local RS = game:GetService("ReplicatedStorage")

local Util = script.Parent.Util
local Error = require(Util.Error)

local Packages = RS:FindFirstChild("Packages")

if Packages then
	local Package = Packages:FindFirstChild("Replicator")
	if Package then
		return require(Package)
	end
end

Error("Couldn't find 'Replicator' in 'ReplicatedStorage.Packages'")
