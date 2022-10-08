local RunService = game:GetService('RunService')

local None = require(script.None)
local Profile

if RunService:IsServer() then
    Profile = require(script.Profile)
else
    Profile = require(script.ClientProfile)
end

Profile.None = None

return Profile