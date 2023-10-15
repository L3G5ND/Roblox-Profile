local Scrtips = {
    SpeedTest = true,
    SafetyTest = false
}

for scriptName, enabled in Scrtips do
    if enabled then
        require(script.Parent[scriptName])
    end
end