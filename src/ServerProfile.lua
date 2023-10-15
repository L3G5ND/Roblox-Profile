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

local IsStudio = RunService:IsStudio()

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
	autoKick = true
}

local Profile = {}
local OrderedProfile = {}

local ProfileType = TypeMarker.Mark("[Profile]")
local OrderedProfileType = TypeMarker.Mark("[OrderedProfile]")

Profile.Profiles = {}
local LoadingProfiles = {}

function Profile.ordered(key)
	Assert(typeof(key) == "string", "Invalid argument #1 (must be a 'string')")
	local self = setmetatable({
		_type = OrderedProfileType
	}, {
		__index = OrderedProfile,
		__tostring = function(self)
			return "[Profile] - (Ordered)[" .. self.key .. "]"
		end,
	})
	self.key = key
	self.dataStore = DataStore.OrderedDataStore.new(self.key)
	return self
end

function OrderedProfile:getPage(pageSize, ascending, minValue, maxValue)
	if ascending == nil then
		ascending = false
	end
	Assert(typeof(pageSize) == "number", "Invalid argument #1 (must be a 'number')")
	Assert(typeof(ascending) == "boolean", "Invalid argument #2 (must be a 'boolean')")
	Assert(minValue == nil or typeof(minValue) == "number", "Invalid argument #3 (must be a 'number')")
	Assert(maxValue == nil or typeof(maxValue) == "number", "Invalid argument #4 (must be a 'boolean')")
	return self.dataStore:getPage(pageSize, ascending, minValue, maxValue)
end

function OrderedProfile:index(key, number)
	key = tostring(key)
	Assert(typeof(key) == "string", "Invalid argument #1 (must be a 'string' or a 'number')")
	Assert(typeof(number) == "number" and number >= 0, "Invalid argument #2 (must be a positive 'number')")
	self.dataStore:index(key, number)
end

local function validateSetting(settings, setting, settingType)
	Assert(
		settings[setting] == nil or typeof(settings[setting]) == settingType,
		"Invalid argument #2 (settings."..setting.." must be of a '"..settingType.."')"
	)
	if settings[setting] == nil then
		if defaultSettings[setting] then
			settings[setting] = defaultSettings[setting]
		end
	end
end

function Profile.new(plrOrKey, settings)
	local isPlayer = typeof(plrOrKey) == "Instance" and plrOrKey.ClassName == "Player"
	Assert(isPlayer or typeof(plrOrKey) == "string", "Invalid argument #1 (must be a 'Player' instance or 'string')")

	local key = isPlayer and "profile_" .. plrOrKey.UserId or plrOrKey

	if Profile.Profiles[key] then
		if Profile.Profiles[key]._isDestroyed then
			while Profile.Profiles[key] do
				task.wait()
			end
		else
			return Profile.Profiles[key]
		end
	end
	if LoadingProfiles[key] then
		while not Profile.Profiles[key] do
			task.wait()
		end
		return Profile.Profiles[key]
	end
	LoadingProfiles[key] = true

	local self = setmetatable({
		_type = ProfileType
	}, {
		__index = Profile,
		__tostring = function(self)
			return "[Profile] - [" .. self.key .. "]"
		end,
	})

	if isPlayer then
		self.player = plrOrKey
	end

	local useSessionLock = isPlayer
	if settings.useSessionLock == false then
		useSessionLock = false
	else
		useSessionLock = true
	end

	self.key = key
	self.dataStore = DataStore.NormalDataStore.new(self.key, useSessionLock)

	settings = settings or {}

	validateSetting(settings, 'studioSave', 'boolean')
	validateSetting(settings, 'default', 'table')
	validateSetting(settings, 'mergeWithDefault', 'boolean')
	validateSetting(settings, 'migrators', 'table')
	validateSetting(settings, 'saveInterval', 'number')
	validateSetting(settings, 'autoKick', 'boolean')

	if settings.migrators then
		for i, migrator in settings.migrators do
			Assert(
				typeof(migrator) == "function",
				"Invalid argument #2 (settings.migrator[" .. i .. "] must be a 'function')"
			)
		end
	end

	self.settings = settings
	self.default = settings.default
	self.migrators = settings.migrators

	self.shouldSave = false

	local profileData
	local newProfile
	local success, message = pcall(function()
		profileData, newProfile = self.dataStore:get({
			data = self.default,
			version = 1
		})
	end)
	if not success then
		if self.player then
			self.player:Kick('An error occured when getting profile data. (Please try again)')
		end
		return
	end
	
	self.version = profileData.version
	self.data = self:_migrate(profileData.data)

	self._lastSaveTime = os.clock()
	self._isDestroyed = false

	if newProfile then
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

	Profile.Profiles[self.key] = self
	LoadingProfiles[self.key] = nil

	return self
end

function Profile:get()
	return Copy(self.data)
end

function Profile:set(data, hard)
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
		self.shouldSave = true
		self.data = newProfileData
		if self.replicator then
			self.replicator:set(newProfileData)
		end
	end
end

function Profile:merge(data)
	Assert(typeof(data) == "table", "Invalid argument #1 (must be a 'table')")
	self:set(merge(self:get(), data), true)
end

function Profile:setVisibility(players)
	self.replicator:setPlayers(players)
end

function Profile:save(removeSession)
	if IsStudio and not self.settings.studioSave then
		return true
	end
	self._lastSaveTime = os.clock()
	if self.shouldSave or removeSession then
		local success = pcall(function()
			self.dataStore:set({
				data = self:get(),
				version = self.version
			}, removeSession)
		end)
		if success then
			self.Saved:Fire()
			self.shouldSave = false
		else
			return false
		end
	end
	return true
end

function Profile:_migrate(profileData)
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

function Profile:Destroy()
	if self._isDestroyed then
		return
	end
	self._isDestroyed = true

	self:save(true)

	self.Changed:DisconnectAll()
	self.Saved:DisconnectAll()
	self.Destroyed:DisconnectAll()

	self.replicator:Destroy()

	Profile.Profiles[self.key] = nil
end

function Profile.is(profile)
	if typeof(profile) == "table" then
		return profile._type == ProfileType
	end
	return false
end

function Profile.isOrdered(profile)
	if typeof(profile) == "table" then
		return profile._type == OrderedProfileType
	end
	return false
end

game:BindToClose(function()
	for _, profile in Profile.Profiles do
		profile:Destroy()
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	local profile = Profile.Profiles["profile_" .. plr.UserId]
	if profile then
		profile:Destroy()
	end
end)

RunService.Heartbeat:Connect(function()
	for _, profile in Profile.Profiles do
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

return setmetatable(Profile, {
	__call = function(_, ...)
		return Profile.new(...)
	end,
})
