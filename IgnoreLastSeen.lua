local addonName = "IgnoreLastSeen"
local frame = CreateFrame("Frame", addonName .. "Frame")
local DB
local queryQueue = {}
local prevQueryQueue = {}
local currentQuery = nil
local isCurrent = nil
local lastQueryTime = 0
local QUERY_DELAY = 60  -- Delay between /who queries in seconds
local guiFrame = nil
local scrollFrame = nil
local rows = {}
local prevFrame = nil
local prevScrollFrame = nil
local prevRows = {}
local PrevNames
local PrevTimesDB

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("IGNORELIST_UPDATE")
frame:RegisterEvent("WHO_LIST_UPDATE")

local FormatTimeDiff, UpdateIgnoreList, RemovePlayer, UpdateGUI, ShowGUI, UpdatePrev, UpdatePrevList, Reignore, DeletePlayer

FormatTimeDiff = function(lastSeen)
    if lastSeen == 0 then
        return "Never Seen"
    end
    local diff = time() - lastSeen
    local days = math.floor(diff / 86400)
    if days == 0 then
        return "< 24 Hours"
    elseif days == 1 then
        return "1 Day ago"
    else
        return days .. " Days ago"
    end
end

UpdateIgnoreList = function()
    wipe(queryQueue)
    for i = 1, GetNumIgnores() do
        local name = GetIgnoreName(i)
        if name then
            if not DB[name] then
                DB[name] = 0
            end
            table.insert(queryQueue, name)
        end
    end
    if guiFrame then
        UpdateGUI()
    end
end

RemovePlayer = function(name)
    DelIgnore(name)  -- Use DelIgnore for WoW 3.3.5
    local lastSeen = DB[name] or 0
    if not PrevTimesDB[name] then
        table.insert(PrevNames, 1, name)
    end
    PrevTimesDB[name] = lastSeen
    UpdateIgnoreList()
    UpdatePrevList()
end

Reignore = function(name)
    AddIgnore(name)
    local lastSeen = PrevTimesDB[name] or 0
    for i = #PrevNames, 1, -1 do
        if PrevNames[i] == name then
            table.remove(PrevNames, i)
            break
        end
    end
    PrevTimesDB[name] = nil
    DB[name] = lastSeen
    UpdateIgnoreList()
    UpdatePrevList()
end

DeletePlayer = function(name)
    for i = #PrevNames, 1, -1 do
        if PrevNames[i] == name then
            table.remove(PrevNames, i)
            break
        end
    end
    PrevTimesDB[name] = nil
    UpdatePrev()
end

UpdateGUI = function()
    if not guiFrame then return end
    
    -- Clear existing rows
    for _, row in ipairs(rows) do
        row:Hide()
        row.nameLabel:SetText("")
        row.timeLabel:SetText("")
        row.removeButton:SetScript("OnClick", nil)
    end
    wipe(rows)
    
    -- Create scroll content
    local offset = 0
    for i = 1, GetNumIgnores() do
        local name = GetIgnoreName(i)
        if name then
            local row = CreateFrame("Frame", nil, scrollFrame:GetScrollChild())
            row:SetSize(400, 20)
            row:SetPoint("TOPLEFT", 10, -offset)
            
            local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            nameLabel:SetPoint("LEFT", 0, 0)
            nameLabel:SetWidth(150)
            nameLabel:SetJustifyH("LEFT")
            nameLabel:SetText(name)
            
            local timeLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            timeLabel:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
            timeLabel:SetWidth(120)
            timeLabel:SetJustifyH("LEFT")
            timeLabel:SetText(FormatTimeDiff(DB[name] or 0))
            timeLabel:SetTextColor(1, 1, 1, 1)
            
            local removeButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            removeButton:SetSize(65, 20)
            removeButton:SetPoint("RIGHT", row, "RIGHT", -15, 0)
            removeButton:SetText("Remove")
            removeButton:SetScript("OnClick", function() RemovePlayer(name) end)
            
            row.nameLabel = nameLabel
            row.timeLabel = timeLabel
            row.removeButton = removeButton
            
            table.insert(rows, row)
            offset = offset + 25
        end
    end
    
    -- Update scroll child size
    local scrollChild = scrollFrame:GetScrollChild()
    scrollChild:SetSize(400, math.max(offset, 300))
    
    UpdatePrev()
end

UpdatePrevList = function()
    wipe(prevQueryQueue)
    for i, name in ipairs(PrevNames) do
        if not PrevTimesDB[name] then
            PrevTimesDB[name] = 0
        end
        table.insert(prevQueryQueue, name)
    end
    if prevFrame then
        UpdatePrev()
    end
