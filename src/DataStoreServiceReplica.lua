local Util = script.Parent.Util
local Copy = require(Util.Copy)

local DataStoreKeyInfo = {}

function DataStoreKeyInfo.new()
	local self = setmetatable({}, { __index = DataStoreKeyInfo })
	self.CreatedTime = math.floor(os.time() * 1000)
	self.UpdatedTime = math.floor(os.time() * 1000)
	self.Version = ""
	self._metadata = {}
	self._userIds = {}
	return self
end

function DataStoreKeyInfo:GetMetadata()
	return self._metadata
end

function DataStoreKeyInfo:GetUserIds()
	return self._userIds
end

local DataStore = {}
local DataStores = {}

function DataStore.new(name, scope)
	scope = scope or "global"
	if DataStores[name .. scope] then
		return DataStores[name .. scope]
	end
	local self = setmetatable({}, {
		__index = DataStore,
		__tostring = function()
			return name
		end,
	})
	self.name = name
	self.scope = scope
	self.data = {}
	self._keyInfos = {}
	self._getCache = {}
	DataStores[name .. scope] = self
	return self
end

function DataStore:GetAsync(key)
	task.wait()
	local data = self.data[key]
	if not data then
		return
	end
	if self._getCache[key] then
		return self._getCache[key]
	else
		self._getCache[key] = data
		task.delay(4, function()
			self._getCache[key] = nil
		end)
	end
	return Copy(data), Copy(self._keyInfos[key])
end

function DataStore:RemoveAsync(key)
	task.wait()
	local data = self.data[key]
	if not data then
		return
	end
	self.data[key] = nil
	self._getCache[key] = nil
	return Copy(data), Copy(self._keyInfos[key])
end

function DataStore:SetAsync(key, value, userIds)
	task.wait()
	self.data[key] = value
	if not self._keyInfos[key] then
		self._keyInfos[key] = DataStoreKeyInfo.new()
	end
	local keyInfo = self._keyInfos[key]
	keyInfo._userIds = userIds
	keyInfo.UpdatedTime = math.floor(os.time() * 1000)
	return ""
end

function DataStore:UpdateAsync(key, transformFunction)
	task.wait()
	if not self._keyInfos[key] then
		self._keyInfos[key] = DataStoreKeyInfo.new()
	end
	local keyInfo = self._keyInfos[key]
	local data, userIds, metadata = transformFunction(Copy(self.data[key]), Copy(keyInfo))
	if not data then
		return
	else
		self.data[key] = data
		keyInfo._userIds = userIds or {}
		keyInfo._metadata = metadata or {}
		keyInfo.UpdatedTime = math.floor(os.time() * 1000)
		return Copy(data), Copy(keyInfo)
	end
end

local DataStorePages = {}

function DataStorePages.new(data, context)
	local self = setmetatable({}, { __index = DataStorePages })
	self.IsFinished = false
	self._data = {}
	self._currentPage = 1
	self._ascending = context.ascending
	self._pageSize = context.pageSize
	self._minValue = context.minValue or -math.huge
	self._maxValue = context.maxValue or math.huge

	local sorted = {}
	for key, value in data do
		table.insert(sorted, { key = key, value = value })
	end
	table.sort(sorted, function(a, b)
		if self._ascending then
			return a.value < b.value
		else
			return a.value > b.value
		end
	end)

	for _, data in sorted do
		if data.value >= self._minValue and data.value <= self._maxValue then
			table.insert(self._data, data)
		end
	end

	return self
end

function DataStorePages:GetCurrentPage()
	local page = {}
	local startIndex = (self._currentPage - 1) * self._pageSize + 1
	local endIndex = math.min(self._currentPage * self._pageSize, #self._data)
	for i = startIndex, endIndex do
		table.insert(page, { key = self._data[i].key, value = self._data[i].value })
	end
	return page
end

function DataStorePages:AdvanceToNextPageAsync()
	if not self.IsFinished then
		self._currentPage += 1
	else
		self._currentPage = 1
	end
	self.IsFinished = #self._data <= self._currentPage * self._pageSize
end

local OrderedDataStore = {}
local OrderedDataStores = {}

function OrderedDataStore.new(name, scope)
	scope = scope or "global"
	if OrderedDataStores[name .. scope] then
		return OrderedDataStores[name .. scope]
	end
	local self = setmetatable({}, {
		__index = OrderedDataStore,
		__tostring = function()
			return name
		end,
	})
	self.name = name
	self.scope = scope
	self.data = {}
	self._getCache = {}
	OrderedDataStores[name .. scope] = self
	return self
end

function OrderedDataStore:GetSortedAsync(ascending, pageSize, minValue, maxValue)
	task.wait()
	return DataStorePages.new(self.data, {
		ascending = ascending,
		pageSize = pageSize,
		minValue = minValue,
		maxValue = maxValue,
	})
end

function OrderedDataStore:GetAsync(key)
	task.wait()
	local data = self.data[key]
	if not data then
		return
	end
	if self._getCache[key] then
		return self._getCache[key]
	else
		self._getCache[key] = data
		task.delay(4, function()
			self._getCache[key] = nil
		end)
	end
	return Copy(data)
end

function OrderedDataStore:RemoveAsync(key)
	task.wait()
	local data = self.data[key]
	if not data then
		return
	end
	self.data[key] = nil
	self._getCache[key] = nil
	return Copy(data)
end

function OrderedDataStore:SetAsync(key, value)
	task.wait()
	self.data[key] = value
end

function OrderedDataStore:UpdateAsync(key, transformFunction)
	task.wait()
	local data = transformFunction(self.data[key])
	if not data then
		return
	else
		self.data[key] = data
		return Copy(data)
	end
end

local DataStoreService = {}

function DataStoreService.new()
	local self = setmetatable({}, { __index = DataStoreService })
	return self
end

function DataStoreService:GetDataStore(name, scope)
	return DataStore.new(name, scope)
end

function DataStoreService:GetOrderedDataStore(name, scope)
	return OrderedDataStore.new(name, scope)
end

return DataStoreService.new()
