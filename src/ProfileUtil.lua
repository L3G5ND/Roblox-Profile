local Package = script.Parent

local Util = Package.Util
local Copy = require(Util.Copy)

local Replicator = require(Package.Replicator)
local None = require(Package.None)

local ProfileUtil = {}

function ProfileUtil.getKey(plrOrKey)
    local isPlayerProfile = typeof(plrOrKey) == 'Instance' and plrOrKey.ClassName == 'Player'
    if isPlayerProfile then
        return 'profile_'..plrOrKey.UserId
    else
        return plrOrKey
    end
end

function ProfileUtil.getLoadedKey(key)
    return key..'_loaded'
end

function ProfileUtil.removePrivateMembers(tbl, privateMembers)
    tbl = Copy(tbl)
    if privateMembers == true then
        return
    end
    for key, value in pairs(privateMembers) do
        if typeof(value) == 'table' then
            if tbl[key] then
                tbl[key] = ProfileUtil.removePrivateMembers(tbl[key], value)
            end
        elseif value == true then
            if tbl[key] then
                tbl[key] = nil
            end
        end
    end
    return tbl
end

function ProfileUtil.fixNoneForReplicatorNone(tbl)
    tbl = Copy(tbl)
    for key, value in pairs(tbl) do
        if value == None then
            tbl[key] = Replicator.None
        elseif typeof(value) == 'table' then
            tbl[key] = ProfileUtil.fixNoneForReplicatorNone(value)
        end
    end
    return tbl
end

return ProfileUtil