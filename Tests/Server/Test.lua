local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')

local Profile = require(RS.Profile)

local SpeedLeaderboardProfile = Profile.new('SpeedLeaderboard')

print(SpeedLeaderboardProfile:getPage(10))

local plrAdded = function(player)
    local playerProfile = Profile.new(player, {
        default = {
            Speed = 16
        },
    })
    
    playerProfile.Saved:Connect(function()
        print('[Saved]: '..player.Name)
    end)
    playerProfile.Changed:Connect('Speed', function(speed, oldSpeed)
        print('[New Speed]: '..player.Name..' - New: '..speed..' - Old: '..oldSpeed)
    end)

    while task.wait(1) do
        local nextSpeed = playerProfile:get().Speed + 1
        playerProfile:set({
            Speed = nextSpeed
        })
        SpeedLeaderboardProfile:index(player.UserId, nextSpeed)
    end
end

Players.PlayerAdded:Connect(plrAdded)
for _, plr in pairs(Players:GetPlayers()) do
    plrAdded(plr)
end

return true
