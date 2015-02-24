
local version = '1.2'


--local mayor, minor, patch = string.gmatch(version, "%d")
--
--print(mayor)
--print(minor)
--print(patch)

version = version .. '.3.4.5'

for a in string.gmatch(version, "%d") do
    print(a)
    print('--')
end

