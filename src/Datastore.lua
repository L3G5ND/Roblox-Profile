local DSS = game:GetService("DataStoreService")
local RunService = game:GetService('RunService')

local Package = script.Parent

local Util = script.Parent.Util
local Assert = require(Util.Assert)

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

local DataStore = {}
DataStore.SessionId = game.PlaceId..'/'..game.JobId

function DataStore.new(name)
	local self = setmetatable({}, {__index = DataStore})
	self.dataStore = DSS:GetDataStore(name)
	self.versionDataStore = DSS:GetOrderedDataStore(name)
	self.version = self:_getVersion()
	return self
end

function DataStore:get()
	local isCorrupted = false
	local hasSession = false

	local data
	self.dataStore:UpdateAsync(self.version, function(value, userIds, metadata)
		if value and typeof(value) ~= 'table' then
			isCorrupted = true
			return
		end
		data = value
		if value.sessionId == nil or value.sessionId == DataStore.SessionId then
			value.sessionId = DataStore.SessionId
			hasSession = true
			return value
		else
			return
		end
	end)

	if isCorrupted then
		self:setVersion(self:_getVersion())
		return self:get()
	end

	if not hasSession then
		print('doesnt have session')
	end

	return data
end

function DataStore:set(value)
	Assert(typeof(value) == "table", "Invalid argument #1 (must be a 'table')")
	local isCorrupted = false
	local hasSession = false
	local version = self.version + 1
	self.dataStore:UpdateAsync(version, function(_, userIds, metadata)
		if value and typeof(value) ~= 'table' then
			isCorrupted = true
			return
		end
		if value.sessionId == DataStore.SessionId then
			value.sessionId = nil
			hasSession = true
			return value
		else
			return
		end
	end)

	if isCorrupted then
		self:setVersion(self:_getVersion())
		return self:set(value)
	end

	if not hasSession then
		print('doesnt have session')
	end

	self.versionDataStore:SetAsync(version, version)
end

function DataStore:setVersion(version)
	local currentVersion = self:_getVersion()
	Assert(version < currentVersion, "Invalid argument #1 (must be less that the 'DataStores' current version)")
	for i = 1, currentVersion - version do
		self.versionDataStore:RemoveAsync(currentVersion - i)
		self.dataStore:RemoveAsync(currentVersion - i)
	end
	self.version = version
end

function DataStore:_getVersion()
	local keyStore = self.versionDataStore:GetSortedAsync(false, 1):GetCurrentPage()[1]
	if not keyStore then
		return 0
	else
		return keyStore.value
	end
end

local OrderedDataStore = {}

function OrderedDataStore.new(name)
	local self = setmetatable({}, {__index = DataStore})
	self.orderedDataStore = DSS:GetOrderedDataStore(name, 'Ordered')
	return self
end

function OrderedDataStore:getPage(pageSize, ascending, minValue, maxValue)
	Assert(typeof(pageSize) == "number", "Invalid argument #1 (must be a 'number')")
	Assert(typeof(ascending) == "boolean", "Invalid argument #2 (must be a 'boolean')")
	local data
	local success, message = pcall(function()
		data = self.versionDataStore:GetSortedAsync(ascending, pageSize, minValue, maxValue):GetCurrentPage()
	end)
	Assert(success, message)
	return data
end

function OrderedDataStore:index(key, number)
	Assert(typeof(key) == "string", "Invalid argument #1 (must be a 'string')")
	Assert(typeof(number) == "number" and number >= 0, "Invalid argument #2 (must be a positive 'number')")
	local success, message = pcall(function()
		self.orderedDataStore:SetAsync(key, number)
	end)
	Assert(success, message)
end

return {
	DataStore = DataStore,
	OrderedDataStore = OrderedDataStore
}
