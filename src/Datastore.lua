local DSS = game:GetService("DataStoreService")

local Util = script.Parent.Util
local Assert = require(Util.Assert)

local Datastore = {}

function Datastore.new(key)
	local self = setmetatable({}, { __index = Datastore })
	self.datastore = DSS:GetDataStore(key)
	return self
end

function Datastore:request(key, maxIterations)
	Assert(typeof(key) == 'string', "Invalid argument #1 (must be a 'string'")
	Assert(self['Get'..key] ~= nil, "Invalid argument #1 (couldn't find method '"..key.."')")
	local method = self['Get'..key]
	local success, result
	for _ = 1, maxIterations do
		success, result = method(self)
		if success then
			break
		end
	end
	return {
		success = success,
		message = not success and result or nil,
		data = success and result or nil
	}
end

function Datastore:save(key, value, maxIterations)
	Assert(typeof(key) == 'string', "Invalid argument #1 (must be a 'string'")
	Assert(self['Save'..key] ~= nil, "Invalid argument #1 (couldn't find method '"..key.."')")
	local method = self['Save'..key]
	local success, errorMsg
	for _ = 1, maxIterations do
		success, errorMsg = method(self, value)
		if success then
			break
		end
	end
	return {
		success = success,
		message = errorMsg
	}
end

function Datastore:delete(key, maxIterations)
	Assert(typeof(key) == 'string', "Invalid argument #1 (must be a 'string'")
	Assert(self['Delete'..key] ~= nil, "Invalid argument #1 (couldn't find method '"..key.."')")
	local method = self['Delete'..key]
	local success, errorMsg
	for _ = 1, maxIterations do
		success, errorMsg = method(self)
		if success then
			break
		end
	end
	return {
		success = success,
		message = errorMsg
	}
end

function Datastore:GetProfileData()
	local profileData
	local success, errorMsg = pcall(function()
		profileData = self.datastore:GetAsync("ProfileData")
	end)
	return success, success and profileData or errorMsg
end

function Datastore:SaveProfileData(value)
	return pcall(function()
		self.datastore:UpdateAsync("ProfileData", function()
			return value
		end)
	end)
end

function Datastore:DeleteProfileData()
	return pcall(function()
		self.datastore:RemoveAsync("ProfileData")
	end)
end

function Datastore:GetDataVersion()
	local dataVersion
	local success, errorMsg = pcall(function()
		dataVersion = self.datastore:GetAsync("DataVersion")
	end)
	return success, success and dataVersion or errorMsg
end

function Datastore:SaveDataVersion(value)
	return pcall(function()
		self.datastore:UpdateAsync("DataVersion", function()
			return value
		end)
	end)
end

function Datastore:DeleteDataVersion()
	return pcall(function()
		self.datastore:RemoveAsync("DataVersion")
	end)
end

function Datastore:GetVersions()
	local versions
	local success, errorMsg = pcall(function()
		versions = self.datastore:GetAsync("Versions")
	end)
	return success, success and versions or errorMsg
end

function Datastore:SaveVersions(value)
	return pcall(function()
		self.datastore:UpdateAsync("Versions", function()
			return value
		end)
	end)
end

return Datastore
