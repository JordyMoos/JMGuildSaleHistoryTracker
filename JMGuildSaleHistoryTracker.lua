
---
--- JMGuildSaleHistoryTracker
--- https://github.com/JordyMoos/JMGuildSaleHistoryTracker
---

--[[

    Variable declaration

 ]]

---
-- @field name
-- @field savedVariablesName
--
local Config = {
    version = '0.6',
    author = 'Jordy Moos',

    -- Data version tells us what the version of the data should be to match the addons version
    -- In the saved variables will also be a Data Version and if that is lower than the current Data Version
    -- Then backward compatibility functions will run trought the stored sales to match the current interface
    dataVersion = 2,

    name = 'JMGuildSaleHistoryTracker',
    savedVariablesName = 'JMGuildSaleHistoryTrackerSavedVariables',

    waitTime = 1600,                      -- Miliseconds

    scanInterval = 120,                   -- Seconds
    minimumScanInterval = 10,             -- Seconds
    memberListRefreshInterval = 60 * 60,  -- Seconds

    removeOldSaleInterval = 24 * 60 * 60, -- Seconds
    saleMaxAge = 30 * 24 * 60 * 60,       -- Seconds

    -- Testing mode will print messages about what the addon is doing
    -- Also lowers the scanInterval so you do not have to wait so long
    testingMode = false,
}

---
-- Settings
--

local Settings = {

}

---
-- Return the configs setting if the setting does not exists
--
-- @field __index
--
local SettingMetatable = {
    __index = function (setting, key)
        setting[key] = Config[key]

        return setting[key]
    end
}


---
-- Stored the guild the player is in
-- If you leave a guild than that data will disapear
--
local GuildList = {

}

local SavedVariables = {

}

---
-- Map guild id to the guilds name
--
local GuildIdMap = {

}

---
-- Guilds event index should be reset after a reload because the event list will be changes
-- Thats why we do not store this value in the GuildList (which is in the saved variables)
--
local GuildScanEventIndexMap = {

}

---
-- New guild events will temporary be stored in here
-- So we can "flush" them when we have them all
-- This allows us to do it all over if something went wrong
-- Without half "flushed" data
--
local NewGuildSaleList = {

}

--[[

    Testing messages
    Should be removed later

 ]]

local function db(message)
    if not Settings.testingMode then
        return
    end

    d('GH: ' .. message)
end

--[[

    Indexer

    Used to speedup the api

 ]]

---
-- Logic for the indexes are in here
--
local Indexer = {
    soldBy = {},
    boughtBy = {},
    itemId = {},
}

---
-- Add sale to the sold by index
--
-- @param sale
--
function Indexer:addSoldBy(sale)
    local seller = sale.seller:lower()

    if not self.soldBy[seller] then
        self.soldBy[seller] = {}
    end

    table.insert(self.soldBy[seller], sale)
end


---
-- Add sale to the bought by index
--
-- @param sale
--
function Indexer:addBoughtBy(sale)
    local buyer = sale.buyer:lower()

    if not self.boughtBy[buyer] then
        self.boughtBy[buyer] = {}
    end

    table.insert(self.boughtBy[buyer], sale)
end

---
-- Add sale to the item index
--
-- @param sale
--
function Indexer:addItemId(sale)
    local itemId = sale.itemId

    if not self.itemId[itemId] then
        self.itemId[itemId] = {}
    end

    table.insert(self.itemId[itemId], sale)
end

---
-- Create indexes for the sale
--
-- @param sale
--
function Indexer:addSale(sale)
    self:addSoldBy(sale)
    self:addBoughtBy(sale)
    self:addItemId(sale)
end

---
-- Get list of sales from given user name
-- We copy the table because we give away the data through the api
--
-- @param user
--
function Indexer:getSaleListFromUser(user)
    return ZO_DeepTableCopy(self.soldBy[user:lower()] or {})
end

---
-- Get list of buys from given user name
-- We copy the table because we give away the data through the api
--
-- @param user
--
function Indexer:getBuyListFromUser(user)
    return ZO_DeepTableCopy(self.boughtBy[user:lower()] or {})
end

---
-- Get list of sales from item id
-- We copy the table because we give away the data through the api
--
-- @param user
--
function Indexer:getSaleListFromItemId(itemId)
    return ZO_DeepTableCopy(self.itemId[itemId] or {})
