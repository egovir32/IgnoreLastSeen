local addonName = "IgnoreLastSeen"
local frame = CreateFrame("Frame", addonName .. "Frame")
local DB
local queryQueue = {}
local currentQuery = nil
local lastQueryTime = 0
local QUERY_DELAY = 60  -- Delay between /who queries in seconds
local guiFrame = nil
local scrollFrame = nil
local rows = {}

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("IGNORELIST_UPDATE")
frame:RegisterEvent("WHO_LIST_UPDATE")

local function FormatTimeDiff(lastSeen)
    if lastSeen == 0 then
        return "Never seen online"
    end
    local diff = time() - lastSeen
    local days = math.floor(diff / 86400)
    local hours = math.floor((diff % 86400) / 3600)
    local minutes = math.floor((diff % 3600) / 60)
    local seconds = math.floor(diff % 60)
    return string.format("%dd %dh %dm %ds ago", days, hours, minutes, seconds)
end

local function UpdateIgnoreList()
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

local function RemovePlayer(name)
    DelIgnore(name)  -- Use DelIgnore for WoW 3.3.5
    UpdateIgnoreList()
end

local function UpdateGUI()
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
            timeLabel:SetWidth(200)
            timeLabel:SetJustifyH("LEFT")
            timeLabel:SetText(FormatTimeDiff(DB[name] or 0))
            
            local removeButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            removeButton:SetSize(80, 20)
            removeButton:SetPoint("LEFT", timeLabel, "RIGHT", 10, 0)
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
end

local function ShowGUI()
    if guiFrame then
        guiFrame:Show()
        UpdateGUI()
        return
    end
    
    -- Create main frame
    guiFrame = CreateFrame("Frame", addonName .. "GUIFrame", UIParent)
    guiFrame:SetSize(525, 350)
    guiFrame:SetPoint("CENTER")
    guiFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    guiFrame:EnableMouse(true)
    guiFrame:SetResizable(false)  -- Explicitly disable resizing
    guiFrame:SetMinResize(525, 350)  -- Set min/max to same as size to prevent resizing
    guiFrame:SetMaxResize(525, 350)
    
    -- Title
    local title = guiFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -15)
    title:SetText("Ignore Last Seen v3.3.5")
    
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
    
    UpdateGUI()
end

frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        IgnoreLastSeenDB = IgnoreLastSeenDB or {}
        DB = IgnoreLastSeenDB
        UpdateIgnoreList()
    elseif event == "IGNORELIST_UPDATE" then
        UpdateIgnoreList()
    elseif event == "WHO_LIST_UPDATE" then
        if currentQuery then
            local numResults = GetNumWhoResults()
            if numResults > 0 then
                local name = GetWhoInfo(1)
                if name == currentQuery then
                    DB[currentQuery] = time()
                end
            end
            currentQuery = nil
            FriendsFrame:RegisterEvent("WHO_LIST_UPDATE")
            UpdateGUI()
        end
    end
end)

frame:SetScript("OnUpdate", function(self, elapsed)
    if #queryQueue > 0 and (GetTime() - lastQueryTime) > QUERY_DELAY then
        currentQuery = table.remove(queryQueue, 1)
        FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE")
        SetWhoToUI(1)
        SendWho('n-"' .. currentQuery .. '"')
        lastQueryTime = GetTime()
        table.insert(queryQueue, currentQuery)
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
    else
        ShowGUI()
    end
end