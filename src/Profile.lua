local Players = game:GetService('Players')
local RunService = game:GetService('RunService')

local Package = script.Parent

local Util = Package.Util
local Assert = require(Util.Assert)
local Assign = require(Util.Assign)
local Error = require(Util.Error)
local DeepEqual = require(Util.DeepEqual)
local Copy = require(Util.Copy)

local Replicator = require(Package.Replicator)
local DefaultSettings = require(Package.DefaultSettings)
local None = require(Package.None)
local Signal = require(Package.Signal)
local DatastoreRequests = require(Package.DatastoreRequests)
local ProfileUtil = require(Package.ProfileUtil)

local IsStudio = RunService:IsStudio()

local Profile = {}
local ProfileCache = {}

function Profile.getProfile(plrOrKey, timeout)
    Assert(not timeout or typeof(timeout) == 'number', 'Invalid argument #2 (type \'number\' expected)')
    local key = ProfileUtil.getKey(plrOrKey)
    if not ProfileCache[key] then
        local startTime = os.time()
        while true do
            if ProfileCache[key] then
                break
            end
            if os.time() - startTime >= (timeout or 10) then
                Error('Profile '..key..' doesnt exist')
            end
            RunService.Heartbeat:Wait()
        end
    end
    return ProfileCache[key]
end

