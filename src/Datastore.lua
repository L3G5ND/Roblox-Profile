local DSS = game:GetService("DataStoreService")

local Util = script.Parent.Util
local Assert = require(Util.Assert)

local DataStore = {}

function DataStore.new(key)
	local self = setmetatable({}, {
		__index = DataStore,
		__tostring = function()
			return "[DataStore]"
		end,
	})

	self.key = nil
	self.dataStore = DSS:GetDataStore(key)
	self.keyDataStore = DSS:GetOrderedDataStore(key)
	self.orderedDataStore = DSS:GetOrderedDataStore(key)

	return self
end

function DataStore:get()
	local data
	local success, message = pcall(function()
		local keyStore = self.keyDataStore:GetSortedAsync(false, 1):GetCurrentPage()[1]
		if not keyStore then
			return
		end
		self.key = keyStore.value
		self.dataStore:UpdateAsync(self.key, function(value)
			data = value
		end)
	end)
	Assert(success, message)
	return data
end

function DataStore:set(value)
	Assert(typeof(value) == "table", "Invalid argument #1 (must be a 'table')")
	local success, message = pcall(function()
		local key = self.key and self.key + 1 or 1
		self.dataStore:UpdateAsync(key, function()
			return value
		end)
		self.keyDataStore:SetAsync(key, key)
	end)
	Assert(success, message)
end

function DataStore:getPage(pageSize, ascending, minValue, maxValue)
	Assert(typeof(pageSize) == "number", "Invalid argument #1 (must be a 'number')")
	Assert(typeof(ascending) == "boolean", "Invalid argument #2 (must be a 'boolean')")
	local data
	local success, message = pcall(function()
		data = self.keyDataStore:GetSortedAsync(ascending, pageSize, minValue, maxValue):GetCurrentPage()
	end)
	Assert(success, message)
	return data
end

function DataStore:index(key, number)
	Assert(typeof(key) == "string", "Invalid argument #1 (must be a 'string')")
	Assert(typeof(number) == "number" and number >= 0, "Invalid argument #2 (must be a positive 'number')")
	local success, message = pcall(function()
		self.orderedDataStore:SetAsync(key, number)
	end)
	Assert(success, message)
end

return DataStore
