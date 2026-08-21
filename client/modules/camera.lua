local camera = {}

local cam
local targetPed
local active = false

local heading = 0.0
local zoom = 1.0
local focusHeight = 0.5
local current = { heading = 0.0, zoom = 1.0, focus = 0.5 }

local FULL_DISTANCE = 2.9
local CLOSE_DISTANCE = 0.45
local FULL_FOV = 42.0
local CLOSE_FOV = 30.0

local BONES = {
    { height = 0.00, bone = 14201, pair = 52301, zOff = 0.0 },
    { height = 0.30, bone = 58271, pair = 51826, zOff = 0.0 },
    { height = 0.55, bone = 11816, zOff = 0.0 },
    { height = 0.80, bone = 24818, zOff = 0.0 },
    { height = 1.00, bone = 31086, zOff = 0.14 },
}

local function boneCoords(ped, entry)
    local pos = GetPedBoneCoords(ped, entry.bone, 0.0, 0.0, 0.0)
    if entry.pair then
        pos = (pos + GetPedBoneCoords(ped, entry.pair, 0.0, 0.0, 0.0)) / 2
    end
    return pos + vec3(0.0, 0.0, entry.zOff)
end

local SCREEN_SHIFT = 0.10

local PRESETS = {
    face = { zoom = 0.06, focus = 1.0 },
    hair = { zoom = 0.10, focus = 1.0 },
    eyes = { zoom = 0.04, focus = 1.0 },
    hat = { zoom = 0.12, focus = 1.0 },
    mask = { zoom = 0.10, focus = 1.0 },
    glasses = { zoom = 0.07, focus = 1.0 },
    ears = { zoom = 0.08, focus = 1.0, heading = 80.0 },
    torso = { zoom = 0.45, focus = 0.78 },
    arms = { zoom = 0.45, focus = 0.75 },
    watch = { zoom = 0.25, focus = 0.62, heading = 70.0 },
    bracelet = { zoom = 0.25, focus = 0.62, heading = -70.0 },
    pants = { zoom = 0.45, focus = 0.35 },
    shoes = { zoom = 0.30, focus = 0.05 },
    bag = { zoom = 0.55, focus = 0.75, heading = 180.0 },
    full = { zoom = 1.0, focus = 0.5 },
}

local TATTOO_ZONES = {
    ZONE_TORSO = { zoom = 0.5, focus = 0.75, pedTurn = 0.0 },
    ZONE_HEAD = { zoom = 0.12, focus = 1.0, pedTurn = 0.0 },
    ZONE_LEFT_ARM = { zoom = 0.35, focus = 0.7, pedTurn = -90.0 },
    ZONE_RIGHT_ARM = { zoom = 0.35, focus = 0.7, pedTurn = 90.0 },
    ZONE_LEFT_LEG = { zoom = 0.4, focus = 0.3, pedTurn = -90.0 },
    ZONE_RIGHT_LEG = { zoom = 0.4, focus = 0.3, pedTurn = 90.0 },
    ZONE_BACK = { zoom = 0.5, focus = 0.75, pedTurn = 180.0 },
}

local basePedHeading = 0.0
local origPedHeading = 0.0
local targetPedHeading

