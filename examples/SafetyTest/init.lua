local RS = game:GetService("ReplicatedStorage")

local TestEZ = require(RS.Packages.TestEZ)

local results = TestEZ.TestBootstrap:run({ script["Test.spec"] })

local ranSuccessfully = (results.failureCount == 0 and #results.errors == 0) and true or false

if ranSuccessfully then
	print("SafetyTest ran successfully")
else
	print("SafetyTest ran unsucessfully")
end

return true
