if ReadPoint then return end

local angZero = Angle( 0, 0, 0 )

function ReadPoint( point )
    if isvector( point ) then
        return { point, angZero }
    elseif istable( point ) then
        if isnumber( point[2] ) then
            point[3] = point[2]
            point[2] = angZero
        end

        return point
    end
end