end

UpdatePrev = function()
    if not prevFrame then return end
    
    -- Clear existing rows
    for _, row in ipairs(prevRows) do
        row:Hide()
        row.nameLabel:SetText("")
        row.timeLabel:SetText("")
        row.ignoreButton:SetScript("OnClick", nil)
        row.deleteButton:SetScript("OnClick", nil)
    end
    wipe(prevRows)
    
    -- Create scroll content
    local offset = 0
    for i, name in ipairs(PrevNames) do
        local row = CreateFrame("Frame", nil, prevScrollFrame:GetScrollChild())
        row:SetSize(400, 20)
        row:SetPoint("TOPLEFT", 10, -offset)
        
        local nameLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        nameLabel:SetPoint("LEFT", 0, 0)
        nameLabel:SetWidth(100)
        nameLabel:SetJustifyH("LEFT")
        nameLabel:SetText(name)
        nameLabel:SetTextColor(0.5, 0.5, 0.5, 1)
        
        local timeLabel = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        timeLabel:SetPoint("LEFT", nameLabel, "RIGHT", 10, 0)
        timeLabel:SetWidth(120)
        timeLabel:SetJustifyH("LEFT")
        timeLabel:SetText(FormatTimeDiff(PrevTimesDB[name] or 0))
        timeLabel:SetTextColor(0.5, 0.5, 0.5, 1)
        
        local ignoreButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        ignoreButton:SetSize(60, 20)
        ignoreButton:SetPoint("LEFT", timeLabel, "RIGHT", -15, 0)
        ignoreButton:SetText("Ignore")
        ignoreButton:SetScript("OnClick", function() Reignore(name) end)
        
        local deleteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        deleteButton:SetSize(60, 20)
        deleteButton:SetPoint("RIGHT", row, "RIGHT", -60, 0)
        deleteButton:SetText("Delete")
        deleteButton:SetScript("OnClick", function() DeletePlayer(name) end)
        
        row.nameLabel = nameLabel
        row.timeLabel = timeLabel
        row.ignoreButton = ignoreButton
        row.deleteButton = deleteButton
        
        table.insert(prevRows, row)
        offset = offset + 25
    end
    
    -- Update scroll child size
    local prevScrollChild = prevScrollFrame:GetScrollChild()
    prevScrollChild:SetSize(400, math.max(offset, 300))
end

ShowGUI = function()
    if guiFrame then
        guiFrame:Show()
        prevFrame:Hide()
        UpdateGUI()
        return
    end
    
    -- Create main frame
    guiFrame = CreateFrame("Frame", addonName .. "GUIFrame", UIParent)
    guiFrame:SetSize(450, 350)
    guiFrame:SetPoint("CENTER")
    guiFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    guiFrame:SetMovable(true)
    guiFrame:EnableMouse(true)
    guiFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            self:StartMoving()
        end
    end)
    guiFrame:SetScript("OnMouseUp", function(self, button)
        self:StopMovingOrSizing()
    end)
    guiFrame:SetResizable(false)  -- Explicitly disable resizing
    guiFrame:SetMinResize(450, 350)  -- Set min/max to same as size to prevent resizing
    guiFrame:SetMaxResize(450, 350)
    
    -- Toggle button
    local toggleButton = CreateFrame("Button", nil, guiFrame, "UIPanelButtonTemplate")
    toggleButton:SetSize(16, 20)
    toggleButton:SetPoint("TOPLEFT", 10, -10)
    toggleButton:SetText("<")
    toggleButton:SetScript("OnClick", function(self)
        if prevFrame:IsShown() then
            prevFrame:Hide()
            self:SetText("<")
        else
            prevFrame:Show()
            self:SetText(">")
        end
        UpdatePrev()
    end)
    
    -- Title
    local title = guiFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Active Ignore List:")
    
    -- Close button
    local closeButton = CreateFrame("Button", nil, guiFrame, "UIPanelCloseButton")
    closeButton:SetPoint("TOPRIGHT", -5, -5)
    closeButton:SetScript("OnClick", function() guiFrame:Hide() end)
    
    -- Scroll frame
    scrollFrame = CreateFrame("ScrollFrame", addonName .. "ScrollFrame", guiFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 15, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -35, 15)
    
    local scrollChild = CreateFrame("Frame", nil, scrollFrame)
    scrollChild:SetSize(400, 300)
    scrollFrame:SetScrollChild(scrollChild)
    
    -- Create previous frame
    prevFrame = CreateFrame("Frame", addonName .. "PrevGUIFrame", guiFrame)
    prevFrame:SetSize(400, 350)
    prevFrame:SetPoint("TOPRIGHT", guiFrame, "TOPLEFT", 0, 0)
    prevFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    prevFrame:Hide()
    
    -- Previous title
    local prevTitle = prevFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableLarge")
    prevTitle:SetPoint("TOP", 0, -15)
    prevTitle:SetText("Previously Ignored:")
    
    -- Previous scroll frame
    prevScrollFrame = CreateFrame("ScrollFrame", addonName .. "PrevScrollFrame", prevFrame, "UIPanelScrollFrameTemplate")
    prevScrollFrame:SetPoint("TOPLEFT", 15, -40)
    prevScrollFrame:SetPoint("BOTTOMRIGHT", -35, 15)
    
    local prevScrollChild = CreateFrame("Frame", nil, prevScrollFrame)
    prevScrollChild:SetSize(400, 300)
    prevScrollFrame:SetScrollChild(prevScrollChild)
    
    UpdateGUI()