end

---
-- Get list of sales from given guild id
-- We copy the table because we give away the data through the api
--
-- @param user
--
function Indexer:getSaleListFromGuildId(guildId)
    local guildData = GuildIdMap[guildId]
    if not guildData then
        return {}
    end

    return ZO_DeepTableCopy(guildData.saleList)
end

---
-- Get list of sales from given guild index
-- We copy the table because we give away the data through the api
--
-- @param user
--
function Indexer:getSaleListFromGuildIndex(guildIndex)
    guildIndex = tonumber(guildIndex)
    if not guildIndex then
        return {}
    end

    return self:getSaleListFromGuildId(
        GetGuildId(guildIndex)
    )
end

---
-- Add the sales in the saved variables to the index
--
function Indexer:addExistingDataToTheIndex()
    for _, guildData in pairs(GuildList) do
        for _, sale in ipairs(guildData.saleList) do
            self:addSale(sale)
        end
    end
end

--[[

 Sale Upgrader

 Will upgrade old sales to match the newest interface
 To fix backward compatibility of the sales

 ]]

local SaleUpgrader = {}

---
-- Will be called after the saved variables is loaded
-- To check and update the sale data
--
function SaleUpgrader:upgrade(SavedVariables)
    while SavedVariables.dataVersion < Config.dataVersion do
        local upgradeFunction = SaleUpgrader.upgradeFunctionVersion[SavedVariables.dataVersion]
        upgradeFunction(SavedVariables)

        SavedVariables.dataVersion = SavedVariables.dataVersion + 1
    end
end

---
-- Every time we increase the data version we must add the backward compatibility function
-- If we get from version 2 to 3 then we add a function with key 2
-- The function will be called once and is and can everything it wants
-- That is because maybe it needs to do more then just change the sale data
--
SaleUpgrader.upgradeFunctionVersion = {

    ---
    -- Example to be used to the first version increment
    -- This function does not do anything but it is called so it can not be removed
    --
    [0] = function(SavedVariables)

    end,

    ---
    -- Added price per piece
    --
    [1] = function(SavedVariables)
        for _, guildData in pairs(SavedVariables.guildList) do
            for _, sale in ipairs(guildData.saleList) do
                sale.pricePerPiece = math.ceil(sale.price / sale.quantity)
            end
        end
    end,
}

--[[

 Scanner

 ]]

---
-- The scanner will do all the gathering
--
local Scanner = {
    isScanning = false,
    currentGuildIndex = 0,
    currentGuildId = 0,
    currentEventIndex = 0,
    highestFoundTimeStamp = 0,
    lastSuccessfullScan = 0,
}

---
--
function Scanner:getScanInterval()
     return Settings.scanInterval * 1000
end

---
--
function Scanner:startScanning()
    if self.isScanning then
        db('Already is scanning, will wait for the next iteration')
        return
    end

    if ((GetTimeStamp() - self.lastSuccessfullScan) < Settings.minimumScanInterval) then
        db('Scan request is too early, the last one just finished, will wait for the next iteration')
        return
    end

    db('Scan started')
    self.isScanning = true

    -- Assumingly we can scan the first guild right
    self:scanGuild(1)
end

---
-- Start the scan of a guild
--
-- @param guildIndex
--
function Scanner:scanGuild(guildIndex)
    local guildId = GetGuildId(guildIndex)

    -- If there are no more guilds then we are done
    if guildId == 0 then
        return self:finishedScanning()
    end

    db('Scan guildIndex ' .. guildIndex .. ' which is guildId ' .. guildId)

    self:storeGuildInformation(guildId)

    NewGuildSaleList = {}
    self.currentGuildIndex = guildIndex
    self.currentGuildId = guildId
    self.lastEventTimestamp = math.max(0, GuildIdMap[guildId].lastEventTimestamp)
    self.currentEventIndex = math.max(0, GuildScanEventIndexMap[guildId] or 0)

    -- We start from the newest record and find our way down
    self.timeStamp = GetTimeStamp()
    RequestGuildHistoryCategoryNewest(guildId, GUILD_HISTORY_STORE)

    -- We must wait a while between some of the api calls
    zo_callLater(function ()
        self:scanPageHandler(guildId)
    end, Settings.waitTime)
end

