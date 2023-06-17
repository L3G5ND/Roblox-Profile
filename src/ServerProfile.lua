local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Package = script.Parent

local Util = Package.Util
local Assert = require(Util.Assert)
local Assign = require(Util.Assign)
local DeepEqual = require(Util.DeepEqual)
local Copy = require(Util.Copy)
local TypeMarker = require(Util.TypeMarker)

local Replicator = require(Package.Replicator)
local Signal = require(Package.Signal)
local DataStore = require(Package.DataStore)
local None = require(Package.None)

local isStudio = RunService:IsStudio()

local function removeNone(tbl)
	for key, value in tbl do
		if typeof(value) == "table" then
			removeNone(value)
		elseif value == None then
			tbl[key] = nil
		end
	end
end

local function merge(tbl1, tbl2)
	for key, value in tbl2 do
		if typeof(value) == "table" and typeof(tbl1[key]) == "table" then
			merge(tbl1[key], value)
		elseif tbl1[key] == nil then
			tbl1[key] = value
		end
	end
	return tbl1
end

local defaultSettings = {
	studioSave = true,
	mergeWithDefault = true,
	default = {},
	migrators = {},
	saveInterval = nil,
}

local ProfileType = TypeMarker.Mark("[Profile]")

local ServerProfile = {}
local Profiles = {}
local LoadingProfiles = {}

function ServerProfile.new(plrOrKey, settings)
	local isPlayer = typeof(plrOrKey) == "Instance" and plrOrKey.ClassName == "Player"
	Assert(isPlayer or typeof(plrOrKey) == "string", "Invalid argument #1 (must be a 'Player' instance or 'string')")

	local key = isPlayer and "profile_" .. plrOrKey.UserId or plrOrKey

	if Profiles[key] then
		return Profiles[key]
	end
	if LoadingProfiles[key] then
		while not Profiles[key] do
			task.wait()
		end
		return Profiles[key]
	end
	LoadingProfiles[key] = true

	local self = setmetatable({}, {
		__index = ServerProfile,
		__tostring = function(self)
			return "[Profile] - [" .. self.key .. "]"
		end,
	})

	self._type = ProfileType

	self.key = key
	self.dataStore = DataStore.new(self.key)

	self:_applySettings(settings)

	self.shouldSaveDataStore = false
	self.shouldSaveOrderedDataStore = false

	local profileData = self:_get()
	self.version = profileData.version
	self.data = self:_migrate(profileData.data)
	self.orderedData = {}

	self._lastSaveTime = os.clock()
	self._isDestroyed = false

	if self.data == self.default then
		self.shouldSave = true
	else
		if self.settings.mergeWithDefault then
			self:merge(self.default)
		end
	end

	self.replicator = Replicator.new({
		key = self.key,
		data = self:get(),
		players = { isPlayer and plrOrKey or nil },
	})

	self.Changed = self.replicator.Changed
	self.Saved = Signal.new()
	self.Destroyed = self.replicator.Destroyed

	Profiles[self.key] = self
	LoadingProfiles[self.key] = nil

	return self
end

function ServerProfile.is(profile)
	if typeof(profile) == "table" then
		return profile._type == ProfileType
	end
	return false
end

function ServerProfile:get()
	return Copy(self.data)
end

function ServerProfile:set(data, hard)
	Assert(typeof(data) == "table", "Invalid argument #1 (must be a 'table')")

	local oldProfileData = self.data
	local newProfileData
	if hard then
		newProfileData = data
	elseif typeof(data) == "table" and typeof(oldProfileData) == "table" then
		newProfileData = Assign({}, oldProfileData, data)
	end
	removeNone(newProfileData)

	if not DeepEqual(oldProfileData, newProfileData) then
		self.shouldSaveDataStore = true
		self.data = newProfileData
		if self.replicator then
			self.replicator:set(newProfileData)
		end
	end
end

function ServerProfile:merge(data)
	Assert(typeof(data) == "table", "Invalid argument #1 (must be a 'table')")
	self:set(merge(self:get(), data), true)
end

function ServerProfile:getPage(pageSize, ascending, minValue, maxValue)
	if ascending == nil then
		ascending = false
	end
	Assert(typeof(pageSize) == "number", "Invalid argument #1 (must be a 'number')")
	Assert(typeof(ascending) == "boolean", "Invalid argument #2 (must be a 'boolean')")
	Assert(minValue == nil or typeof(minValue) == "number", "Invalid argument #3 (must be a 'number')")
	Assert(maxValue == nil or typeof(maxValue) == "number", "Invalid argument #4 (must be a 'boolean')")
	return self.dataStore:getPage(pageSize, ascending, minValue, maxValue)
