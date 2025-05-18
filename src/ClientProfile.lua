local Players = game:GetService("Players")

local Package = script.Parent

local Util = Package.Util
local Assert = require(Util.Assert)
local Error = require(Util.Error)
local TypeMarker = require(Util.TypeMarker)

local Replicator = require(Package.Replicator)

local plr = Players.LocalPlayer

local function expect(callback, errorMsg, timeout)
	timeout = timeout or 10
	local startTime = os.clock()
	while true do
		if callback() ~= nil then
			return
		end
		if os.clock() - startTime >= timeout then
			Error(errorMsg)
		end
		task.wait()
	end
end

local ProfileType = TypeMarker.Mark("[Profile]")

local ClientProfile = {}
local Profiles = {}
local LoadingProfiles = {}

function ClientProfile.new(plrOrKey)
	local isPlayer = typeof(plrOrKey) == "Instance" and plrOrKey.ClassName == "Player"
	Assert(isPlayer or typeof(plrOrKey) == "string", "Invalid argument #1 (must be a 'Player' instance or a 'string')")

	local key = isPlayer and "profile_" .. plrOrKey.UserId or plrOrKey

	if Profiles[key] then
		return Profiles[key]
	end
	if LoadingProfiles[key] then
		expect(function()
			return Profiles[key]
		end, "Wasn't able to get profile '" .. key .. "'", 20)
		return Profiles[key]
	end
	LoadingProfiles[key] = true

	local self = setmetatable({}, {
		__index = ClientProfile,
		__tostring = function(self)
			return "[Profile] - [" .. self.key .. "]"
		end,
	})

	self._type = ProfileType

	self.key = key

	self.replicator = Replicator.new(self.key)

	self.Changed = self.replicator.Changed
	self.Destroyed = self.replicator.Destroyed

	Profiles[self.key] = self
	LoadingProfiles[self.key] = nil

	return self
end

function ClientProfile.profileExists(plrOrKey)
	local isPlayer = typeof(plrOrKey) == "Instance" and plrOrKey.ClassName == "Player"
	Assert(isPlayer or typeof(plrOrKey) == "string", "Invalid argument #1 (must be a 'Player' instance or 'string')")

	local key = isPlayer and "profile_" .. plrOrKey.UserId or plrOrKey

	return Replicator.getReplicator(key) and true or false
end

function ClientProfile.is(profile)
	if typeof(profile) == "table" then
		return profile._type == ProfileType
	end
	return false
end

function ClientProfile:get()
	return self.replicator:get()
end

return ClientProfile.new(plr)
