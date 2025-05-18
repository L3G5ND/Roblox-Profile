local Players = game:GetService("Players")

local Package = script.Parent

local Util = Package.Util
local Assert = require(Util.Assert)
local Error = require(Util.Error)
local TypeMarker = require(Util.TypeMarker)
local Assign = require(Util.Assign)

local Replicator = require(Package.Replicator)
local Signal = require(Package.Signal)
local ChangedCallback = require(Package.ChangedCallback)

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

local function signalWrapper(signal, events)
	events = events or {}
	return {
		Connect = function(_, ...)
			if events.Connect then
				return events.Connect(signal, ...)
			end
			return signal:Connect(...)
		end,
		Once = function(_, ...)
			if events.Once then
				return events.Once(signal, ...)
			end
			return signal:Once(...)
		end,
		Wait = function()
			if events.Wait then
				return events.Wait(signal)
			end
			return signal:Wait()
		end,
		DisconnectAll = function()
			if events.DisconnectAll then
				return events.DisconnectAll(signal)
			end
			signal:DisconnectAll()
		end
	}
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
		end, "Wasn't able to get profile '" .. key .. "'", 30)
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
	if isPlayer and plrOrKey == plr then
		self.privateReplicator = Replicator.new(self.key.."_Private")
	end

	self.Destroyed = self.replicator.Destroyed

	self._ChangedSignal = Signal.new()
	self.Changed = signalWrapper(self._ChangedSignal, {
		Connect = function(_, ...)
			return self._ChangedSignal:Connect(ChangedCallback(...))
		end,
		Once = function(_, ...)
			return self._ChangedSignal:Once(ChangedCallback(...))
		end
	})

	self.replicator.Changed:Connect(function(newData, oldData)
		self._ChangedSignal:Fire(newData, oldData)
	end)
	if self.privateReplicator then
		self.privateReplicator.Changed:Connect(function(newData, oldData)
			self._ChangedSignal:Fire(newData, oldData)
		end)
	end

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
	local data = self.replicator:get()
	if self.privateReplicator then
		Assign(data, self.privateReplicator:get())
	end
	return data
end

return ClientProfile.new(plr)
