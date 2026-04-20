ZGRAD = ZGRAD or {}

ZGRAD.PointRadii = {
    control_point = 256,
    boxspawn      = 48,
}

ZGRAD.DefaultPointRadius = 24

ZGRAD.PointIntersectRadii = {
    control_point = 32,
    boxspawn      = 48,
}

function ZGRAD.GetPointRadius( typeName )
    return ZGRAD.PointRadii[typeName] or ZGRAD.DefaultPointRadius
end

function ZGRAD.GetPointIntersectRadius( typeName )
    return ZGRAD.PointIntersectRadii[typeName] or ZGRAD.DefaultPointRadius
end

function ZGRAD.PointsIntersect( posA, typeA, posB, typeB )
    local rA = ZGRAD.GetPointIntersectRadius( typeA )
    local rB = ZGRAD.GetPointIntersectRadius( typeB )
    local minSep = rA + rB
    return posA:DistToSqr( posB ) < ( minSep * minSep )
end

local PLAYER_HULL_MINS = Vector( -16, -16, 0 )
local PLAYER_HULL_MAXS = Vector(  16,  16, 72 )

local GROUND_TRACE_UP   = 16
local GROUND_TRACE_DOWN = 2048
local GROUND_OFFSET     = 5
local GROUND_HULL_MINS  = Vector( -4, -4, 0 )
local GROUND_HULL_MAXS  = Vector(  4,  4, 1 )

function ZGRAD.IsPointInWall( pos )
    if util.IsInWorld and not util.IsInWorld( pos ) then return true end

    local tr = util.TraceHull( {
        start  = pos,
        endpos = pos,
        mins   = PLAYER_HULL_MINS,
        maxs   = PLAYER_HULL_MAXS,
        mask   = MASK_PLAYERSOLID_BRUSHONLY,
    } )

    return tr.StartSolid or tr.AllSolid
end

function ZGRAD.FindNearbyPoint( pos, minDist, ignoreDataKey, ignoreIndex )
    local list = ZGRAD.SpawnPointsList
    if not list then return nil end

    local minSq = minDist * minDist
    for dataKey, info in pairs( list ) do
        local pts = info[3]
        if not pts then continue end

        for i = 1, #pts do
            if dataKey == ignoreDataKey and i == ignoreIndex then continue end

            local other = ZGRAD.ReadPoint( pts[i] )
            if other and pos:DistToSqr( other[1] ) < minSq then
                return { dataKey = dataKey, typeName = info[1], index = i, pos = other[1] }
            end
        end
    end

    return nil
end

function ZGRAD.FindIntersectingPoint( pos, typeName, ignoreDataKey, ignoreIndex )
    local list = ZGRAD.SpawnPointsList
    if not list then return nil end

    for dataKey, info in pairs( list ) do
        local otherType = info[1]
        local pts       = info[3]
        if not pts then continue end

        for i = 1, #pts do
            if dataKey == ignoreDataKey and i == ignoreIndex then continue end

            local other = ZGRAD.ReadPoint( pts[i] )
            if not other then continue end

            if ZGRAD.PointsIntersect( pos, typeName, other[1], otherType ) then
                return { dataKey = dataKey, typeName = otherType, index = i, pos = other[1] }
            end
        end
    end

    return nil
end

local WALL_STEP      = 8
local WALL_MAX_UP    = 256
local WALL_MAX_OUT   = 384
local WALL_ANGLES    = 16
local RESOLVE_ITERS  = 24
local MAX_DRIFT      = 512
local MAX_DRIFT_SQ   = MAX_DRIFT * MAX_DRIFT

local WALL_DIRS = {}
for i = 0, WALL_ANGLES - 1 do
    local a = ( i / WALL_ANGLES ) * math.pi * 2
    WALL_DIRS[i + 1] = { math.cos( a ), math.sin( a ) }
end

