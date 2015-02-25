
---
--- Copyright (c) 2015 Jordy Moos
--- @licence see LICENSE file
---

LibJMVersion = {}

---
-- Check if the addons version is in range of the given versions
--
-- @param string           minimumVersion
-- @param string|nil|false maximumVersion
--
-- nil will be the next mayor function
-- false will ignore the maximum check
--
function LibJMVersion:validateVersion(minimumVersion, currentVersion, maximumVersion)
    local minMajor, minMinor, minPatch = self:parseVersion(minimumVersion)
    local minVersionNumber = self:toNumber(minMajor, minMinor, minPatch)

    local currentMajor, currentMinor, currentPatch = self:parseVersion(currentVersion)
    local currentVersionNumber = self:toNumber(currentMajor, currentMinor, currentPatch)

    -- Check if the minimum version is at least equal to the current version
    if currentVersionNumber < minVersionNumber then
        return false
    end

    -- If we do not want to check the maximum version than its oke now
    if maximumVersion == false then
        return true
    end

    -- Set the maximum version to the next mayor version
    maximumVersion = maximumVersion or tostring(minMajor + 1)
    local maxMajor, maxMinor, maxPatch = self:parseVersion(maximumVersion)
    local maxVersionNumber = self:toNumber(maxMajor, maxMinor, maxPatch)

    -- The current version should be less then the maximum version
    -- The maximum is like max allowed + 1
    -- So if the current version is equal or more then the max version
    -- Then the version is too high
    if currentVersionNumber >= maxVersionNumber then
        return false
    end

    return true
end

---
-- Parses the string version to the three values Mayor, Minor and Patch
--
-- @param version
--
function LibJMVersion:parseVersion(version)
    local versionTable = {}
    local index = 1

    for verionPart in string.gmatch(version .. '.0.0.0', "%d+") do
        versionTable[index] = verionPart

        if (index == 3) then
            return versionTable[1], versionTable[2], versionTable[3]
        end
        index = index + 1
    end
end

---
-- Converts the mayor minor and patch to a number
-- This is not the same as the version as a string
--
function LibJMVersion:toNumber(mayor, minor, patch)
    return ((mayor + 1) * 1000000) + ((minor + 1) * 1000) + patch
end
