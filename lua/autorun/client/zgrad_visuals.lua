local TOOL_NAME         = "zgrad_point_tool"
local HOVER_RADIUS_SQ   = 160 * 160
local SPHERE_SEGS       = 12

local RENDER_DIST       = 4000
local RENDER_DIST_SQ    = RENDER_DIST * RENDER_DIST
local FADE_START        = 1200
local FADE_RANGE        = RENDER_DIST - FADE_START
local LABEL_DIST_SQ     = 1200 * 1200

local SELECTED_COLOR    = Color( 255, 230, 60 )
local HOVER_COLOR       = Color( 255, 180, 50 )
local HAMMER_COLOR      = Color( 120, 120, 120 )
local BLOCKED_COLOR     = Color( 255, 60, 60 )

local function GetRadius( typeName )
    return ZGRAD.GetPointRadius and ZGRAD.GetPointRadius( typeName ) or 24
end

local ARROW_LENGTH     = 40
local ARROW_HEAD       = 16
local ARROW_HEAD_WING  = ARROW_HEAD * 0.6

local LABEL_BG     = Color( 0, 0, 0, 160 )

local PANEL_FONT = "DermaLarge"

local _col = Color( 0, 0, 0, 0 )
local function MutColor( col, alpha )
    _col.r = col.r
    _col.g = col.g
    _col.b = col.b
    _col.a = math.Clamp( alpha, 0, 255 )
    return _col
end

local selectedPoint  = nil
local hoveredPoint   = nil

local pointCache     = {}
local typeColorCache = {}

local function RebuildCache()
    pointCache    = {}
    typeColorCache = {}

    for dataKey, info in pairs( ZGRAD.SpawnPointsList or {} ) do
        local typeName   = info[1]
        local baseColor  = info[2]
        local pts        = info[3]
        local gameRadius = GetRadius( typeName )

        typeColorCache[typeName] = baseColor

        if not pts then continue end

        for i, rawPt in ipairs( pts ) do
            local p = ZGRAD.ReadPoint( rawPt )
            if not p then continue end

            pointCache[#pointCache + 1] = {
                pos        = p[1],
                ang        = p[2],
                num        = p[3],
                typeName   = typeName,
                baseColor  = baseColor,
                gameRadius = gameRadius,
                dataIndex  = i,
                hammer     = rawPt[4] == true,
            }
        end
    end
end

local function DataKeyForShortName( shortName )
    for k, info in pairs( ZGRAD.SpawnPointsList or {} ) do
        if info[1] == shortName then return k end
    end
end

net.Receive( "zgrad_pt_select", function()
    local pointType = net.ReadString()
    local index     = net.ReadUInt( 16 )

    local key  = DataKeyForShortName( pointType )
    local info = key and ZGRAD.SpawnPointsList and ZGRAD.SpawnPointsList[key]
    if not info then return end

    local pts = info[3]
    if not pts or not pts[index] then return end

    local p = ZGRAD.ReadPoint( pts[index] )
    selectedPoint = {
        pointType = pointType,
        index     = index,
        pos       = p[1],
        ang       = p[2],
    }
end )

net.Receive( "zgrad_pt_select_deny", function()
    surface.PlaySound( "buttons/button10.wav" )
    chat.AddText( Color( 255, 80, 80 ), "[ZGRAD]", color_white, " Cannot select Hammer-placed points." )
end )

net.Receive( "zgrad_pt_place_deny", function()
    surface.PlaySound( "buttons/button10.wav" )
end )

local function IsToolActive()
    local ply = LocalPlayer()
    if not IsValid( ply ) then return false end
    local wep = ply:GetActiveWeapon()
    if not IsValid( wep ) then return false end
    if wep:GetClass() ~= "gmod_tool" then return false end
    return ply:GetInfo( "gmod_toolmode" ) == TOOL_NAME
end

local _eyePos = Vector()
local _eyeFwd = Vector()

