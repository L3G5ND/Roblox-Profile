local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Package = script.Parent

local Util = Package.Util
local Assert = require(Util.Assert)
local Assign = require(Util.Assign)
local Error = require(Util.Error)
local DeepEqual = require(Util.DeepEqual)
local Copy = require(Util.Copy)
local TypeMarker = require(Util.TypeMarker)

local Replicator = require(Package.Replicator)

local plr = Players.LocalPlayer

local function expect(callback, errorMsg, timeout)
	timeout = timeout or 10
	local startTime = os.clock()
	while true do
		if callback() == true then
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

function ClientProfile.new(plrOrKey)
	local isPlayer = typeof(plrOrKey) == "Instance" and plrOrKey.ClassName == "Player"
	Assert(
		isPlayer or typeof(plrOrKey) == "string",
		"Invalid argument #1 (must be a 'Player' object or type 'string')"
	)

	local key = isPlayer and 'profile_'..plrOrKey.UserId or plrOrKey

	if Profiles[key] ~= nil then
		if Profiles[key] == false then
			expect(function()
				return Profiles[key] == true
			end, "Wasn't able to get profile '"..key.."'")
		end
		return Profiles[key]
	end
	Profiles[key] = false

	local self = setmetatable({}, {
		__index = ClientProfile,
		__tostring = function(self)
			return ProfileType..' - ['..self.key..']'
		end
	})

	self._type = ProfileType

	self.key = key

	self.replicator = Replicator.new(self.key)

	expect(function()
		return self.replicator:get()._isLoaded == true
	end, "Couldn't load profile in time '"..key.."'")

	self.Changed = self.replicator.Changed
	self.Destroyed = self.replicator.Destroyed

	Profiles[self.key] = self

	return self
end

function ClientProfile.is(profile)
	if typeof(profile) == "table" then
		return profile._type == ProfileType
	end
	return false
end

function ClientProfile:get()
	return self.replicator:get().data
end

return ClientProfile.new(plr)
