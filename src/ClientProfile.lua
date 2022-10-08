local RunService = game:GetService('RunService')
local Players = game:GetService('Players')

local Package = script.Parent

local Util = Package.Util
local Error = require(Util.Error)

local Replicator = require(Package.Replicator)

local plr = Players.LocalPlayer

local ClientProfile = {}

function ClientProfile.new(profile)
    local self = setmetatable({}, {__index = ClientProfile})

    self.isPlayerProfile = typeof(profile) == 'Instance'
    if self.isPlayerProfile then
        self.key = 'profile_'..profile.UserId
        self.player = profile
    else
        self.key = profile     
    end

    return self
end

function ClientProfile:load()
    local loadedReplicator = Replicator.new(self.key..'_loaded')
    loadedReplicator:expect(true, 20, function()
        Error('['..self.key..'] Couldn\'t load profile')
    end)

    local replicator = Replicator.new(self.key)

    self.replicator = replicator
    self.isLoaded = true
end

function ClientProfile:get()
    if not self.isLoaded then
        self:load()
    end
    return self.replicator:get()
end

function ClientProfile:onChanged(...)
    if not self.isLoaded then
        self:load()
    end
    self.replicator:onChanged(...)
end

function ClientProfile:getProfile(plr)
    return ClientProfile.new(plr)
end

return ClientProfile.new('profile_'..plr.UserId)