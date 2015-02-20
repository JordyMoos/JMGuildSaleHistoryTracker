## JMGuildHistoryTracker

Addon for elder scroll online that keeps track of guild sales.
Other addons can request this addon about all the sales of a guild.
Or sales and buys from users or of a certain item id.

## Sale structure

```lua
sale =
{
    saleTimestamp = '',
    seller = '', -- The account name like @player
    buyer = '',
    quantity = '',
    itemLink = '',
    price = '',
    tax = '',
    itemId = '',
    guildName = '',
    isKioskSale = '', -- true or false
}
```

The addon also stores some information about the guild that the addon uses itself.
That information is also in the saved file. (See below)

## Guild information structure

```lua
data =
{
    guildList =
    {
        -- Guilds are stored by their name
        "Name of first guild" =
        {
            name = '',
            description = '',

            memberList =
            {
                "@player" = "@Player",
                -- etc..
            },

            -- List of sales as described above
            saleList =
            {
                sale,
                sale,
                sale,
            },
        },

        "Name of second guild" = {}, -- Etc..
    }
}
```

## API

### getSalesFromUser

```lua
local saleList = JMGuildSaleHistoryTracker.getSalesFromUser("@Player")
```

Will return a list of sales made by the given users name. Sales are from all your guilds.

### getBuysFromUser

```lua
local salesList = JMGuildSaleHistoryTracker.getBuysFromUser("@Player")
```

Will return list of "sales" that the given user bought.

### getSalesFromItemId

```lua
local saleList = JMGuildSaleHistoryTracker.getSalesFromItemId(1000)
```

Will return a list of sales from the given item id.

### getAllSalesFromGuildId

```lua
local saleList = JMGuildSaleHistoryTracker.getAllSalesFromGuildId(guildId)
```

Will return all the sales of the guild belonging to the given guild id

### getAllSalesFromGuildIndex

```lua
local saleList = JMGuildSaleHistoryTracker.getAllSalesFromGuildIndex(guildIndex)
```

Will return all the sales of the guild belonging to the given guild index

### registerForEvent

```lua
JMGuildSaleHistoryTracker.registerForEvent(event, callback)
```

Allows you to listen to an event. See Events for list of possible events.
The callback function will be called when the events triggers.

### unregisterForEvent

```lua
JMGuildSaleHistoryTracker.unregisterForEvent(event, callback)
```

Stop listening to an event.

## Events

All possible events are listen in `JMGuildSaleHistoryTracker.events`.

#### NEW_GUILD_SALES

```lua
JMGuildSaleHistoryTracker.events.NEW_GUILD_SALES
```

Will be triggered when new sales for a guild is found.
The function will have the guild id as its first argument.
And a list of new sales as the second argument.

```lua
JMGuildSaleHistoryTracker.registerForEvent(JMGuildSaleHistoryTracker.events.NEW_GUILD_SALES, function (guildId, saleList)
    d('We found ' .. #saleList .. ' new sales for guild id ' .. guildId)
    d(saleList)
end)
```

## Disclaimer

This Add-on is not created by, affiliated with or sponsored by ZeniMax Media Inc. or its affiliates. The Elder Scrolls® and related logos are registered trademarks or trademarks of ZeniMax Media Inc. in the United States and/or other countries. All rights reserved.