local function focusCoords(ped, focus)
    local lower, upper = BONES[1], BONES[#BONES]
    for i = 1, #BONES - 1 do
        if focus >= BONES[i].height and focus <= BONES[i + 1].height then
            lower, upper = BONES[i], BONES[i + 1]
            break
        end
    end
    local span = upper.height - lower.height
    local t = span > 0 and (focus - lower.height) / span or 0
    local a = boneCoords(ped, lower)
    local b = boneCoords(ped, upper)
    return a + (b - a) * t
end

local function updateCam()
    local effectiveFocus = current.focus
        + (0.5 - current.focus) * math.max(0.0, (current.zoom - 0.85) / 0.15)
    local focus = focusCoords(targetPed, effectiveFocus)
    local distance = CLOSE_DISTANCE + (FULL_DISTANCE - CLOSE_DISTANCE) * current.zoom
    local fov = CLOSE_FOV + (FULL_FOV - CLOSE_FOV) * current.zoom
    local rad = math.rad(current.heading + basePedHeading)
    local pos = vec3(
        focus.x + math.sin(rad) * distance,
        focus.y + math.cos(rad) * distance,
        focus.z + 0.05 * current.zoom
    )
    SetCamCoord(cam, pos.x, pos.y, pos.z)
    local dir = focus - pos
    local flat = vec3(dir.x, dir.y, 0.0)
    local len = #flat
    if len > 0.01 then
        local right = vec3(dir.y / len, -dir.x / len, 0.0)
        local shift = distance * SCREEN_SHIFT
        SetCamCoord(cam, pos.x + right.x * shift, pos.y + right.y * shift, pos.z)
        PointCamAtCoord(cam, focus.x + right.x * shift, focus.y + right.y * shift, focus.z)
    else
        PointCamAtCoord(cam, focus.x, focus.y, focus.z)
    end
    SetCamFov(cam, fov)
end

---@param ped number
function camera.start(ped)
    if active then camera.stop() end
    targetPed = ped
    ClearPedTasksImmediately(ped)
    FreezeEntityPosition(ped, true)
    origPedHeading = GetEntityHeading(ped)
    basePedHeading = -origPedHeading
    heading, zoom, focusHeight = 0.0, 1.0, 0.5
    current = { heading = 0.0, zoom = 1.0, focus = 0.5 }
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    updateCam()
    RenderScriptCams(true, true, 500, true, true)
    DisableIdleCamera(true)
    active = true

    CreateThread(function()
        while active do
            local lerp = math.min(1.0, GetFrameTime() * 8.0)
            current.heading += (heading - current.heading) * lerp
            current.zoom += (zoom - current.zoom) * lerp
            current.focus += (focusHeight - current.focus) * lerp
            if targetPedHeading then
                local ph = GetEntityHeading(targetPed)
                local diff = (targetPedHeading - ph + 540.0) % 360.0 - 180.0
                if math.abs(diff) < 1.0 then
                    SetEntityHeading(targetPed, targetPedHeading)
                    targetPedHeading = nil
                else
                    SetEntityHeading(targetPed, ph + diff * lerp)
                end
            end
            updateCam()
            Wait(0)
        end
    end)
end

function camera.stop()
    if not active then return end
    active = false
    if targetPed and DoesEntityExist(targetPed) then
        FreezeEntityPosition(targetPed, false)
    end
    RenderScriptCams(false, true, 500, true, true)
    if cam then DestroyCam(cam, false) end
    cam = nil
    DisableIdleCamera(false)
end

---@param dx number
---@param dy number?
function camera.rotate(dx, dy)
    heading = (heading + dx * 0.4) % 360.0
    if dy and dy ~= 0 then
        local sensitivity = 0.0012 + 0.0022 * current.zoom
        focusHeight = math.max(0.0, math.min(1.0, focusHeight + dy * sensitivity))
    end
end

---@param dir number +1 in / -1 out
---@param cursorY number? 0 (top) .. 1 (bottom)
function camera.zoom(dir, cursorY)
    zoom = math.max(0.0, math.min(1.0, zoom - dir * 0.12))
    if dir <= 0 or not cursorY or not targetPed then return end

    local screenY = {}
    for i = 1, #BONES do
        local pos = boneCoords(targetPed, BONES[i])
        local onScreen, _, sy = GetScreenCoordFromWorldCoord(pos.x, pos.y, pos.z)
        screenY[i] = onScreen and sy or nil
    end

    for i = 1, #BONES - 1 do
        local yLow, yHigh = screenY[i], screenY[i + 1]
        if yLow and yHigh and cursorY <= yLow and cursorY >= yHigh then
            local t = (yLow - cursorY) / math.max(0.001, yLow - yHigh)
            focusHeight = BONES[i].height + (BONES[i + 1].height - BONES[i].height) * t
            return
        end
    end
    local top, bottom = screenY[#BONES], screenY[1]
    if top and cursorY < top then
        focusHeight = 1.0
    elseif bottom and cursorY > bottom then
        focusHeight = 0.0
    end
end

---@param name string
function camera.preset(name)
    local preset = PRESETS[name] or PRESETS.full
    zoom = preset.zoom
    focusHeight = preset.focus
    heading = preset.heading or 0.0
end

function camera.flip()
    heading = (heading + 180.0) % 360.0
end

---@param zone string
---@param back boolean? frame the back variant of a torso zone
function camera.tattooZone(zone, back)
    local preset = TATTOO_ZONES[back and 'ZONE_BACK' or zone] or TATTOO_ZONES.ZONE_TORSO
    zoom = preset.zoom
    focusHeight = preset.focus
    heading = 0.0
    targetPedHeading = (origPedHeading + preset.pedTurn) % 360.0
end

---@return boolean
function camera.isActive()
    return active
end

return camera