local function FindClosestPointToScreen( screenX, screenY, maxDistSq )
    local best, bestDistSq = nil, maxDistSq or math.huge

    for _, entry in ipairs( pointCache ) do
        if entry.hammer then continue end

        local pos = entry.pos
        if pos:DistToSqr( _eyePos ) > RENDER_DIST_SQ then continue end

        local dx = pos.x - _eyePos.x
        local dy = pos.y - _eyePos.y
        local dz = pos.z - _eyePos.z
        if _eyeFwd.x * dx + _eyeFwd.y * dy + _eyeFwd.z * dz <= 0 then continue end

        local sp = pos:ToScreen()
        if not sp.visible then continue end

        local sdx = sp.x - screenX
        local sdy = sp.y - screenY
        local dSq = sdx * sdx + sdy * sdy

        if dSq < bestDistSq then
            bestDistSq = dSq
            best = entry
        end
    end

    return best
end

local ringCache = {}

local function GetRingVerts( radius, segs )
    local key = radius .. "_" .. segs
    if ringCache[key] then return ringCache[key] end

    local verts = {}
    local step  = ( math.pi * 2 ) / segs
    for i = 0, segs do
        local a = i * step
        verts[i + 1] = { math.cos( a ), math.sin( a ) }
    end
    ringCache[key] = verts
    return verts
end

local _rp1 = Vector()
local _rp2 = Vector()

local function DrawGroundRing( pos, radius, col, segs )
    local verts = GetRingVerts( radius, segs )
    local pz    = pos.z
    render.SetColorMaterial()
    for i = 1, #verts - 1 do
        local v1 = verts[i]
        local v2 = verts[i + 1]
        _rp1.x = pos.x + v1[1] * radius  _rp1.y = pos.y + v1[2] * radius  _rp1.z = pz
        _rp2.x = pos.x + v2[1] * radius  _rp2.y = pos.y + v2[2] * radius  _rp2.z = pz
        render.DrawLine( _rp1, _rp2, col, true )
    end
end

local function DrawDirectionArrow( pos, ang, color )
    local base = pos + Vector( 0, 0, 4 )
    local fwd  = ang:Forward()
    local rgt  = ang:Right()
    fwd.z = 0
    rgt.z = 0

    local tip  = base + fwd * ARROW_LENGTH
    local back = tip  - fwd * ARROW_HEAD

    render.SetColorMaterial()
    render.DrawLine( base, tip,                        color, true )
    render.DrawLine( tip,  back + rgt * ARROW_HEAD_WING, color, true )
    render.DrawLine( tip,  back - rgt * ARROW_HEAD_WING, color, true )
end

local FADE_START_SQ = FADE_START * FADE_START

local function DistAlpha( distSq )
    if distSq <= FADE_START_SQ then return 1 end
    local dist = math.sqrt( distSq )
    return 1 - ( dist - FADE_START ) / FADE_RANGE
end

local function DrawAllPoints()
    for _, entry in ipairs( pointCache ) do
        local pos    = entry.pos
        local distSq = pos:DistToSqr( _eyePos )
        if distSq > RENDER_DIST_SQ then continue end

        local dx = pos.x - _eyePos.x
        local dy = pos.y - _eyePos.y
        local dz = pos.z - _eyePos.z
        if _eyeFwd.x * dx + _eyeFwd.y * dy + _eyeFwd.z * dz <= 0 then continue end

        local fade = DistAlpha( distSq )

        local col, solidAlpha, fadeAlpha
        if entry.hammer then
            col        = HAMMER_COLOR
            solidAlpha = math.floor( 80 * fade )
            fadeAlpha  = math.floor( 15 * fade )
        else
            local isSel = selectedPoint
                and selectedPoint.pointType == entry.typeName
                and selectedPoint.index     == entry.dataIndex
            local isHov = hoveredPoint
                and hoveredPoint.typeName  == entry.typeName
                and hoveredPoint.dataIndex == entry.dataIndex

            col        = isSel and SELECTED_COLOR or ( isHov and HOVER_COLOR or entry.baseColor )
            solidAlpha = math.floor( 200 * fade )
            fadeAlpha  = math.floor(  40 * fade )
        end

        render.SetColorMaterial()

        if entry.typeName == "control_point" then
            render.DrawWireframeSphere( pos, entry.gameRadius, SPHERE_SEGS, SPHERE_SEGS,
                MutColor( col, fadeAlpha ) )
            DrawGroundRing( pos, entry.gameRadius, MutColor( col, solidAlpha ), 48 )
        else
            DrawGroundRing( pos, entry.gameRadius, MutColor( col, fadeAlpha ), 16 )
        end

        render.DrawSphere( pos, 4, 8, 8, MutColor( col, solidAlpha ) )
        DrawDirectionArrow( pos, entry.ang, MutColor( col, solidAlpha ) )
    end
