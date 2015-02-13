
---
--- JMGuildSaleHistoryTracker version 0.2
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
    name = 'JMGuildSaleHistoryTracker',
    savedVariablesName = 'JMGuildSaleHistoryTrackerSavedVariables',

    waitTime = 750,                       -- Miliseconds

    scanInterval = 120,                   -- Seconds
    minimumScanInterval = 10,             -- Seconds
    memberListRefreshInterval = 60 * 60,  -- Seconds

    removeOldSaleInterval = 24 * 60 * 60, -- Seconds
    saleMaxAge = 30 * 24 * 60 * 60,       -- Seconds
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
function Scanner:startScanning()
    if self.isScanning then
        return
    end

    if ((GetTimeStamp() - self.lastSuccessfullScan) < Config.minimumScanInterval) then
        return
    end

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
    end, Config.waitTime)
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
        end, Config.waitTime)
    else
        -- We are done with this guild

        -- Trigger that we are done, save the data etc
        GuildIdMap[guildId].lastEventTimestamp = self.lastEventTimestamp
        GuildScanEventIndexMap[guildId] = self.currentEventIndex
        self:saveNewSaleList(guildId)

        -- Do the next guild
        zo_callLater(function ()
            self:scanGuild(self.currentGuildIndex + 1)
        end, Config.waitTime)
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

    if ((GetTimeStamp() - GuildList[guildName].memberListTimestamp) > Config.memberListRefreshInterval) then
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
end

---
-- Will be called when all guilds are finished
--
function Scanner:finishedScanning()
    self.isScanning = false
    self.currentGuildIndex = 0
    self.currentGuildId = 0
    self.lastSuccessfullScan = GetTimeStamp()
end

---
-- Remove old sales once in a while
--
function Scanner:removeOldSales()
    if ((GetTimeStamp() - SavedVariables.removedOldSaleTimestamp) < Config.removeOldSaleInterval) then
        return
    end

    for _, guildData in pairs(GuildList) do
        for saleIndex = #(guildData.saleList), 1, -1 do
            if (guildData.saleList[saleIndex].saleTimestamp + Config.saleMaxAge < GetTimeStamp()) then

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
    })

    -- Make GuildList link to the savedVariables
    GuildList = SavedVariables.guildList

    -- Remove old data
    Scanner:removeOldSales()

    -- Create the indexes
    Indexer:addExistingDataToTheIndex()

    -- Scan every x seconds
    EVENT_MANAGER:RegisterForUpdate(Config.name, (Config.scanInterval * 1000), function()
        Scanner:startScanning()
    end)
end

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
    if args == "" then
        return
    end

    d('Info for ' .. args)

    d(#(JMGuildSaleHistoryTracker.getSalesFromUser(args)))
    d(#(JMGuildSaleHistoryTracker.getBuysFromUser(args)))
    d(#(JMGuildSaleHistoryTracker.getSalesFromItemId(args)))
    d(#(JMGuildSaleHistoryTracker.getAllSalesFromGuildIndex(args)))
end
