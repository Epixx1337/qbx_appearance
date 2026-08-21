local backdrop = {}

backdrop.COLORS = {
    green = { 0, 255, 0 },
    blue = { 0, 60, 255 },
    magenta = { 255, 0, 255 },
    orange = { 255, 128, 0 },
}

backdrop.ORDER = { 'green', 'blue', 'magenta', 'orange' }

local active = false
local color = backdrop.COLORS.green
local center, right, up
local subjectPos, camPos

---@param name string
function backdrop.setColor(name)
    color = backdrop.COLORS[name] or backdrop.COLORS.green
end

---@param name string
---@return string? next name in the retry ladder, nil when exhausted
function backdrop.nextColor(name)
    for i = 1, #backdrop.ORDER do
        if backdrop.ORDER[i] == name then
            return backdrop.ORDER[i + 1]
        end
    end
end

---@param subjectCoords vector3
---@param camCoords vector3
---@param fov number camera fov in degrees
function backdrop.place(subjectCoords, camCoords, fov)
    subjectPos, camPos = subjectCoords, camCoords
    local toCam = camCoords - subjectCoords
    local dist = #toCam
    local dir = toCam / dist
    center = subjectCoords - dir * 2.0
    local size = math.tan(math.rad(fov) / 2) * (dist + 2.0) * 2.1
    right = vec3(-dir.y, dir.x, 0.0)
    right = right / #right * size
    up = vec3(0.0, 0.0, size)
end

function backdrop.start()
    if active then return end
    active = true
    NetworkOverrideClockTime(12, 30, 0)
    NetworkOverrideClockMillisecondsPerGameMinute(1000000)
    SetOverrideWeather('EXTRASUNNY')
    SetWind(0.0)
    SetWindSpeed(0.0)

    if IsEntityDead(cache.ped) or IsPedDeadOrDying(cache.ped, true) then
        TriggerEvent('qbx_medical:client:playerRevived')
        Wait(500)
    end
    local hadGodmode = GetPlayerInvincible(cache.playerId)
    local healTick = 0
    CreateThread(function()
        while active do
            local playerPed = PlayerPedId()
            SetPlayerInvincible(cache.playerId, true)
            SetEntityInvincible(playerPed, true)
            local now = GetGameTimer()
            if now > healTick then
                healTick = now + 5000
                local maxHealth = GetEntityMaxHealth(playerPed)
                if GetEntityHealth(playerPed) < maxHealth then
                    SetEntityHealth(playerPed, maxHealth)
                end
            end
            Wait(0)
        end
        SetPlayerInvincible(cache.playerId, hadGodmode)
        SetEntityInvincible(PlayerPedId(), hadGodmode)
    end)

    CreateThread(function()
        while active do
            HideHudAndRadarThisFrame()
            if subjectPos and camPos then
                local dir = subjectPos - camPos
                dir = dir / #dir
                DrawSpotLight(camPos.x, camPos.y, camPos.z + 0.3, dir.x, dir.y, dir.z,
                    255, 255, 255, 12.0, 1.1, 0.0, 13.0, 1.0)
                DrawLightWithRange(subjectPos.x, subjectPos.y, subjectPos.z + 0.8,
                    255, 255, 255, 3.5, 0.9)
            end
            if center then
                local r, g, b = color[1], color[2], color[3]
                local a = center - right - up
                local bq = center + right - up
                local c = center + right + up
                local d = center - right + up
                DrawPoly(a.x, a.y, a.z, bq.x, bq.y, bq.z, c.x, c.y, c.z, r, g, b, 255)
                DrawPoly(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z, r, g, b, 255)
                DrawPoly(c.x, c.y, c.z, bq.x, bq.y, bq.z, a.x, a.y, a.z, r, g, b, 255)
                DrawPoly(d.x, d.y, d.z, c.x, c.y, c.z, a.x, a.y, a.z, r, g, b, 255)
            end
            Wait(0)
        end
    end)
end

function backdrop.stop()
    active = false
    center = nil
    subjectPos, camPos = nil, nil
    NetworkOverrideClockMillisecondsPerGameMinute(2000)
    NetworkClearClockTimeOverride()
    ClearOverrideWeather()
end

return backdrop
