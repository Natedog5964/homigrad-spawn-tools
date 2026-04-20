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

local WALL_STEP      = 4
local WALL_MAX_UP    = 256
local RESOLVE_ITERS  = 24
local MAX_DRIFT      = 512
local MAX_DRIFT_SQ   = MAX_DRIFT * MAX_DRIFT

function ZGRAD.ResolvePlacement( pos, typeName, ignoreDataKey, ignoreIndex )
    local current = Vector( pos )

    for _ = 1, RESOLVE_ITERS do
        if current:DistToSqr( pos ) > MAX_DRIFT_SQ then return nil end

        if ZGRAD.IsPointInWall( current ) then
            local lifted
            for z = WALL_STEP, WALL_MAX_UP, WALL_STEP do
                local test = current + Vector( 0, 0, z )
                if not ZGRAD.IsPointInWall( test ) then
                    lifted = test
                    break
                end
            end
            if not lifted then return nil end
            current = lifted
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
