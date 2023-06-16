local RunService = game:GetService("RunService")

local Profile = RunService:IsServer() and require(script.ServerProfile) or require(script.ClientProfile)

local ProfileAPI = {}

ProfileAPI.new = Profile.new

ProfileAPI.is = Profile.is

ProfileAPI.None = require(script.None)

return ProfileAPI
