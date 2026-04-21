hg = hg or {}
if ReadPoint then return end

local angZero = Angle( 0, 0, 0 )

function ReadPoint( point )
    if isvector( point ) then
        return { point, angZero }
    elseif istable( point ) then
        if isnumber( point[2] ) then
            return { point[1], angZero, point[2] }
        end

        return point
    end
end
