local Scrtips = {
    SpeedTest = true,
    SafetyTest = true
}

for scriptName, enabled in Scrtips do
    if enabled then
        require(script.Parent[scriptName])
    end
end