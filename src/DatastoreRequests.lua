local DSS = game:GetService('DataStoreService')

local DatastoreRequests = {}

function DatastoreRequests.new(key)
    local self = setmetatable({}, {__index = DatastoreRequests})
    self.datastore = DSS:GetDataStore(key)
    return self
end


function DatastoreRequests:requestIterator(key, maxIterations)
    local success
    local data
    for i = 1, maxIterations do
        local _success, _data = self[key](self)
        if _success then
            success = true
            data = _data
            break
        end
    end
    return success, data
end

function DatastoreRequests:saveIterator(key, value, maxIterations)
    local success
    local data
    for i = 1, maxIterations do
        local _success, _data = self[key](self, value)
        if _success then
            success = true
            data = data
            break
        end
    end
    return success, data
end


function DatastoreRequests:requestProfile()
    local profileData
    local success, errorMsg = pcall(function()
        profileData = self.datastore:GetAsync('Profile')
    end)
    return success, success and profileData or errorMsg
end

function DatastoreRequests:requestSave(value)
    local success, errorMsg = pcall(function()
        self.datastore:UpdateAsync('Profile', function()
			return value
		end)
    end)
    return success, errorMsg
end

function DatastoreRequests:requestVersions()
    local versions
    local success, errorMsg = pcall(function()
        versions = self.datastore:GetAsync('Versions')
    end)
    return success, success and versions or errorMsg
end

function DatastoreRequests:requestSaveVersion(value)
    local success, errorMsg = pcall(function()
        self.datastore:UpdateAsync('Versions', function()
			return value
		end)
    end)
    return success, errorMsg
end


function DatastoreRequests:requestDataVersion()
    local dataVersion
    local success, errorMsg = pcall(function()
        dataVersion = self.datastore:GetAsync('DataVersion')
    end)
    return success, success and dataVersion or errorMsg
end

function DatastoreRequests:requestSaveDataVersion(value)
    local success, errorMsg = pcall(function()
        self.datastore:UpdateAsync('DataVersion', function()
			return value
		end)
    end)
    return success, errorMsg
end


function DatastoreRequests:requestDeleteProfileData()
    local success, errorMsg = pcall(function()
        self.datastore:RemoveAsync('Profile')
    end)
    return success, errorMsg
end

function DatastoreRequests:requestDeleteDataVersion()
    local success, errorMsg = pcall(function()
        self.datastore:RemoveAsync('DataVersion')
    end)
    return success, errorMsg
end

return DatastoreRequests