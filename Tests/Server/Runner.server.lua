local RS = game:GetService('ReplicatedStorage')

local Settings = require(RS.Settings)

local ScriptsFolder = script.Parent

for scriptName, shouldRun in Settings do
    if shouldRun then
        local scriptInstance = ScriptsFolder:FindFirstChild(scriptName)
        if not script then
            error(scriptName, "doesn't exist")
        end
        require(scriptInstance)
    end
end
