local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Profile = require(RS.Profile)

local defaultData = {
    Speed = 16,
    a = 1,
    b = 2,
    c = {
        a = 1,
        b = 2
    }
}

local plrAdded = function(player)
    local playerProfile = Profile.new(player, {
        default = defaultData,
        studioSave = true,
    })
    playerProfile.Saved:Connect(function()
        print('Saved')
    end)
    playerProfile.Deleted:Connect(function()
        print('Deleted')
    end)
    playerProfile.Changed:Connect('Speed', function(speed, oldSpeed)
        print('[New Speed]: '..player.Name..' - New: '..speed..' - Old: '..oldSpeed)
    end)
    local i = 1
    while task.wait(1) do
        playerProfile:set({
            Speed = playerProfile:get().Speed + 1
        })
        i += 1
        if i >= 100 then
            break
        end
    end
    playerProfile:Destroy()
end

Players.PlayerAdded:Connect(plrAdded)
for _, plr in pairs(Players:GetPlayers()) do
    plrAdded(plr)
end