local function FindWallClearance( pos )
    if not ZGRAD.IsPointInWall( pos ) then return pos end

    for r = WALL_STEP, WALL_MAX_OUT, WALL_STEP do
        for _, d in ipairs( WALL_DIRS ) do
            local test = Vector( pos.x + d[1] * r, pos.y + d[2] * r, pos.z )
            if not ZGRAD.IsPointInWall( test ) then
                return test
            end
        end

        if r <= WALL_MAX_UP then
            local up = Vector( pos.x, pos.y, pos.z + r )
            if not ZGRAD.IsPointInWall( up ) then return up end
        end
    end

    return nil
end

function ZGRAD.SnapToGround( pos )
    local basePos = FindWallClearance( pos )
    if not basePos then return nil end

    local tr = util.TraceHull( {
        start  = basePos + Vector( 0, 0, GROUND_TRACE_UP ),
        endpos = basePos + Vector( 0, 0, -GROUND_TRACE_DOWN ),
        mins   = GROUND_HULL_MINS,
        maxs   = GROUND_HULL_MAXS,
        mask   = MASK_SOLID_BRUSHONLY,
    } )

    if tr.StartSolid or not tr.Hit then return nil end
    return tr.HitPos + Vector( 0, 0, GROUND_OFFSET )
end

local MAX_GRID_POINTS   = 1024
local RANDOM_ATTEMPTS_X = 30

function ZGRAD.GetAreaGridPositions( center, yaw, length, width, spacing )
    local positions = {}
    spacing = math.max( 4, spacing )

    local ang = Angle( 0, yaw, 0 )
    local fwd = ang:Forward()
    local rgt = ang:Right()

    local numL = math.max( 1, math.floor( length / spacing ) + 1 )
    local numW = math.max( 1, math.floor( width  / spacing ) + 1 )
    if numL * numW > MAX_GRID_POINTS then
        local scale = math.sqrt( ( numL * numW ) / MAX_GRID_POINTS )
        numL = math.max( 1, math.floor( numL / scale ) )
        numW = math.max( 1, math.floor( numW / scale ) )
    end

    local startL = -( numL - 1 ) * spacing * 0.5
    local startW = -( numW - 1 ) * spacing * 0.5

    for i = 0, numL - 1 do
        for j = 0, numW - 1 do
            local l = startL + i * spacing
            local w = startW + j * spacing
            positions[#positions + 1] = center + fwd * l + rgt * w
        end
    end

    return positions
end

function ZGRAD.GetAreaRandomCandidates( center, yaw, length, width, count )
    local positions = {}
    local ang = Angle( 0, yaw, 0 )
    local fwd = ang:Forward()
    local rgt = ang:Right()

    local attempts = count * RANDOM_ATTEMPTS_X
    for _ = 1, attempts do
        local l = ( math.random() - 0.5 ) * length
        local w = ( math.random() - 0.5 ) * width
        positions[#positions + 1] = center + fwd * l + rgt * w
    end

    return positions
end

function ZGRAD.ResolvePlacement( pos, typeName, ignoreDataKey, ignoreIndex )
    local current = Vector( pos )

    for _ = 1, RESOLVE_ITERS do
        if current:DistToSqr( pos ) > MAX_DRIFT_SQ then return nil end

        if ZGRAD.IsPointInWall( current ) then
            local cleared = FindWallClearance( current )
            if not cleared then return nil end
            current = cleared
        else
            local hit = ZGRAD.FindIntersectingPoint( current, typeName, ignoreDataKey, ignoreIndex )
            if not hit then return current end

            local dx = current.x - hit.pos.x
            local dy = current.y - hit.pos.y
            local lenSq = dx * dx + dy * dy
            if lenSq < 0.01 then
                dx, dy = 1, 0
            else
                local invLen = 1 / math.sqrt( lenSq )
                dx = dx * invLen
                dy = dy * invLen
            end

            local rA = ZGRAD.GetPointIntersectRadius( typeName )
            local rB = ZGRAD.GetPointIntersectRadius( hit.typeName )
            local needed = rA + rB + 0.5

            current = Vector( hit.pos.x + dx * needed, hit.pos.y + dy * needed, current.z )
        end
    end

    return nil
end
