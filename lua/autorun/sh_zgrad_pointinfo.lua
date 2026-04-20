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
