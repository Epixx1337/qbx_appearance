local db = require 'server.modules.db'
local config = require 'config.server'

local zones = {}

local function isZoneAdmin(source)
    return IsPlayerAceAllowed(source --[[@as string]], config.studioAce)
        or exports.qbx_core:HasPermission(source, 'admin')
end

CreateThread(function()
    zones = db.getZones()
    for _, zone in ipairs(zones) do
        if type(zone.points) == 'string' then
            zone.points = json.decode(zone.points)
        end
    end
end)

lib.callback.register('qbx_appearance:server:getZones', function()
    return zones
end)

local VALID_TYPES = {
    clothing = true, barber = true, tattoo = true, surgeon = true,
    job_locker = true, gang_locker = true,
}

local function sanitizeZone(data)
    if type(data) ~= 'table' or not VALID_TYPES[data.type] then return nil end
    if (data.type == 'job_locker' or data.type == 'gang_locker')
        and (type(data.group_name) ~= 'string' or data.group_name == '') then
        return nil
    end

    local label = type(data.label) == 'string' and data.label:sub(1, 64) or nil
    if label == '' then label = nil end

    local zone = {
        type = data.type,
        label = label,
        group_name = data.group_name,
        min_grade = math.max(0, math.floor(tonumber(data.min_grade) or 0)),
        x = tonumber(data.x), y = tonumber(data.y), z = tonumber(data.z),
        heading = tonumber(data.heading) or 0.0,
        width = math.min(50, math.max(1, tonumber(data.width) or 4)),
        length = math.min(50, math.max(1, tonumber(data.length) or 4)),
        height = math.min(30, math.max(1, tonumber(data.height) or 4)),
        blip = data.blip == true,
    }
    if not zone.x or not zone.y or not zone.z then return nil end

    if type(data.points) == 'table' then
        if #data.points < 3 or #data.points > 64 then return nil end
        local points = {}
        for i, point in ipairs(data.points) do
            local px, py, pz = tonumber(point.x or point[1]), tonumber(point.y or point[2]), tonumber(point.z or point[3])
            if not px or not py or not pz then return nil end
            points[i] = { px, py, pz }
        end
        zone.points = points
    end
    return zone
end

lib.callback.register('qbx_appearance:server:addZone', function(source, data)
    if not isZoneAdmin(source) then return nil end
    local zone = sanitizeZone(data)
    if not zone then return nil end

    local player = exports.qbx_core:GetPlayer(source)
    zone.id = db.addZone(zone, player and player.PlayerData.citizenid or nil)
    zone.blip = zone.blip and 1 or 0
    zones[#zones + 1] = zone
    TriggerClientEvent('qbx_appearance:client:zoneAdded', -1, zone)
    lib.print.info(('zone #%d (%s) created by %s'):format(zone.id, zone.type, GetPlayerName(source)))
    return zone.id
end)

lib.callback.register('qbx_appearance:server:updateZone', function(source, id, data)
    if not isZoneAdmin(source) or type(id) ~= 'number' then return false end
    local zone = sanitizeZone(data)
    if not zone then return false end
    if not db.updateZone(id, zone) then return false end

    zone.id = id
    zone.blip = zone.blip and 1 or 0
    for i = 1, #zones do
        if zones[i].id == id then zones[i] = zone break end
    end
    TriggerClientEvent('qbx_appearance:client:zoneUpdated', -1, zone)
    lib.print.info(('zone #%d (%s) updated by %s'):format(id, zone.type, GetPlayerName(source)))
    return true
end)

lib.callback.register('qbx_appearance:server:deleteZone', function(source, id)
    if not isZoneAdmin(source) or type(id) ~= 'number' then return false end
    if not db.deleteZone(id) then return false end
    for i = #zones, 1, -1 do
        if zones[i].id == id then table.remove(zones, i) end
    end
    TriggerClientEvent('qbx_appearance:client:zoneRemoved', -1, id)
    return true
end)

lib.addCommand('appearancezone', {
    help = 'Create or delete appearance shop/locker zones at your position',
    restricted = config.studioGroup,
}, function(source)
    TriggerClientEvent('qbx_appearance:client:zoneTool', source)
end)