---
-- This function manages the scan page but does not scan itself
-- That does the scan page function
--
-- @param guildId
--
function Scanner:scanPageHandler(guildId)

    self:scanPage(guildId)

    -- If we have more then get more
    if DoesGuildHistoryCategoryHaveMoreEvents(guildId, GUILD_HISTORY_STORE) then
        self.timeStamp = GetTimeStamp()
        RequestGuildHistoryCategoryOlder(guildId, GUILD_HISTORY_STORE)
        zo_callLater(function()
            self:scanPageHandler(guildId)
        end, Settings.waitTime)
    else
        -- We are done with this guild

        -- Trigger that we are done, save the data etc
        GuildIdMap[guildId].lastEventTimestamp = self.lastEventTimestamp
        GuildScanEventIndexMap[guildId] = self.currentEventIndex
        self:saveNewSaleList(guildId)

        -- Do the next guild
        zo_callLater(function ()
            self:scanGuild(self.currentGuildIndex + 1)
        end, Settings.waitTime)
    end
end

---
-- We should have a page with guild sales
-- Try to read the page and keep requesting older record
--
-- @param guildId
--
function Scanner:scanPage(guildId)
    local numEvents = GetNumGuildEvents(guildId, GUILD_HISTORY_STORE)

    -- Add one to the starting index so we do not do the last one of the previous iteration again
    for eventIndex = self.currentEventIndex + 1, numEvents do
        local eventInformation = {GetGuildEventInfo(guildId, GUILD_HISTORY_STORE, eventIndex) }

        if (eventInformation[1] == GUILD_EVENT_ITEM_SOLD) then
            local saleTimestamp = self.timeStamp - eventInformation[2]
            self.lastEventTimestamp = math.max(self.lastEventTimestamp, saleTimestamp)

            if saleTimestamp > GuildIdMap[guildId].lastEventTimestamp then

                local _, _, _, itemId = ZO_LinkHandler_ParseLink(eventInformation[6])

                local sale = {
                    saleTimestamp = saleTimestamp,
                    seller = eventInformation[3],
                    buyer = eventInformation[4],
                    quantity = eventInformation[5],
                    itemLink = eventInformation[6],
                    price = eventInformation[7],
                    pricePerPiece = math.ceil(eventInformation[7] / eventInformation[5]),
                    tax = eventInformation[8],
                    itemId = itemId or 0,
                    guildName = GuildIdMap[guildId].name,
                    isKioskSale = (GuildIdMap[guildId].memberList[eventInformation[4]:lower()] ~= nil),
                }

                table.insert(NewGuildSaleList, sale)
                Indexer:addSale(sale)
            end
        end
    end

    -- Update the index incase we have more pages
    -- That will raise the total number of events but not the "beginning"
    -- So it will add more records to the page
    self.currentEventIndex = numEvents
end

---
-- Refresh the guild member list once in a while
--
-- @param guildId
--
function Scanner:refreshGuildMemberList(guildId)
    local guildName = GetGuildName(guildId)

    if ((GetTimeStamp() - GuildList[guildName].memberListTimestamp) > Settings.memberListRefreshInterval) then
        GuildList[guildName].memberList = {}

        for memberIndex = 1, GetNumGuildMembers(guildId) do
            local memberName, _, _, _, _ = GetGuildMemberInfo(guildId, memberIndex)
            GuildList[guildName].memberList[memberName:lower()] = memberName
        end

        GuildList[guildName].memberListTimestamp = GetTimeStamp()
    end
end

---
-- Store information about the guild
--
-- @param guildId
--
function Scanner:storeGuildInformation(guildId)
    local guildName = GetGuildName(guildId)
    local description = GetGuildDescription(guildId)

    -- If we already have the guild then just update the description
    if GuildList[guildName] then
        GuildList[guildName].description = description
    else

        -- Guild does not exists yet
        GuildList[guildName] = {
            name = guildName,
            description = description,
            lastEventTimestamp = 0,
            saleList = {},
            memberList = {},
            memberListTimestamp = 0,
        }
    end

    -- Refresh the guild member list
    self:refreshGuildMemberList(guildId)

    -- Make a map from the guild id to the guild name
    -- So we can find the guild by the guildId later
    GuildIdMap[guildId] = GuildList[guildName]
end

