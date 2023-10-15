local Players = game:GetService('Players')
local RS = game:GetService('ReplicatedStorage')

local Profile = require(RS.Profile)

local ClientScript = script.Client

local SpeedLeaderboardProfile = Profile.ordered('SpeedLeaderboard')
print("[Speed Leaderboard]", SpeedLeaderboardProfile:getPage(10))

local TestProfile = Profile.new('TestProfile', {
    default = {
        value = 1
    },
})
TestProfile:set({
    value = TestProfile:get().value + 1
})

local plrAdded = function(player)
    ClientScript:Clone().Parent = player:WaitForChild("PlayerGui")

    local playerProfile = Profile.new(player, {
        default = {
            Speed = 16
        },
    })
    if not playerProfile then
        return
    end
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
