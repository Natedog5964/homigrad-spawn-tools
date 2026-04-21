hg = hg or {}
if net.Receivers and net.Receivers["hg_spawn_points"] then return end

SpawnPointsList = SpawnPointsList or {}

net.Receive( "hg_spawn_points", function()
    ZGRAD.SpawnPointsList = net.ReadTable()
    hook.Run( "hg_SpawnPointsUpdated" )
end )