function Profile.createProfile(plrOrKey, settings)
    Assert(typeof(plrOrKey) == 'Instance' and plrOrKey.ClassName == 'Player' or typeof(plrOrKey) == 'string', 'Invalid argument #1 (must be a \'Player\' object or type \'string\')')

    local key = ProfileUtil.getKey(plrOrKey)
    local loadedKey = ProfileUtil.getLoadedKey(key)
    
    local self = setmetatable({}, {__index = Profile})

    self:_rawSetSettings(settings)

    self.key = key
    self.isPlayerProfile = typeof(plrOrKey) == 'Instance' and plrOrKey.ClassName == 'Player'
    if self.isPlayerProfile then
        local plr = plrOrKey

        self.player = plr
        self.profileDataReplicator = Replicator.new({
            key = self.key,
            data = {},
            replicators = {plr}
        })
        self.isLoadedReplicator = Replicator.new({
            key = loadedKey,
            data = false,
            replicators = {plr}
        })
    else   
        self.profileDataReplicator = Replicator.new({
            key = key,
            data = {},
            replicators = {}
        })
        self.isLoadedReplicator = Replicator.new({
            key = loadedKey,
            data = false,
            replicators = {}
        })
    end

    self.cache = {}

    self.log = ''
    self.newLogSignal = Signal.new()
    
    self.beforeCloseSignal = Signal.new()
    self.onCloseSignal = Signal.new()

    self.isClosing = false
    self.isLoaded = false

    self.shouldSaveProfileData = false
    self.shouldSaveDataVersion = false
    self.shouldSaveProfile = true

    self.profileDataChangedSignal = Signal.new()
    self.profileDataChangedSignal:Connect(function()
        self.profileDataReplicator:set(self:_getPublicProfileData())
    end)

    self.datastore = DatastoreRequests.new(self.key)

    self.dataVersion = self:_rawGetCurrentDataVersion()
    self.cache[#self.cache+1] = self:_initialGet()
    self.versions = self:_rawGetVersions()

    if self:_rawGet() == self.settings.default then
        self.shouldSaveProfileData = true
    end

    ProfileCache[self.key] = self

    self:_log('['..self.key..']'..' - Successfully loaded', 3)

    self.isLoaded = true

    self.profileDataReplicator:set(self:_getPublicProfileData())
    self.isLoadedReplicator:set(true)

    return self
end

function Profile:_getPublicProfileData()
    local profileData = Copy(self:_rawGet())
    
    if typeof(profileData) == 'table' then
        profileData = ProfileUtil.fixNoneForReplicatorNone(profileData)
    elseif profileData == None then
        profileData = Replicator.None
    end

    if self.settings.private == true then
        profileData = nil
    elseif typeof(self.settings.private) == 'table' then
        profileData = ProfileUtil.removePrivateMembers(profileData, self.settings.private)
    end

    return profileData
end

function Profile:_rawSetSettings(settings)
    Assert(not settings.maxGetRequests or typeof(settings.maxGetRequests) == 'number', 'Invalid argument #1 (settings.maxGetRequests must be type \'number\')')
    Assert(not settings.maxSaveRequests or typeof(settings.maxSaveRequests) == 'number', 'Invalid argument #1 (settings.maxSaveRequests must be type \'number\')')
    Assert(not settings.maxDeleteRequests or typeof(settings.maxDeleteRequests) == 'number', 'Invalid argument #1 (settings.maxDeleteRequests must be type \'number\')')
    Assert(not settings.maxVersionRequests or typeof(settings.maxVersionRequests) == 'number', 'Invalid argument #1 (settings.maxVersionRequests must be type \'number\')')
    Assert(not settings.maxSaveVersionRequests or typeof(settings.maxSaveVersionRequests) == 'number', 'Invalid argument #1 (settings.maxSaveVersionRequests must be type \'number\')')
    Assert(not settings.maxDataVersionRequests or typeof(settings.maxDataVersionRequests) == 'number', 'Invalid argument #1 (settings.maxDataVersionRequests must be type \'number\')')
    Assert(not settings.maxSaveDataVersionRequests or typeof(settings.maxSaveDataVersionRequests) == 'number', 'Invalid argument #1 (settings.maxSaveDataVersionRequests must be type \'number\')')
    Assert(not settings.studioSave or typeof(settings.studioSave) == 'boolean', 'Invalid argument #1 (settings.studioSave must be type \'boolean\')')
    Assert(not settings.default or (typeof(settings.default) == 'nil' or typeof(settings.default) == 'table'), 'Invalid argument #1 (settings.default must be type \'nil\' or \'table\')')
    Assert(not settings.private or (typeof(settings.private) == 'boolean' or typeof(settings.private) == 'table'), 'Invalid argument #1 (settings.private must be type \'boolean\' or \'table\')')
    Assert(not settings.mergedData or (typeof(settings.mergedData) == 'nil' or typeof(settings.mergedData) == 'table'), 'Invalid argument #1 (settings.mergedData must be type \'nil\' or \'table\')')

    local newSettings = {
        maxGetRequests = settings.maxGetRequests or DefaultSettings.maxGetRequests,
        maxSaveRequests = settings.maxSaveRequests or DefaultSettings.maxSaveRequests,
        maxDeleteRequests = settings.maxDeleteRequests or DefaultSettings.maxDeleteRequests,
        maxVersionRequests = settings.maxVersionRequests or DefaultSettings.maxVersionRequests,
        maxSaveVersionRequests = settings.maxSaveVersionRequests or DefaultSettings.maxSaveVersionRequests,
        maxDataVersionRequests = settings.maxDataVersionRequests or DefaultSettings.maxDataVersionRequests,
        maxSaveDataVersionRequests = settings.maxSaveDataVersionRequests or DefaultSettings.maxSaveDataVersionRequests,
        studioSave = settings.studioSave or DefaultSettings.studioSave,
        default = settings.default,
        private = settings.private,
        mergedData = settings.mergedData or settings.default
    }

    Assert(not settings.migrators or typeof(settings.migrators) == 'table', 'Invalid argument #1 (settings.migrators must be type \'table\' and have a minimum of 1 migrator)')
    if settings.migrators and #settings.migrators > 0 then
        newSettings.migrators = settings.migrators
    end

    if settings.serializer then
        Assert(typeof(settings.serializer) == 'function', 'Invalid argument #1 (settings.serializer must be type \'function\')')
        newSettings.serializer = settings.serializer
    end
    if settings.deserializer then
        Assert(typeof(settings.deserializer) == 'function', 'Invalid argument #1 (settings.deserializer must be type \'function\')')
        newSettings.deserializer = settings.deserializer
    end

    self.settings = newSettings
end

function Profile:setSettings(settings)
    self:_rawSetSettings(settings)
    self:_log('['..self.key..']'..' - profile:setSettings(settings)', 2)
end

function Profile:_migrate(profileData)
    local dataVersion = self:_rawGetDataVersion()
    if self.dataVersion ~= dataVersion then
        for i = self.dataVersion, #self.settings.migrators do
            local migrator = self.settings.migrators[i]
            local newProfileData = migrator(profileData)
            Assert(newProfileData, 'Migrator function must return a value')
            profileData = newProfileData
        end
        self.shouldSaveDataVersion = true
        self.dataVersion = dataVersion
        return profileData
    end
end

function Profile:_initialGet()
    local success, data = self.datastore:requestIterator('requestProfile', self.settings.maxGetRequests)
    Assert(success, 'An error occured when getting profile ['..self.key..'] -', data)
    if not data then
        data = self.settings.default
    else
        if self.settings.deserializer then
            data = self.deserializer(data)
        end
        local migrateData = self:_migrate(data)
        data = migrateData and migrateData or data
        if self.settings.mergedData then
            self:_rawMerge(data, self.settings.mergedData)
        end
    end
    return data
end

function Profile:_rawGet()
    if #self.cache > 0 then
        return self.cache[#self.cache]
    end
    return self:_initialGet()
end

function Profile:get()
    local profileData = self:_rawGet()
    self:_log('['..self.key..']'..' - profile:get()', 1)
    return profileData
end

function Profile:_rawGetVersions()
    if self.versions then
        return self.versions
    end
    local success, data = self.datastore:requestIterator('requestVersions', self.settings.maxVersionRequests)
    Assert(success, 'An error occured when getting versions of profile ['..self.key..'] -', data)
    if not data then
        data = {}
    end
    return data
end

function Profile:getVersions()
    local version = self:_rawGetVersions()
    self:_log('['..self.key..']'..' - profile:getVersions()', 1)
    return version
end

function Profile:_rawGetCurrentDataVersion()
    if self.dataVersion then
        return self.dataVersion
    end
    local success, data = self.datastore:requestIterator('requestDataVersion', self.settings.maxDataVersionRequests)
    Assert(success, 'An error occured when getting DataVersion on profile ['..self.key..'] -', data)
    if not data then
        return self.settings.migrators and #self.settings.migrators + 1 or 1
    end
    return data
end

function Profile:getCurrentDataVersion()
    local currentVersion = self:_rawGetCurrentDataVersion()
    self:_log('['..self.key..']'..' - profile:getCurrentDataVersion()', 1)
    return currentVersion
end

function Profile:_rawGetDataVersion()
    if self.settings.migrators then
        return #self.settings.migrators + 1
    else
        return self.dataVersion
    end
end

function Profile:getDataVersion()
    local dataVersion = self:_rawGetDataVersion()
    self:_log('['..self.key..']'..' - profile:getDataVersion()', 1)
    return dataVersion
end

function Profile:_rawMerge(tbl, mergeTbl)
    for key, value in pairs(mergeTbl) do
        if not tbl[key] then
            if not self.shouldSaveProfileData then
                self.shouldSaveProfileData = true
            end
            tbl[key] = value
        elseif typeof(value) == 'table' then
            self:_rawMerge(tbl[key], value)
        end
    end
end

function Profile:merge(tbl)
    self:_rawMerge(self:_rawGet(), tbl)
    self.profileDataChangedSignal:Fire()
    self:_log('['..self.key..']'..' - profile:merge(tbl)', 3)
end

function Profile:_rawSet(profileData, exact)
    if #self.cache <= 0 then
        self.cache[#self.cache+1] = self:_initialGet()
    end
    local oldProfileData = self.cache[#self.cache]
    local newProfileData
    if exact then
        newProfileData = profileData
    elseif typeof(profileData) == 'table' and typeof(oldProfileData) == 'table' then
        newProfileData = Assign({}, oldProfileData, profileData)
    else
        newProfileData = profileData
    end
    if not DeepEqual(oldProfileData, newProfileData) then
        self.shouldSaveProfileData = true
        self.cache[#self.cache+1] = newProfileData
        self.profileDataChangedSignal:Fire()
    end
end

function Profile:set(profileData, exact)
    self:_rawSet(profileData, exact)
    self:_log('['..self.key..']'..' - profile:set(profileData, '..tostring(exact) or 'false'..')', 3)
end

function Profile:save()
    if self.shouldSaveProfileData then
        if IsStudio and not self.settings.studioSave then
            return {successful = false, message = 'Cannot save inside of studio'}
        end

        local value = self:_rawGet()

        if value == None then
            return self:delete()
        end
        if self.settings.serializer then
            value = self.serializer(value)
        end

        local success, data = self.datastore:saveIterator('requestSave', value, self.settings.maxSaveRequests)

        if success then
            self:_saveDataVersion()
            self:_saveVersion(value)
            self.shouldSaveProfileData = false
            self:_log('['..self.key..']'..' - Successfully saved profile', 3)
            return {successful = true, message = 'Successfully saved profile'}
        else
            self:_log('['..self.key..']'..' - There was an error when saving profile', 3)
            return {successful = true, message = 'There was an error when saving profile -', data}
        end
    else
        self:_log('['..self.key..']'..' - Profile data did not change', 3)
        return {successful = false, message = 'Profile data did not change'}
    end
end

function Profile:_saveVersion(profileData)
    if self.shouldSaveProfileData then
        if IsStudio and not self.settings.studioSave then
            return {successful = false, message = 'Cannot save inside of studio'}
        end

        local value = self.versions
        value[#value+1] = profileData or {}

        local success, data = self.datastore:saveIterator('requestSaveVersion', value, self.settings.maxSaveVersionRequests)

        if success then
            self:_log('['..self.key..']'..' - Successfully saved version', 2)
            return {successful = true, message = 'Successfully saved version'}
        else
            self:_log('['..self.key..']'..' - There was an error when saving version', 2)
            return {successful = true, message = 'There was an error when saving version -', data}
        end
    else
        self:_log('['..self.key..']'..' - Profile data did not change so not version was added', 2)
        return {successful = false, message = 'Profile data did not change'}
    end
end

function Profile:_saveDataVersion()
    if self.shouldSaveProfileData then
        if IsStudio and not self.settings.studioSave then
            return {successful = false, message = 'Cannot save inside of studio'}
        end

        local dataVersion = self.dataVersion

        local success, data = self.datastore:saveIterator('requestSaveDataVersion', dataVersion, self.settings.maxSaveDataVersionRequests)

        if success then
            self:_log('['..self.key..']'..' - Successfully saved DataVersion', 2)
            return {successful = true, message = 'Successfully saved DataVersion'}
        else
            self:_log('['..self.key..']'..' - There was an error when saving DataVersion', 2)
            return {successful = true, message = 'There was an error when saving DataVersion -', data}
        end
    else
        self:_log('['..self.key..']'..' - DataVersion did not change', 2)
        return {successful = false, message = 'DataVersion did not change'}
    end
end

function Profile:delete()
    local success, data = self.datastore:requestIterator('requestDeleteProfileData', self.settings.maxDeleteRequests)

    if success then
        self.cache = {}

        self.shouldSaveProfileData = true
        self:_saveVersion()

        self.profileDataChangedSignal:Fire()

        local success, data = self.datastore:requestIterator('requestDeleteDataVersion', self.settings.maxDeleteRequests)
        if success then
            self:_log('['..self.key..']'..' - Successfully deleted profile', 3)
            return {successful = true, message = 'Successfully deleted profile'}
        else
            self:_log('['..self.key..']'..' - There was an error when deleting profile', 3)
            return {successful = false, message = 'There was an error when deleting profile -', data}
        end   
    else
        self:_log('['..self.key..']'..' - There was an error when deleting profile', 3)
        return {successful = false, message = 'There was an error when deleting profile -', data}
    end
end

function Profile:setVisibility(plrTbl)
    self.profileDataReplicator:setReplicators(plrTbl)
    self.isLoadedReplicator:setReplicators(plrTbl)
    self:_log('['..self.key..']'..' - profile:setVisibility('..(typeof(plrTbl) == 'table' and 'plrTbl' or plrTbl)..')', 1)
end

function Profile:shouldSave(should)
    Assert(typeof(should) == 'boolean', 'Invalid argument #1 (must be type \'boolean\')')
    self.shouldSaveProfile = should
    self:_log('['..self.key..']'..' - profile:shouldSave('..(should and 'true' or 'false')..')', 1)
end

function Profile:onChanged(...)
    self.profileDataReplicator:onChanged(...)
end

function Profile:beforeClose(callback)
    Assert(typeof(callback) == 'function', 'Invalid argument #1 (must be type \'function\')')
    self.beforeCloseSignal:Connect(callback)
end

function Profile:onClose(callback)
    Assert(typeof(callback) == 'function', 'Invalid argument #1 (must be type \'function\')')
    self.onCloseSignal:Connect(callback)
end

function Profile:onNewLog(callback)
    self.newLogSignal:Connect(callback)
end

function Profile:didChange()
    return self.shouldSaveProfileData
end

function Profile:getLog()
    return self.log
end

function Profile:_log(message, level)
    self.log = self.log..'\n'..message
    self.newLogSignal:Fire(message, level or 1)
end

function Profile:_close()
    if self.isClosing then
        return
    end
    self.isClosing = true
    
    self.beforeCloseSignal:Fire()
    if self.shouldSaveProfile then
        self:save()
    end
    self.onCloseSignal:Fire()
    ProfileCache[self.key] = nil
end

game:BindToClose(function()
    for _, profile in pairs(ProfileCache) do
        profile:_close()
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    local key = ProfileUtil.getKey(plr)
    local profile = ProfileCache[key]
    if profile then
        profile:_close()
    end
end)

return setmetatable(Profile, {__call = function(tbl, plr)
    return Profile.getProfile(plr)
end})