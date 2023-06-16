local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Package = script.Parent

local Util = Package.Util
local Assert = require(Util.Assert)
local Assign = require(Util.Assign)
local Error = require(Util.Error)
local DeepEqual = require(Util.DeepEqual)
local Copy = require(Util.Copy)
local TypeMarker = require(Util.TypeMarker)

local Replicator = require(Package.Replicator)
local Signal = require(Package.Signal)
local Datastore = require(Package.Datastore)
local None = require(Package.None)

local IsStudio = RunService:IsStudio()

local function removeNone(tbl)
	for key, value in tbl do
		if typeof(value) == 'table' then
			removeNone(value)
		elseif value == None then
			tbl[key] = nil
		end
	end
end

local defaultSettings = {
	maxGetRequests = 4,
	maxSavesRequests = 10,
	maxDeleteRequests = 3,
	studioSave = false,
	mergeWithDefualt = true
}

local ProfileType = TypeMarker.Mark("[Profile]")

local ServerProfile = {}
local Profiles = {}

function ServerProfile.new(plrOrKey, settings)
	local isPlayer = typeof(plrOrKey) == "Instance" and plrOrKey.ClassName == "Player"
	Assert(
		isPlayer or typeof(plrOrKey) == "string",
		"Invalid argument #1 (must be a 'Player' object or type 'string')"
	)

	local key = isPlayer and 'profile_'..plrOrKey.UserId or plrOrKey

	if Profiles[key] ~= nil then
		if Profiles[key] == false then
			while not Profiles[key] do
				task.wait()
			end
		end
		return Profiles[key]
	end
	Profiles[key] = false

	local self = setmetatable({}, {
		__index = ServerProfile,
		__tostring = function(self)
			return ProfileType..' - ['..self.key..']'
		end
	})

	self._type = ProfileType

	self.key = key
	self.datastore = Datastore.new(self.key)

	self.replicator = Replicator.new({
		key = self.key,
		data = {
			data = {},
			_isLoaded = false
		},
		players = { isPlayer and key or nil },
	})

	self:_applySettings(settings)

	self.shouldSaveProfileData = false
	self.shouldSaveDataVersion = false
	self.shouldSaveVersions = false

	self.dataVersion = self:_getDataVersion()
	self.versions = self:_getVersions()
	self.cache = {self:get()}

	if self.cache[1] == self.default then
		self.shouldSaveProfileData = true
	else
		if self.settings.mergeWithDefualt then
			self:merge(self.default)
		end
	end

	self.replicator:set({
		data = self:get(),
		_isLoaded = true,
	})

	self._lastSaveTime = os.clock()

	self.Changed = self.replicator.Changed
	self.Saved = Signal.new()
	self.Deleted = Signal.new()
	self.Destroyed = self.replicator.Destroyed

	Profiles[self.key] = self

	return self
end

function ServerProfile.is(profile)
	if typeof(profile) == "table" then
		return profile._type == ProfileType
	end
	return false
end

