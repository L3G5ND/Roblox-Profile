local RS = game:GetService('ReplicatedStorage')
local Profile = require(RS.Profile)

local plr = game.Players.LocalPlayer
local char = plr.Character or plr.CharacterAdded:Wait()
local humanoid = char:WaitForChild('Humanoid')
plr.CharacterAdded:Connect(function(character)
    char = character
    humanoid = char:WaitForChild('Humanoid')
end)

local plrGui = plr.PlayerGui
local walkspeedUI = Instance.new('ScreenGui', plrGui)
walkspeedUI.ResetOnSpawn = false
walkspeedLabel = Instance.new('TextLabel', walkspeedUI)
walkspeedLabel.Position = UDim2.new(.5, 0, 0, 0)
walkspeedLabel.AnchorPoint = Vector2.new(.5, 0)
walkspeedLabel.Size = UDim2.new(0, 200, 0, 50)

local updateSpeed = function(speed)
    humanoid.WalkSpeed = speed
    walkspeedLabel.Text = speed
end

updateSpeed(Profile:get().Speed)
Profile:onChanged('Speed', updateSpeed)