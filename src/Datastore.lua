local DSS = game:GetService("DataStoreService")
local RunService = game:GetService('RunService')

local Package = script.Parent

local Util = script.Parent.Util
local Assert = require(Util.Assert)
local Copy = require(Util.Copy)

local DataStoreServiceReplica = require(Package.DataStoreServiceReplica)

local IsStudio = RunService:IsStudio()

local shouldUseReplica = false
if game.GameId == 0 then
	shouldUseReplica = true
elseif IsStudio then
	local success, message = pcall(function()
		DSS:GetDataStore("__STUDIO_API_ACCESS_TEST__"):SetAsync("__Value__", "__" .. os.time() .. '__')
	end)
	if not success and message:find("403", 1, true) then
		shouldUseReplica = true
	end
end
if shouldUseReplica then
	DSS = DataStoreServiceReplica
end

local Settings = {
	RequestCooldown = 5,
	MaxSaveAttempts = 10,
	ForceSessionAttempts = 5,
	ForceSessionTime = 60 * 15
}

local DataStore = {}
DataStore.SessionId = game.PlaceId..'/'..game.JobId
DataStore._getQueue = {}
DataStore._setQueue = {}

function DataStore.new(name, sessionLock)
	local self = setmetatable({}, {__index = DataStore})
	self.name = name
	self.sessionLock = sessionLock
	self.dataStore = DSS:GetDataStore(name)
	self.versionDataStore = DSS:GetOrderedDataStore(name)
	return self
end

function DataStore:get(default)
	local SessionId = DataStore.SessionId

	local hasSession = false
	local forceSession = false
	
	local fetchedData
	local newProfile = false
	for i = 1, Settings.ForceSessionAttempts+1 do
		local version = self:_getVersion()
		self.dataStore:UpdateAsync(version, function(data)
			if not data then
				data = default
				newProfile = true
			end
			if self.sessionLock then
				if forceSession then
					hasSession = true
				elseif data.Metadata then
					if data.Metadata.LastUpdate and (os.time() - data.Metadata.LastUpdate >= Settings.ForceSessionTime) then
						hasSession = true
					elseif data.Metadata.SessionId == nil or data.Metadata.SessionId == SessionId then
						hasSession = true
					end
				else
					hasSession = true
				end
				if hasSession then
					data.Metadata = {
						SessionId = SessionId,
						LastUpdate = os.time()
					}
					fetchedData = data
					return data
				end
			else
				if not data then
					data = default
					newProfile = true
				end
				data.Metadata = {
					LastUpdate = os.time()
				}
				fetchedData = data
				hasSession = true
				return data
			end
		end)
		if hasSession then
			break
		end
		if i >= Settings.ForceSessionAttempts then
			forceSession = true
			continue
		end
		task.wait(Settings.RequestCooldown)
	end

	return fetchedData, newProfile
end

function DataStore:set(value, removeSession)
	Assert(typeof(value) == "table", "Invalid argument #1 (must be a 'table')")
	value = Copy(value)

	local SessionId = DataStore.SessionId
	
	local Metadata
	local didSave
	for _ = 1, Settings.MaxSaveAttempts do
		local version = self:_getVersion() + 1
		if self.sessionLock then
			pcall(function()
				self.dataStore:UpdateAsync(version-1, function(data)
					if data.Metadata then
						if data.Metadata.SessionId == SessionId then
							Metadata = data.Metadata
						end
					else
						Metadata = {}
					end
				end)
			end)
		end
		if Metadata or not self.sessionLock then
			local success = pcall(function()
				self.dataStore:UpdateAsync(version, function()
					if self.sessionLock then
						if removeSession then
							value.Metadata = Metadata
							value.Metadata.SessionId = nil
							return value
						else
							value.Metadata = Metadata
							value.Metadata.LastUpdate = os.time()
							return value
						end
					else
						return value
					end
				end)
			end)
			if success then
				didSave = true
			end
		end
		if didSave then
			local success = pcall(function()
				self.versionDataStore:SetAsync(version, version)
			end)
			if success then
				return true
			end
		end
		task.wait(Settings.RequestCooldown)
	end
	return false
end

function DataStore:_getVersion()
	local versionStore = self.versionDataStore:GetSortedAsync(false, 1):GetCurrentPage()[1]
	if not versionStore then
		self.versionDataStore:SetAsync(1, 1)
		return 1
	else
		return versionStore.value
	end
end

local OrderedDataStore = {}

function OrderedDataStore.new(name)
	local self = setmetatable({}, {__index = OrderedDataStore})
	self.orderedDataStore = DSS:GetOrderedDataStore(name)
	return self
end

function OrderedDataStore:getPage(pageSize, ascending, minValue, maxValue)
	Assert(typeof(pageSize) == "number", "Invalid argument #1 (must be a 'number')")
	Assert(typeof(ascending) == "boolean", "Invalid argument #2 (must be a 'boolean')")
	return self.orderedDataStore:GetSortedAsync(ascending, pageSize, minValue, maxValue):GetCurrentPage()
end

function OrderedDataStore:index(key, number)
	Assert(typeof(key) == "string", "Invalid argument #1 (must be a 'string')")
	Assert(typeof(number) == "number" and number >= 0, "Invalid argument #2 (must be a positive 'number')")
	self.orderedDataStore:SetAsync(key, number)
end

return {
	useStoreReplica = function(value)
		DSS = value and DataStoreServiceReplica or game:GetService('DataStoreService')
	end,
	NormalDataStore = DataStore,
	OrderedDataStore = OrderedDataStore
}
