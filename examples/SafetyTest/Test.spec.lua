local RS = game:GetService('ReplicatedStorage')
local Http = game:GetService('HttpService')

local Profile = require(RS.Profile)
local DataStore = require(RS.Profile.DataStore).NormalDataStore

local function getProfile()
    return Profile.new('SafetyTest', {
        default = {
            Value = 1
        },
        useSessionLock = true
    })
end

return function()
    local SafetyTest = getProfile()
    SafetyTest:set({
        Value = 1
    })
    expect(SafetyTest:get().Value).to.equal(1)

    SafetyTest = getProfile()
    SafetyTest:set({
        Value = 2
    })
    expect(SafetyTest:get().Value).to.equal(2)

    SafetyTest:set({
        Value = 3
    })
    task.spawn(function()
        expect(SafetyTest:get().Value).to.equal(3)
        SafetyTest:Destroy()
    end)
    task.wait()
    SafetyTest = getProfile()
    expect(SafetyTest:get().Value).to.equal(3)
    SafetyTest:Destroy()

    SafetyTest = getProfile()
    task.spawn(function()
        SafetyTest:set({
            Value = 4
        })
        expect(SafetyTest:get().Value).to.equal(4)
        SafetyTest:Destroy()
    end)
    task.wait()
    Profile.Profiles['SafetyTest'] = nil
    DataStore.SessionId = Http:GenerateGUID()
    SafetyTest = getProfile()
    expect(SafetyTest:get().Value).to.equal(4)
    SafetyTest:Destroy()

    Profile.useStoreReplica(true)
    SafetyTest = getProfile()
    SafetyTest:set({
        Value = 1
    })
    expect(SafetyTest:get().Value).to.equal(1)
    SafetyTest:set({
        Value = 2
    })
    expect(SafetyTest:get().Value).to.equal(2)
    SafetyTest:Destroy()
    SafetyTest = getProfile()
    expect(SafetyTest:get().Value).to.equal(2)
    SafetyTest:Destroy()
end
