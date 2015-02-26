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

### getVersion

```lua
local version = JMGuildSaleHistoryTracker.getVersion()
```

Will return the current version of the addon

### checkVersion

```lua
---
--- @param atLeastVersion             Means that you need this addon be at least in the given version
--- @param lessThanVersion (optional) Means that the addon needs to be less than the given version
--- JMGuildSaleHistoryTracker.checkVersion(atLeastVersion, lessThanVersion)
---
--- If you do not assign the second argument than it will be automatically assigned to the next mayor version
--- For example if your atLeastVersion is 0.5 than the lessThanVersion will become 1.0
--- You can also set false to the second parameter and than there will be no check against the lessThanVersion version
---
--- Examples:
--- - Lets say that this currents addon version is 1.7 in all the examples then:
---
--- Will return true because 1.5.1 is less than 1.7 and not more than 2.0 (the next mayor)
local isCorrectVersion = JMGuildSaleHistoryTracker.checkVersion('1.5.1')
---
--- Exactly the same as the previous example
local isCorrectVersion = JMGuildSaleHistoryTracker.checkVersion('1.5.1', '2.0')
---
--- False: The current version is lower than what you require
local isCorrectVersion = JMGuildSaleHistoryTracker.checkVersion('1.7.1')
---
--- False: The current version is more than the next mayor
local isCorrectVersion = JMGuildSaleHistoryTracker.checkVersion('0.6.1')
---
--- True: The current version is between the asLeast and LessThan
local isCorrectVersion = JMGuildSaleHistoryTracker.checkVersion('0.6.1', '2.0')
---
--- True: We ignore the LessThan
local isCorrectVersion = JMGuildSaleHistoryTracker.checkVersion('0.6.1', false)

```

This can be useful if you want to use newer features of the addon.
So you can check if you can use the new features or need to inform the player that he should update the addon.

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