---
-- Store the newly gathered sales
--
-- @param guildId
--
function Scanner:saveNewSaleList(guildId)
    if #NewGuildSaleList == 0 then
        return
    end

    local guildSaleList = GuildIdMap[guildId].saleList

    for _, sale in ipairs(NewGuildSaleList) do
        table.insert(guildSaleList, sale)
    end
    db('Guild id ' .. guildId .. ' found ' .. #NewGuildSaleList .. ' new sales and now has ' .. #guildSaleList .. ' sales')
end

---
-- Will be called when all guilds are finished
--
function Scanner:finishedScanning()
    self.isScanning = false
    self.currentGuildIndex = 0
    self.currentGuildId = 0
    self.lastSuccessfullScan = GetTimeStamp()

    db('Finished scanning all guilds')
end

---
-- Remove old sales once in a while
--
function Scanner:removeOldSales()
    if ((GetTimeStamp() - SavedVariables.removedOldSaleTimestamp) < Settings.removeOldSaleInterval) then
        return
    end

    for _, guildData in pairs(GuildList) do
        for saleIndex = #(guildData.saleList), 1, -1 do
            if (guildData.saleList[saleIndex].saleTimestamp + Settings.saleMaxAge < GetTimeStamp()) then

                table.remove(guildData.saleList, saleIndex)
            end
        end
    end
end

---
-- Start of the addon
-- Load the saved variables and create indexes
--
local function Initialize()
    -- Load the saved variables
    SavedVariables = ZO_SavedVars:NewAccountWide(Config.savedVariablesName, 1, nil, {
        guildList = {},
        removedOldSaleTimestamp = GetTimeStamp(),
        settings = {},
        dataVersion = 0,
    })

    --- Backward compatible settings
    SavedVariables.settings = SavedVariables.settings or {}
    setmetatable(SavedVariables.settings, SettingMetatable)
    Settings = SavedVariables.settings

    -- Make GuildList link to the savedVariables
    GuildList = SavedVariables.guildList

    -- Upgrade sale data
    -- To fix old versions data
    SaleUpgrader:upgrade(SavedVariables)

    -- Remove old data
    Scanner:removeOldSales()

    -- Create the indexes
    Indexer:addExistingDataToTheIndex()

    -- Scan every x seconds
    EVENT_MANAGER:RegisterForUpdate(Config.name, Scanner:getScanInterval(), function()
        Scanner:startScanning()
    end)
end

--[[

    Settings menu

 ]]

local LAM = LibStub:GetLibrary('LibAddonMenu-2.0')

---
--
local Menu = {

}

---
-- @field type
-- @field name
-- @field displayName
-- @field author
-- @field version
-- @field slashCommand
-- @field registerForRefresh
--
Menu.panelData = {
    type = 'panel',
    name = 'JM GSHT',
    displayName = 'JM Guild Sale History Tracker',
    author = Config.author,
    version = Config.version,
    slashCommand = '/gsht',
    registerForRefresh = true,
    registerForDefaults = true,
}

---
--
Menu.optionList = {
    {
        type = 'slider',
        name = 'Scan interval',
        tooltip = 'How often we start a scan in seconds',
        min = 1,
        max = 600,
        step = 1,
        getFunc = function() return Settings.scanInterval end,
        setFunc = function(value)
            Settings.scanInterval = value

            EVENT_MANAGER:UnregisterForUpdate(Config.name)
            zo_callLater(function()
                EVENT_MANAGER:RegisterForUpdate(Config.name, Scanner:getScanInterval(), function()
                    Scanner:startScanning()
                end)
            end, 2000)
        end,
        default = Config.scanInterval,
    },
    {
        type = 'slider',
        name = 'Minimum scan interval',
        tooltip = 'Minimum time to wait between scans in seconds',
        min = 0,
        max = 120,
        step = 1,
        getFunc = function() return Settings.minimumScanInterval end,
        setFunc = function(value)
            Settings.minimumScanInterval = value
        end,
        default = Config.minimumScanInterval,
    },
    {
        type = 'slider',
        name = 'Member list refersh interval',
        tooltip = 'How often do we want to update the guild member list in minutes',
        min = 0,
        max = 60 * 5,
        step = 1,
        getFunc = function() return Settings.memberListRefreshInterval / 60 end,
        setFunc = function(value)
            Settings.memberListRefreshInterval = value * 60
        end,
        default = Config.memberListRefreshInterval / 60,
    },
    {
        type = 'slider',
        name = 'Sale max age',
        tooltip = 'The max age of a sale in days',
        min = 10,
        max = 100,
        step = 1,
        getFunc = function() return Settings.saleMaxAge / (24 * 60 * 60) end,
        setFunc = function(value)
            Settings.saleMaxAge = value * (24 * 60 * 60)
        end,
        default = Config.saleMaxAge / (24 * 60 * 60),
    },
    {
        type = 'slider',
        name = 'Remove old sales interval',
        tooltip = 'How often do we want to remove old sales in days. Example 2 means once every 2 days',
        min = 1,
        max = 10,
        step = 1,
        getFunc = function() return Settings.removeOldSaleInterval / (24 * 60 * 60) end,
        setFunc = function(value)
            Settings.removeOldSaleInterval = value * (24 * 60 * 60)
        end,
        default = Config.removeOldSaleInterval / (24 * 60 * 60),
    },
    {
        type = 'header',
        name = 'Advanced settings',
        width = 'full',
    },
    {
        type = 'checkbox',
        name = 'Testing mode',
        tooltip = 'Testing mode will display messages to the chat about what the addon found.',
        getFunc = function()
            return Settings.testingMode
        end,
        setFunc = function(value)
            Settings.testingMode = value
        end,
        default = Config.testingMode,
    },
    {
        type = 'slider',
        name = 'Wait time',
        tooltip = 'Time in milliseconds to wait between ZO Api calls. Too low might kick you from the server',
        min = 1000,
        max = 5000,
        step = 100,
        getFunc = function() return Settings.waitTime end,
        setFunc = function(value)
            Settings.waitTime = value
        end,
        default = Config.waitTime,
    },
}

---
-- Register the menu
--
LAM:RegisterAddonPanel('JM_GSHT', Menu.panelData)
LAM:RegisterOptionControls('JM_GSHT', Menu.optionList)

--[[

    Events

 ]]

---
-- Adding the initialize handler
--
EVENT_MANAGER:RegisterForEvent(
    Config.name,
    EVENT_ADD_ON_LOADED,
    function (_, addonName)
        if addonName ~= Config.name then
            return
        end

        Initialize()
        EVENT_MANAGER:UnregisterForEvent(Config.name, EVENT_ADD_ON_LOADED)
    end
)

---
-- When the player is active then we can do some scanning
--
EVENT_MANAGER:RegisterForEvent(
    Config.name,
    EVENT_PLAYER_ACTIVATED,
    function ()
        EVENT_MANAGER:UnregisterForEvent(Config.name, EVENT_PLAYER_ACTIVATED)

        zo_callLater(function ()
            Scanner:startScanning()
        end, 1500)
    end
)

--[[

    Api

 ]]

---
-- Making some functions public
--
-- @field scan
--
JMGuildSaleHistoryTracker = {

    ---
    -- Get all sales from given user
    --
    getSalesFromUser = function(user)
        return Indexer:getSaleListFromUser(user)
    end,

    ---
    -- Get all buys from given user
    --
    getBuysFromUser = function(user)
        return Indexer:getBuyListFromUser(user)
    end,

    ---
    -- Get sales from item id
    --
    getSalesFromItemId = function(itemId)
        return Indexer:getSaleListFromItemId(itemId)
    end,

    ---
    -- Get sales history of given guild id
    --
    getAllSalesFromGuildId = function(guildId)
        return Indexer:getSaleListFromGuildId(guildId)
    end,

    ---
    -- Get sales history of given guild index
    --
    getAllSalesFromGuildIndex = function(guildIndex)
        return Indexer:getSaleListFromGuildIndex(guildIndex)
    end,
}

---
-- This should be removed
-- This is just for demo purpose only
--
-- @param args
--
SLASH_COMMANDS['/jm_gsht'] = function(args)
    if args == '' then
        return
    end

    d('Info for ' .. args)

    d('Seller: ' .. #(JMGuildSaleHistoryTracker.getSalesFromUser(args)))
    d('Buyer: ' .. #(JMGuildSaleHistoryTracker.getBuysFromUser(args)))
    d('ItemId: ' .. #(JMGuildSaleHistoryTracker.getSalesFromItemId(args)))
    d('Guild: ' .. #(JMGuildSaleHistoryTracker.getAllSalesFromGuildIndex(args)))
end
