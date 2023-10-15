local RunService = game:GetService("RunService")

local IsServer = RunService:IsServer()

local Profile = IsServer and require(script.ServerProfile) or require(script.ClientProfile)

local ProfileAPI = Profile

if RunService:IsServer() then
	ProfileAPI.useStoreReplica = function(value)
		require(script.DataStore).useStoreReplica(value)
	end
end

ProfileAPI.None = require(script.None)

return ProfileAPI
