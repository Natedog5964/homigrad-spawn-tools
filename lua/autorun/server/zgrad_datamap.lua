hg = hg or {}
if WriteDataMap then return end

local mapDir = "homigrad/maps"

file.CreateDir( "homigrad" )
file.CreateDir( mapDir )

SpawnPointsPage = SpawnPointsPage or 1

SpawnPointsList = {
	regular = {"normal", Color(255, 240, 200)},

	spawnpointst = {"red", Color(255, 0, 0)},
	spawnpointsct = {"blue", Color(0, 0, 255)},

	dm = {"dm", Color(155, 155, 255)},

	bahmut_vagner = {"vagner", Color(255, 0, 0)},
	bahmut_nato = {"nato", Color(0, 0, 255)},

	spawnpointswick = {"spawnpointswick", Color(255, 0, 0)},
	spawnpointsnaem = {"spawnpointsnaem", Color(0, 0, 255)},

	spawnpoints_ss_police = {"police", Color(0, 0, 125)},
	spawnpointsseekers = {"seekers", Color(255, 0, 0)},
	spawnpointshiders = {"hiders", Color(0, 255, 0)},
	spawnpoints_ss_exit = {"exit", Color(0, 125, 0), true},

	points_nextbox = {"nextbot", Color(0, 255, 255)},

	gred_emp_dshk = {"gred_emp_dshk", Color(25, 25, 25)},
	gred_ammobox = {"gred_ammobox", Color(25, 25, 25)},
	gred_emp_2a65 = {"gred_emp_2a65", Color(25, 25, 25)},
	gred_emp_pak40 = {"gred_emp_pak40", Color(25, 25, 25)},
	gred_emp_breda35 = {"gred_emp_breda35", Color(25, 25, 25)},

	wac_hc_ah1z_viper = {"wac_hc_ah1z_viper", Color(25, 25, 25)},
	wac_hc_littlebird_ah6 = {"wac_hc_littlebird_ah6", Color(25, 25, 25)},
	wac_hc_mi28_havoc = {"wac_hc_mi28_havoc", Color(25, 25, 25)},
	wac_hc_blackhawk_uh60 = {"wac_hc_blackhawk_uh60", Color(25, 25, 25)},

	controlpoint = {"control_point", Color(25, 25, 25)},

	boxspawn = {"boxspawn", Color(25, 25, 25)},

	basedefencebots = {"basedefencebots", Color(155, 155, 155)},
	basedefencegred = {"basedefencegred", Color(255, 255, 255)},
	basedefenceplayerspawns = {"basedefenceplayerspawns", Color(255, 255, 0)},
	basedefencegred_ammo = {"basedefencegred_ammo", Color(25, 25, 25)},

	gred_simfphys_brdm2 = {"gred_simfphys_brdm2", Color(25, 25, 25)},

	car_red = {"car_red", Color(125, 125, 125)},
	car_blue = {"car_blue", Color(125, 125, 125)},

	car_red_btr = {"car_red_btr", Color(125, 125, 125)},
	car_blue_btr = {"car_blue_btr", Color(125, 125, 125)},

	car_red_tank = {"car_red_tank", Color(125, 125, 125)},
	car_blue_tank = {"car_blue_tank", Color(125, 125, 125)},

	center = {"center", Color(255, 255, 255)},

	jailbreak = {"jailbreak", Color(0, 125, 0)},
	jailbreak_doors = {"jailbreak_doors", Color(255, 0, 0)},

	darkrp_jail = {"darkrp_jail", Color(255, 255, 255)},

	scp173 = {"scp173", Color(255, 0, 0)},
	scp096 = {"scp096", Color(255, 0, 0)},
	scpWhite = {"scpWhite", Color(255, 255, 255)},

	bhop = {"bhop", Color(255, 0, 0)},

	level_construct = {"level_construct", Color(0, 0, 0)},

	sim_fphys_tank3 = {"sim_fphys_tank3", Color(165, 165, 165)},
	sim_fphys_tank4 = {"sim_fphys_tank4", Color(165, 165, 165)},
	sim_fphys_conscriptapc_armed = {"sim_fphys_conscriptapc_armed", Color(165, 165, 165)}
}

local function GetDataMapName( name, localToDataFolder )
    local dataPath = mapDir .. "/" .. name .. "/" .. game.GetMap() .. ( SpawnPointsPage == 1 and "" or SpawnPointsPage ) .. ".txt"
    dataPath = localToDataFolder and dataPath or "data/" .. dataPath

    return dataPath
end

local function ParseVector( v )
    if isvector( v ) then return v end
    if type( v ) == "string" then
        local s = v:match( "%[?([^%]]+)%]?" )
        local parts = string.Explode( " ", s )
        return Vector( tonumber( parts[1] ) or 0, tonumber( parts[2] ) or 0, tonumber( parts[3] ) or 0 )
    end
    if type( v ) == "table" then
        if v[1] ~= nil then
            return Vector( v[1] or 0, v[2] or 0, v[3] or 0 )
        end
        return Vector( v.x or 0, v.y or 0, v.z or 0 )
    end
    return Vector()
