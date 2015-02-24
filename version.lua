
local version = '2.1.1'

function parseVersion(version)
    local versionTable = {}
    local index = 1

    for verionPart in string.gmatch(version .. '.0.0.0', "%d") do
        versionTable[index] = verionPart

        if (index == 3) then
            return versionTable[1], versionTable[2], versionTable[3]
        end
        index = index + 1
    end
end

print(parseVersion(version))