end

local function GetPlacementPos( ply )
    local base
    if ply:GetInfo( "zgrad_point_tool_place_mode" ) == "self" then
        base = ply:GetPos()
    else
        local tr = util.TraceLine({
            start  = ply:EyePos(),
            endpos = ply:EyePos() + ply:EyeAngles():Forward() * 1024,
            filter = ply,
        })
        if not tr.Hit then return nil end
        base = tr.HitPos + Vector( 0, 0, 5 )
    end

    if ply:GetInfoNum( "zgrad_point_tool_snap_ground", 0 ) >= 1 and ZGRAD.SnapToGround then
        local snapped = ZGRAD.SnapToGround( base )
        if snapped then return snapped end
    end

    return base
end

local GHOST_CACHE_DIST_SQ = 16
local GHOST_CACHE_TTL     = 0.1
local ghostCache          = { time = -1 }

local function CachedResolvePlacement( pos, typeName, ignoreKey, ignoreIdx )
    if not ZGRAD.ResolvePlacement then return nil end

    local now = RealTime()
    if ghostCache.time >= 0
        and now - ghostCache.time < GHOST_CACHE_TTL
        and ghostCache.type      == typeName
        and ghostCache.ignoreKey == ignoreKey
        and ghostCache.ignoreIdx == ignoreIdx
        and ghostCache.pos:DistToSqr( pos ) < GHOST_CACHE_DIST_SQ
    then
        return ghostCache.resolved
    end

    local resolved = ZGRAD.ResolvePlacement( pos, typeName, ignoreKey, ignoreIdx )
    ghostCache.time      = now
    ghostCache.pos       = Vector( pos )
    ghostCache.type      = typeName
    ghostCache.ignoreKey = ignoreKey
    ghostCache.ignoreIdx = ignoreIdx
    ghostCache.resolved  = resolved
    return resolved
end

local function DrawAreaRectangle( center, yaw, length, width, col )
    local ang = Angle( 0, yaw, 0 )
    local fwd = ang:Forward()
    local rgt = ang:Right()

    local hl = length * 0.5
    local hw = width  * 0.5

    local c1 = center + fwd *  hl + rgt *  hw
    local c2 = center + fwd *  hl + rgt * -hw
    local c3 = center + fwd * -hl + rgt * -hw
    local c4 = center + fwd * -hl + rgt *  hw

    render.SetColorMaterial()
    render.DrawLine( c1, c2, col, true )
    render.DrawLine( c2, c3, col, true )
    render.DrawLine( c3, c4, col, true )
    render.DrawLine( c4, c1, col, true )

    render.DrawLine( center + fwd * -hl, center + fwd * hl, col, true )
    render.DrawLine( center + rgt * -hw, center + rgt * hw, col, true )
end

local areaCache = { time = -1, points = {} }
local AREA_CACHE_TTL      = 0.15
local AREA_CACHE_DIST_SQ  = 64