end

local function ParseAngle( a )
    if isangle( a ) then return a end
    if type( a ) == "string" then
        local s = a:match( "{?([^}]+)}?" )
        local parts = string.Explode( " ", s )
        return Angle( tonumber( parts[1] ) or 0, tonumber( parts[2] ) or 0, tonumber( parts[3] ) or 0 )
    end
    if type( a ) == "table" then
        if a[1] ~= nil then
            return Angle( a[1] or 0, a[2] or 0, a[3] or 0 )
        end
        return Angle( a.p or 0, a.y or 0, a.r or 0 )
    end
    return Angle()
end

function ReadDataMap( name )
    local raw = util.JSONToTable( file.Read( GetDataMapName( name ), "GAME" ) or "" ) or {}
    local out = {}
    for _, pt in ipairs( raw ) do
        if type( pt ) == "table" then
            out[#out + 1] = {
                ParseVector( pt[1] ),
                ParseAngle(  pt[2] ),
                pt[3]
            }
        end
    end
    return out
end

function WriteDataMap( name, data )
    file.CreateDir( mapDir .. "/" .. name )
    local serialized = {}
    for _, pt in ipairs( data or {} ) do
        if pt[4] then continue end
        local pos = isvector( pt[1] ) and pt[1] or ParseVector( pt[1] )
        local ang = isangle(  pt[2] ) and pt[2] or ParseAngle(  pt[2] )
        serialized[#serialized + 1] = {
            { pos.x, pos.y, pos.z },
            { ang.p, ang.y, ang.r },
            pt[3]
        }
    end
    file.Write( GetDataMapName( name, true ), util.TableToJSON( serialized ) or "" )
end

local function SetupSpawnPointsList()
    for name, info in pairs( SpawnPointsList ) do
        info[3] = ReadDataMap( name )
    end
end

SetupSpawnPointsList()

local function ReadMapEntities()
    for _, ent in ipairs( ents.FindByClass( "zgr_spawn_boxspawn" ) ) do
        table.insert( SpawnPointsList.boxspawn[3], { ent:GetPos(), ent:GetAngles(), false, true } )
    end

    for _, ent in ipairs( ents.FindByClass( "zgr_control_point" ) ) do
        local idx = tonumber( ent:GetKeyValues()["pointindex"] ) or 1
        table.insert( SpawnPointsList.controlpoint[3], { ent:GetPos(), ent:GetAngles(), idx, true } )
    end

    for _, class in ipairs({ "info_player_terrorist", "info_player_rebel", "zgr_spawn_red" }) do
        for _, ent in ipairs( ents.FindByClass( class ) ) do
            table.insert( SpawnPointsList.spawnpointst[3], { ent:GetPos(), ent:GetAngles(), false, true } )
        end
    end

    for _, class in ipairs({ "info_player_counterterrorist", "info_player_combine", "zgr_spawn_blue" }) do
        for _, ent in ipairs( ents.FindByClass( class ) ) do
            table.insert( SpawnPointsList.spawnpointsct[3], { ent:GetPos(), ent:GetAngles(), false, true } )
        end
    end

--[[    for _, class in ipairs({ "info_player_start", "info_player_deathmatch", "zgr_spawn_deathmatch" }) do
        for _, ent in ipairs( ents.FindByClass( class ) ) do
            table.insert( SpawnPointsList.spawnpointhmcd[3], { ent:GetPos(), ent:GetAngles(), false, true } )
        end 
    end --]] -- Removed this cause it causes errors and i don't know what it does lol
end

hook.Add( "InitPostEntity", "hg_ReadMapSpawnEntities_InitPostEntity", function()
    ReadMapEntities()
end )

hook.Add( "PostCleanupMap", "hg_ReadMapSpawnEntities_PostCleanupMap", function()
    SetupSpawnPointsList()
    ReadMapEntities()
end )

util.AddNetworkString( "hg_spawn_points" )

function SendSpawnPoint( ply )
    net.Start( "hg_spawn_points" )
    net.WriteTable( SpawnPointsList )
    if ply then net.Send( ply ) else net.Broadcast() end
end

function AddSpawnPoint( caller, pointType, pointNumber )
    local tbl = ReadDataMap( pointType )
    local point = { caller:GetPos() + Vector( 0, 0, 5 ), Angle( 0, caller:EyeAngles()[2], 0 ), tonumber( pointNumber ) }
    table.insert( tbl, point )
    WriteDataMap( pointType, tbl )

    SetupSpawnPointsList()
    ReadMapEntities()
    SendSpawnPoint()
end

function ResetSpawnPoints( pointType )
    WriteDataMap( pointType )

    SetupSpawnPointsList()
    ReadMapEntities()
    SendSpawnPoint()
end

hook.Add( "PlayerInitialSpawn", "hg_SendSpawnPoints", function( ply )
    SendSpawnPoint( ply )
end )