end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        IgnoreLastSeenDB = IgnoreLastSeenDB or {}
        DB = IgnoreLastSeenDB
        IgnoreLastSeenPrevNames = IgnoreLastSeenPrevNames or {}
        PrevNames = IgnoreLastSeenPrevNames
        table.sort(PrevNames)
        IgnoreLastSeenPrevTimesDB = IgnoreLastSeenPrevTimesDB or {}
        PrevTimesDB = IgnoreLastSeenPrevTimesDB
        UpdateIgnoreList()
        UpdatePrevList()
    elseif event == "IGNORELIST_UPDATE" then
        UpdateIgnoreList()
    elseif event == "WHO_LIST_UPDATE" then
        if currentQuery then
            local numResults = GetNumWhoResults()
            if numResults > 0 then
                local name = GetWhoInfo(1)
                if name == currentQuery then
                    if isCurrent then
                        DB[currentQuery] = time()
                    else
                        PrevTimesDB[currentQuery] = time()
                    end
                end
            end
            currentQuery = nil
            isCurrent = nil
            FriendsFrame:RegisterEvent("WHO_LIST_UPDATE")
            if guiFrame then
                UpdateGUI()
            end
        end
    end
end)

frame:SetScript("OnUpdate", function(self, elapsed)
    if (GetTime() - lastQueryTime) > QUERY_DELAY then
        if #queryQueue > 0 then
            currentQuery = table.remove(queryQueue, 1)
            isCurrent = true
            FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE")
            SetWhoToUI(1)
            SendWho('n-"' .. currentQuery .. '"')
            lastQueryTime = GetTime()
            table.insert(queryQueue, currentQuery)
        elseif #prevQueryQueue > 0 then
            currentQuery = table.remove(prevQueryQueue, 1)
            isCurrent = false
            FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE")
            SetWhoToUI(1)
            SendWho('n-"' .. currentQuery .. '"')
            lastQueryTime = GetTime()
            table.insert(prevQueryQueue, currentQuery)
        end
    end
end)

SLASH_IGNORELASTSEEN1 = "/ils"
SlashCmdList["IGNORELASTSEEN"] = function(msg)
    if msg == "list" then
        if GetNumIgnores() == 0 then
            print("Your ignore list is empty.")
        else
            print("Ignore List Last Seen Times:")
            for i = 1, GetNumIgnores() do
                local name = GetIgnoreName(i)
                local lastSeen = DB[name] or 0
                print(name .. ": " .. FormatTimeDiff(lastSeen))
            end
        end
    elseif msg == "report" then
        local current = GetNumIgnores()
        local prev = #PrevNames
        print("Currently ignoring: " .. current .. " players.")
        print("Previously ignored: " .. prev .. " players.")
    else
        ShowGUI()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PARTY_MEMBERS_CHANGED")
local ignoredplayers = {}
f:SetScript("OnEvent", function(self, event, ...)
	if GetNumPartyMembers() > 0 then
		for i = 1, GetNumPartyMembers() do
			local partyname = UnitName("party"..i)
			if not ignoredplayers[partyname] then
				if IsIgnored(partyname) then
					ignoredplayers[partyname] = true
					RaidNotice_AddMessage(RaidWarningFrame, "Ignored player "..partyname.." has joined your group!", { r = 1, g = 0, b = 0 })
				end
			end
		end
	else
		ignoredplayers = {}
	end
end)