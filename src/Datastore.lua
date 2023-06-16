local DSS = game:GetService("DataStoreService")

local Util = script.Parent.Util
local Assert = require(Util.Assert)

local Datastore = {}

function Datastore.new(key)
	local self = setmetatable({}, { __index = Datastore })
	self.isDestroyed = false
	self.datastore = DSS:GetDataStore(key)
	return self
end

function Datastore:request(key, maxIterations)
	if self.isDestroyed then
		return
	end
	Assert(typeof(key) == 'string', "Invalid argument #1 (must be a 'string'")
	local success, message, data
	for _ = 1, maxIterations do
		success, message = pcall(function()
			self.datastore:UpdateAsync(key, function(value)
				data = value
				return value
			end)
		end)
		if success then
			break
		end
	end
	return {
		success = success,
		message = message,
		data = data
	}
end

function Datastore:save(key, value, maxIterations)
	if self.isDestroyed then
		return
	end
	Assert(typeof(key) == 'string', "Invalid argument #1 (must be a 'string'")
	local success, message
	for _ = 1, maxIterations do
		success, message = pcall(function()
			self.datastore:UpdateAsync(key, function()
				return value
			end)
		end)
		if success then
			break
		end
	end
	return {
		success = success,
		message = message
	}
end

function Datastore:delete(key, maxIterations)
	if self.isDestroyed then
		return
	end
	Assert(typeof(key) == 'string', "Invalid argument #1 (must be a 'string'")
	local success, message
	for _ = 1, maxIterations do
		success, message = pcall(function()
			self.datastore:RemoveAsync(key)
		end)
		if success then
			break
		end
	end
	return {
		success = success,
		message = message
	}
end

function Datastore:Destroy()
	self.isDestroyed = true
end

return Datastore
