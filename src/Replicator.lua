local RS = game:GetService('ReplicatedStorage')
local Replicator = script.Parent.Parent:FindFirstChild('Replicator')
if not Replicator then
    return require(RS.Packages.Replicator)
else
    return require(Replicator)
end