function ServerProfile:get()
	if #self.cache > 0 then
		return Copy(self.cache[#self.cache])
	end
	local result = self.datastore:request("ProfileData", self.settings.maxGetRequests)
	Assert(result.success, "An error occured when getting profile [" .. self.key .. "] - "..result.message)
	local data = result.data
	if not data then
		data = self.default
	else
		data = self:_migrate(data)
	end
	return data
end

function ServerProfile:set(data, hard)
	Assign(typeof(data) == 'table', "Invalid argument #1 (must be a 'table'")

	local oldProfileData = self.cache[#self.cache]
	local newProfileData
	if hard then
		newProfileData = data
	elseif typeof(data) == "table" and typeof(oldProfileData) == "table" then
		newProfileData = Assign({}, oldProfileData, data)
	end
	removeNone(newProfileData)
	
	if not DeepEqual(oldProfileData, newProfileData) then
		self.shouldSaveProfileData = true
		self.shouldSaveVersions = true
		table.insert(self.cache, newProfileData)
		self.replicator:set({
			data = newProfileData
		})
	end
end

--[[
	tbl1 = {
		a = 1,
		b = 2,
		c = {
			a = 1,
			b = 2
		}
	},

	tbl2 = {
		a = 2,
		b = 1,
		c = {
			c = {
				a = 1,
				b = 2
			}
		}
	},
]]

function ServerProfile:merge(data)
	Assert(typeof(data) == 'table', "Invalid argument #1 (must be a 'table'")
	local function merge(tbl1, tbl2)
		for key, value in pairs(tbl2) do
			if typeof(value) == "table" and typeof(tbl1[key]) == "table" then
				merge(tbl1[key], value)
			else
				tbl1[key] = value
			end
		end
		return tbl1
	end
	self:set(merge(self:get(), data), true)
end

function ServerProfile:getVersions()
	return self.versions
end

function ServerProfile:setVisibility(players)
	self.replicator:setPlayers(players)
end

function ServerProfile:save()
	if IsStudio and not self.settings.studioSave then
		return false
	end
	self._lastSaveTime = os.clock()
	if self.shouldSaveProfileData then
		local result = self.datastore:save("ProfileData", self:get(), self.settings.maxSaveRequests)

		if not result.success then
			Error("Couldn't save 'ProfileData'")
		end
		self.shouldSaveProfileData = false
	end
	if self.shouldSaveDataVersion then
		local result = self.datastore:save("DataVersion", self.dataVersion, self.settings.maxSaveRequests)

		if not result.success then
			Error("Couldn't save 'DataVersion'")
		end
		self.shouldSaveDataVersion = false
	end
	if self.shouldSaveVersions then
		table.insert(self.versions, self:get())
		local result = self.datastore:save("DataVersion", self.versions, self.settings.maxSaveRequests)

		if not result.success then
			Error("Couldn't save 'Versions'")
		end
		self.shouldSaveVersions = false
	end
	self.Saved:Fire()
end

function ServerProfile:delete(hard)
	local result = self.datastore:delete("ProfileData", self.settings.maxDeleteRequests)
	if not result.success then
		Error("Couldn't delete 'ProfileData'")
	end
	result = self.datastore:delete("DataVersion", self.settings.maxDeleteRequests)
	if not result.success then
		Error("Couldn't delete 'DataVersion'")
	end
	if hard then
		result = self.datastore:delete("Versions", self.settings.maxDeleteRequests)
		if not result.success then
			Error("Couldn't delete 'Versions'")
		end
	end
	self.Deleted:Fire()
end

function ServerProfile:Destroy()
	if not Profiles[self.key] then
		return
	end
	Profiles[self.key] = nil

	self:save()

	self.Changed:DisconnectAll()
	self.Saved:DisconnectAll()
	self.Deleted:DisconnectAll()
	self.Destroyed:DisconnectAll()

	self.replicator:Destroy()

	setmetatable(self, {})
end

function ServerProfile:_applySettings(settings)
	Assert(
		not settings.maxGetRequests or typeof(settings.maxGetRequests) == "number",
		"Invalid argument #2 (settings.maxGetRequests must be of type 'number' or 'nil')"
	)
	Assert(
		not settings.maxSaveRequests or typeof(settings.maxSaveRequests) == "number",
		"Invalid argument #2 (settings.maxSaveRequests must be of type 'number' or 'nil')"
	)
	Assert(
		not settings.maxDeleteRequests or typeof(settings.maxDeleteRequests) == "number",
		"Invalid argument #2 (settings.maxDeleteRequests must be of type 'number' or 'nil')"
	)
	Assert(
		not settings.studioSave or typeof(settings.studioSave) == "boolean",
		"Invalid argument #2 (settings.studioSave must be of type 'boolean' or 'nil')"
	)
	Assert(
		not settings.default or (typeof(settings.default) == "table"),
		"Invalid argument #2 (settings.default must be of type 'table' or 'nil')"
	)
	Assert(
		not settings.mergeWithDefualt or (typeof(settings.mergeWithDefualt) == "boolean"),
		"Invalid argument #2 (settings.mergeWithDefualt must be of type 'boolean' or 'nil')"
	)
	Assert(
		not settings.migrators or typeof(settings.migrators) == "table",
		"Invalid argument #2 (settings.migrators must be of type 'table' or 'nil')"
	)
	Assert(
		not settings.saveInterval or typeof(settings.saveInterval) == 'number',
		"Invalid argument #2 (settings.saveInterval must be of type 'number' or 'nil')"
	)

	self.settings = {
		maxGetRequests = settings.maxGetRequests or defaultSettings.maxGetRequests,
		maxSaveRequests = settings.maxSaveRequests or defaultSettings.maxSaveRequests,
		maxDeleteRequests = settings.maxDeleteRequests or defaultSettings.maxDeleteRequests,
		studioSave = settings.studioSave or defaultSettings.studioSave,
		mergeWithDefualt = settings.mergeWithDefualt == nil and defaultSettings.mergeWithDefualt or settings.mergeWithDefualt,
		saveInterval = settings.saveInterval and math.max(settings.saveInterval, 1)
	}
	self.default = settings.default
	self.migrators = settings.migrators
end

function ServerProfile:_migrate(profileData)
	local dataVersion = #self.migrators + 1
	if self.migrators then
		if self.dataVersion < dataVersion then
			for i = self.dataVersion, dataVersion do
				local newProfileData = self.migrators[i](profileData)
				Assert(newProfileData, "Migrator function must return a value")
				profileData = newProfileData
			end
			self.shouldSaveDataVersion = true
			self.dataVersion = dataVersion
		end
	end
	return profileData
end

function ServerProfile:_getDataVersion()
	local success, dataVersion = self.datastore:requestIterator("DataVersion", self.settings.mexGetRequests)
	Assert(success, "An error occured when getting DataVersion on profile [" .. self.key .. "] -", dataVersion)
	if not dataVersion then
		return self.migrators and #self.migrators + 1 or 1
	end
	return dataVersion
end

function ServerProfile:_getVersions()
	local success, data = self.datastore:requestIterator("Versions", self.settings.mexGetRequests)
	Assert(success, "An error occured when getting Versions of profile [" .. self.key .. "] -", data)
	return data or {}
end

game:BindToClose(function()
	for _, profile in pairs(Profiles) do
		profile:Destroy()
	end
end)

Players.PlayerRemoving:Connect(function(plr)
	local profile = Profiles['profile_'..plr.UserId]
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
