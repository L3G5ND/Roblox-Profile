local RS = game:GetService('ReplicatedStorage')

local Profile = require(RS.Profile)

local plr = game.Players.LocalPlayer

local walkspeedUI = Instance.new('ScreenGui', plr.PlayerGui)
walkspeedUI.ResetOnSpawn = false

local walkspeedLabel = Instance.new('TextLabel', walkspeedUI)
walkspeedLabel.Position = UDim2.new(.5, 0, 0, 0)
walkspeedLabel.AnchorPoint = Vector2.new(.5, 0)
walkspeedLabel.Size = UDim2.new(0, 200, 0, 50)

local updateSpeed = function(speed)
    local char = plr.Character
    if char then
        local humanoid = char:FindFirstChild('Humanoid')
        if humanoid then
            humanoid.WalkSpeed = speed
        end
    end
    walkspeedLabel.Text = speed
end

updateSpeed(Profile:get().Speed)
Profile.Changed:Connect('Speed', updateSpeed)

return true