end

function ServerProfile:index(key, number)
	key = tostring(key)
	Assert(typeof(key) == "string", "Invalid argument #1 (must be a 'string' or a 'number')")
	Assert(typeof(number) == "number" and number >= 0, "Invalid argument #2 (must be a positive 'number')")
	self.orderedData[key] = number
	self.shouldSaveOrderedDataStore = true
end

function ServerProfile:setVisibility(players)
	self.replicator:setPlayers(players)
end

function ServerProfile:save()
	if self._isDestroyed then
		return
	end
	if isStudio and not self.settings.studioSave then
		return false
	end
	self._lastSaveTime = os.clock()
	if self.shouldSaveDataStore then
		self.dataStore:set({
			data = self:get(),
			version = self.version,
		})
		self.shouldSaveDataStore = false
	end
	if self.shouldSaveOrderedDataStore then
		for key, number in self.orderedData do
			self.dataStore:index(key, number)
			self.shouldSaveOrderedDataStore = false
		end
	end
	self.Saved:Fire()
end

function ServerProfile:Destroy()
	if not Profiles[self.key] then
		return
	end
	Profiles[self.key] = nil

	self:save()

	self.Changed:DisconnectAll()
	self.Saved:DisconnectAll()
	self.Destroyed:DisconnectAll()

	self.replicator:Destroy()

	self._isDestroyed = true
end

function ServerProfile:_applySettings(settings)
	settings = settings or {}
	Assert(
		not settings.studioSave or typeof(settings.studioSave) == "boolean",
		"Invalid argument #2 (settings.studioSave must be of a 'boolean')"
	)
	Assert(
		not settings.default or (typeof(settings.default) == "table"),
		"Invalid argument #2 (settings.default must be of a 'table')"
	)
	Assert(
		not settings.mergeWithDefault or (typeof(settings.mergeWithDefualt) == "boolean"),
		"Invalid argument #2 (settings.mergeWithDefault must be of a 'boolean')"
	)
	Assert(
		not settings.migrators or typeof(settings.migrators) == "table",
		"Invalid argument #2 (settings.migrators must be of a 'table')"
	)
	Assert(
		not settings.saveInterval or typeof(settings.saveInterval) == "number",
		"Invalid argument #2 (settings.saveInterval must be of a 'number')"
	)

	if settings.migrators then
		for i, migrator in settings.migrators do
			Assert(
				typeof(migrator) == "function",
				"Invalid argument #2 (settings.migrator[" .. i .. "] must be a 'function')"
			)
		end
	end

	self.settings = {
		studioSave = settings.studioSave or defaultSettings.studioSave,
		mergeWithDefault = settings.mergeWithDefault == nil and defaultSettings.mergeWithDefault
			or settings.mergeWithDefualt,
		saveInterval = settings.saveInterval or defaultSettings.saveInterval,
	}
	self.default = settings.default
	self.migrators = settings.migrators
end

function ServerProfile:_migrate(profileData)
	if self.migrators then
		local version = #self.migrators + 1
		if self.migrators then
			if self.version < version then
				for i = self.version, version - 1 do
					local newProfileData = self.migrators[i](profileData)
					Assert(typeof(newProfileData) == "table", "Migrator must return a 'table'")
					profileData = newProfileData
				end
				self.version = version
			end
		end
	end
	return profileData
end

function ServerProfile:_get()
	local data = self.dataStore:get()
	if not data then
		data = {
			data = self.default,
			version = 1,
		}
	end
	return data
end

game:BindToClose(function()
	for _, profile in Profiles do
		profile:Destroy()
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	local profile = Profiles["profile_" .. plr.UserId]
	if profile then
		profile:Destroy()
	end
end)

RunService.Heartbeat:Connect(function()
	for _, profile in Profiles do
		local saveInterval = profile.settings.saveInterval
		if saveInterval then
			if os.clock() - profile._lastSaveTime >= saveInterval then
				task.spawn(function()
					profile:save()
				end)
			end
		end
	end
end)

return setmetatable(ServerProfile, {
	__call = function(_, ...)
		return ServerProfile.new(...)
	end,
})
