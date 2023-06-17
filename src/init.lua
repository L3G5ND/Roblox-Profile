local RunService = game:GetService("RunService")

local Profile = RunService:IsServer() and require(script.ServerProfile) or require(script.ClientProfile)

local ProfileAPI = {}

if RunService:IsServer() then
	ProfileAPI.new = Profile.new
else
	ProfileAPI = Profile
end

ProfileAPI.is = Profile.is

ProfileAPI.None = require(script.None)

return ProfileAPI