local function GetCachedAreaPoints( ply, center, yaw, placementType, typeName )
    local nowMinSpacing = ply:GetInfoNum( "zgrad_point_tool_area_min_spacing", 64 )
    local nowLength     = ply:GetInfoNum( "zgrad_point_tool_area_length", 512 )
    local nowWidth      = ply:GetInfoNum( "zgrad_point_tool_area_width",  512 )
    local nowGrid       = ply:GetInfoNum( "zgrad_point_tool_grid_spacing", 64 )
    local nowMaxCount   = ply:GetInfoNum( "zgrad_point_tool_area_count", 16 )

    local now = RealTime()
    if areaCache.time >= 0
        and now - areaCache.time < AREA_CACHE_TTL
        and areaCache.type        == placementType
        and areaCache.pointType   == typeName
        and areaCache.yaw         == yaw
        and areaCache.minSpacing  == nowMinSpacing
        and areaCache.length      == nowLength
        and areaCache.width       == nowWidth
        and areaCache.gridSpacing == nowGrid
        and areaCache.maxCount    == nowMaxCount
        and areaCache.center:DistToSqr( center ) < AREA_CACHE_DIST_SQ
    then
        return areaCache.points
    end

    local length     = ply:GetInfoNum( "zgrad_point_tool_area_length", 512 )
    local width      = ply:GetInfoNum( "zgrad_point_tool_area_width",  512 )
    local minSpacing = math.max( 0, ply:GetInfoNum( "zgrad_point_tool_area_min_spacing", 64 ) )
    local maxCount   = math.max( 1, math.floor( ply:GetInfoNum( "zgrad_point_tool_area_count", 16 ) ) )
    local snap       = ply:GetInfoNum( "zgrad_point_tool_snap_ground", 0 ) >= 1
    local minSq      = minSpacing * minSpacing

    local raw
    if placementType == "grid" then
        local spacing = math.max( 8, ply:GetInfoNum( "zgrad_point_tool_grid_spacing", 64 ) )
        raw = ZGRAD.GetAreaGridPositions( center, yaw, length, width, spacing, maxCount )
    else
        raw = {}
    end

    local result = {}
    local batch  = {}
    for _, p in ipairs( raw ) do
        local pos = p
        if snap then
            pos = ZGRAD.SnapToGround( p ) or p
        end

        local ok = not ZGRAD.IsPointInWall( pos )
            and not ZGRAD.FindIntersectingPoint( pos, typeName )

        if ok and minSpacing > 0 and ZGRAD.FindNearbyPoint( pos, minSpacing ) then
            ok = false
        end

        if ok then
            for _, other in ipairs( batch ) do
                if ZGRAD.PointsIntersect( pos, typeName, other, typeName ) then
                    ok = false
                    break
                end
                if minSq > 0 and pos:DistToSqr( other ) < minSq then
                    ok = false
                    break
                end
            end
        end

        if ok and #batch >= maxCount then ok = false end

        result[#result + 1] = { pos = pos, ok = ok }
        if ok then batch[#batch + 1] = pos end
    end

    areaCache.time        = now
    areaCache.type        = placementType
    areaCache.pointType   = typeName
    areaCache.yaw         = yaw
    areaCache.minSpacing  = nowMinSpacing
    areaCache.length      = nowLength
    areaCache.width       = nowWidth
    areaCache.gridSpacing = nowGrid
    areaCache.maxCount    = nowMaxCount
    areaCache.center      = Vector( center )
    areaCache.points      = result
    return result
end

local function DrawGhostPreview()
    local ply  = LocalPlayer()
    local mode = ply:GetInfo( "zgrad_point_tool_mode" )

    local typeName, pos
    if mode == "place" then
        typeName = ply:GetInfo( "zgrad_point_tool_point_type" )
        pos = GetPlacementPos( ply )
    elseif mode == "select" and selectedPoint then
        typeName = selectedPoint.pointType
        pos = GetPlacementPos( ply )
    end

    if not pos then return end

    local placementType = mode == "place" and ply:GetInfo( "zgrad_point_tool_placement_type" ) or "single"
    if placementType == "random" or placementType == "grid" then
        local baseCol = typeColorCache[typeName] or color_white
        local length  = ply:GetInfoNum( "zgrad_point_tool_area_length", 512 )
        local width   = ply:GetInfoNum( "zgrad_point_tool_area_width",  512 )
        local yaw     = ply:EyeAngles().y

        DrawAreaRectangle( pos, yaw, length, width, MutColor( baseCol, 180 ) )

        if placementType == "grid" then
            local points = GetCachedAreaPoints( ply, pos, yaw, placementType, typeName )
            for _, entry in ipairs( points ) do
                local c = entry.ok and baseCol or BLOCKED_COLOR
                render.DrawSphere( entry.pos, 3, 6, 6, MutColor( c, 180 ) )
            end
        end

        return
    end

    local ignoreKey, ignoreIdx
    if mode == "select" and selectedPoint then
        ignoreKey = DataKeyForShortName( selectedPoint.pointType )
        ignoreIdx = selectedPoint.index
    end

    local resolved = CachedResolvePlacement( pos, typeName, ignoreKey, ignoreIdx )

    local shifted = resolved and resolved ~= pos and resolved:DistToSqr( pos ) > 0.25
    local drawPos = resolved or pos
    local blocked = not resolved

    local col        = blocked and BLOCKED_COLOR or ( typeColorCache[typeName] or color_white )
    local gameRadius = GetRadius( typeName )
    local ang        = Angle( 0, ply:EyeAngles().y, 0 )

    render.SetColorMaterial()

    if typeName == "control_point" then
        render.DrawWireframeSphere( drawPos, gameRadius, SPHERE_SEGS, SPHERE_SEGS,
            MutColor( col, 25 ) )
        DrawGroundRing( drawPos, gameRadius, MutColor( col, 160 ), 48 )
    else
        DrawGroundRing( drawPos, gameRadius, MutColor( col, 80 ), 16 )
    end

    render.DrawSphere( drawPos, 4, 8, 8, MutColor( col, 160 ) )
    DrawDirectionArrow( drawPos, ang, MutColor( col, 160 ) )

    if shifted then
        render.SetColorMaterial()
        local steps = 8
        for s = 0, steps - 1, 2 do
            render.DrawLine(
                LerpVector( s / steps,         pos, drawPos ),
                LerpVector( ( s + 1 ) / steps, pos, drawPos ),
                MutColor( col, 110 ), true
            )
        end
        render.DrawSphere( pos, 2, 6, 6, MutColor( col, 80 ) )
    end

    if mode == "select" and selectedPoint and selectedPoint.pos then
        local from  = selectedPoint.pos
        local steps = 8
        render.SetColorMaterial()
        for s = 0, steps - 1, 2 do
            render.DrawLine(
                LerpVector( s / steps,         from, drawPos ),
                LerpVector( ( s + 1 ) / steps, from, drawPos ),
                MutColor( col, 120 ), true
            )
        end
    end
end

local function DrawScreenLabels()
    local plyPos = LocalPlayer():GetPos()

    for _, entry in ipairs( pointCache ) do
        local pos    = entry.pos
        local distSq = pos:DistToSqr( plyPos )
        if distSq > LABEL_DIST_SQ then continue end

        local sp = pos:ToScreen()
        if not sp.visible then continue end

        local fade = DistAlpha( distSq )

        local col, label
        if entry.hammer then
            col   = HAMMER_COLOR
            label = entry.typeName .. " #" .. entry.dataIndex .. " [H]"
        else
            local isSel = selectedPoint
                and selectedPoint.pointType == entry.typeName
                and selectedPoint.index     == entry.dataIndex
            local isHov = hoveredPoint
                and hoveredPoint.typeName  == entry.typeName
                and hoveredPoint.dataIndex == entry.dataIndex

            col   = isSel and SELECTED_COLOR or ( isHov and HOVER_COLOR or entry.baseColor )
            label = entry.typeName .. " #" .. entry.dataIndex

            local tw = #label * 6 + 10
            draw.RoundedBox( 4, sp.x - tw / 2, sp.y - 22, tw, 14,
                MutColor( LABEL_BG, math.floor( 160 * fade ) ) )
            draw.SimpleText( label, "DefaultFixedDropShadow", sp.x, sp.y - 15,
                MutColor( col, math.floor( 220 * fade ) ),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

            if isSel then
                draw.SimpleText( "SELECTED", "DefaultFixedDropShadow", sp.x, sp.y - 2,
                    MutColor( SELECTED_COLOR, math.floor( 220 * fade ) ),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
            end
            continue
        end

        draw.SimpleText( label, "DefaultFixedDropShadow", sp.x, sp.y - 15,
            MutColor( col, math.floor( 140 * fade ) ),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
    end
end

hook.Add( "PlayerButtonDown", "ZGrad_PointToolSelectInput", function( ply, button )
    if ply ~= LocalPlayer() then return end
    if not IsToolActive() then return end
    if button ~= MOUSE_LEFT then return end
    if ply:GetInfo( "zgrad_point_tool_mode" ) ~= "select" then return end
    if selectedPoint then return end

    local nearest = FindClosestPointToScreen( ScrW() / 2, ScrH() / 2, HOVER_RADIUS_SQ * 4 )
    if not nearest then return end

    net.Start( "zgrad_pt_select_sv" )
        net.WriteString( nearest.typeName )
        net.WriteUInt( nearest.dataIndex, 16 )
    net.SendToServer()
end )

hook.Add( "PlayerButtonDown", "ZGrad_PointToolDeselect", function( ply, button )
    if ply ~= LocalPlayer() then return end
    if not IsToolActive() then return end
    if button ~= KEY_R then return end
    selectedPoint = nil
end )

hook.Add( "WeaponEquipped", "ZGrad_PointToolClearOnSwitch", function( wep, ply )
    if not IsValid( ply ) or ply ~= LocalPlayer() then return end
    if IsValid( wep ) and wep:GetClass() ~= "gmod_tool" then
        selectedPoint = nil
        hoveredPoint  = nil
    end
end )

hook.Add( "ZGrad_SpawnPointsUpdated", "ZGrad_ClearOnSpawnPointsUpdate", function()
    selectedPoint = nil
    hoveredPoint  = nil
    RebuildCache()
end )

hook.Add( "PostDrawTranslucentRenderables", "ZGrad_PointToolDraw3D", function( bDepth, bSkybox )
    if bDepth or bSkybox then return end
    if not IsToolActive() then return end

    local ply = LocalPlayer()
    local eyeAng = ply:EyeAngles()
    local eyePos = ply:EyePos()
    _eyePos:Set( eyePos )
    _eyeFwd:Set( eyeAng:Forward() )

    hoveredPoint = FindClosestPointToScreen( ScrW() / 2, ScrH() / 2, HOVER_RADIUS_SQ )

    DrawAllPoints()
    DrawGhostPreview()
end )

hook.Add( "HUDPaint", "ZGrad_PointToolDraw2D", function()
    if not IsToolActive() then return end

    DrawScreenLabels()

    local ply       = LocalPlayer()
    local mode      = ply:GetInfo( "zgrad_point_tool_mode" )
    local placeMode = ply:GetInfo( "zgrad_point_tool_place_mode" )
    local typeName  = ply:GetInfo( "zgrad_point_tool_point_type" )
    local sw, sh    = ScrW(), ScrH()

    local originTxt = placeMode == "self" and "Self" or "Surface"
    local modeLabel = mode == "place" and "Place" or "Select"

    local margin  = 14
    local pad     = 16
    local lineGap = 10

    local l1 = "Map Point Editor"
    local l2 = "Mode: " .. modeLabel
    local l3 = "Origin: " .. originTxt
    local l4 = "Type: " .. ( typeName or "?" )

    surface.SetFont( PANEL_FONT )
    local _, fh = surface.GetTextSize( "M" )
    local w = math.max(
        surface.GetTextSize( l1 ),
        surface.GetTextSize( l2 ),
        surface.GetTextSize( l3 ),
        surface.GetTextSize( l4 )
    )

    local panelW = w + pad * 2
    local panelH = pad * 2 + 4 * fh + 3 * lineGap
    local bx     = sw - panelW - margin
    local by     = margin

    surface.SetDrawColor( 0, 0, 0, 160 )
    surface.DrawRect( bx, by, panelW, panelH )

    local tx = bx + pad
    local ty = by + pad
    draw.SimpleText( l1, PANEL_FONT, tx, ty, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
    ty = ty + fh + lineGap
    draw.SimpleText( l2, PANEL_FONT, tx, ty, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
    ty = ty + fh + lineGap
    draw.SimpleText( l3, PANEL_FONT, tx, ty, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
    ty = ty + fh + lineGap
    draw.SimpleText( l4, PANEL_FONT, tx, ty, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )

    if selectedPoint then
        local label = "Selected: " .. selectedPoint.pointType .. " #" .. selectedPoint.index
        if mode == "select" then
            label = label .. " — LMB move, RMB delete"
        end

        surface.SetFont( PANEL_FONT )
        local tw = surface.GetTextSize( label )
        local barW = tw + pad * 2
        local barH = fh + pad * 2
        local sx = sw / 2
        local sy = sh / 2 + 24

        surface.SetDrawColor( 0, 0, 0, 160 )
        surface.DrawRect( sx - barW / 2, sy, barW, barH )
        draw.SimpleText( label, PANEL_FONT, sx, sy + barH / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
    end
end )

RebuildCache()
