local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')
local Profile = require(RS.Profile)

local defaultData = {
    Speed = 16,
    Test = {
        test = true,
        value = 'hello'
    }
}

local plrAdded = function(player)
    local playerProfile = Profile.getProfile(player, {
        default = defaultData,
        studioSave = true,
        private = {
            Test = true,
        },
    })
    playerProfile:onChanged('Speed', function(speed, oldSpeed)
        print('[New Speed]: '..player.Name..' - '..speed)
    end)
    while task.wait(1) do
        playerProfile:set({
            Speed = playerProfile:get().Speed + 1
        })
    end
end

Players.PlayerAdded:Connect(plrAdded)
for _, plr in pairs(Players:GetPlayers()) do
    plrAdded(plr)
end