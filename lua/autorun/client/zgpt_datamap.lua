if net.Receivers and net.Receivers["points"] then return end

SpawnPointsList = SpawnPointsList or {}

net.Receive( "points", function()
    SpawnPointsList = net.ReadTable()
    hook.Run( "ZGrad_SpawnPointsUpdated" )
end )
