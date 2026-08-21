local config = require 'config.client'
local editor = require 'client.modules.editor'

local zones = {}
local active = {}

local TYPE_EVENTS = {
    clothing = 'qbx_appearance:client:openClothing',
    barber = 'qbx_appearance:client:openBarber',
    tattoo = 'qbx_appearance:client:openTattoo',
    surgeon = 'qbx_appearance:client:openSurgeon',
    job_locker = 'qbx_appearance:client:openJobOutfits',
    gang_locker = 'qbx_appearance:client:openGangOutfits',
}

local function allowedInZone(data)
    if data.type == 'job_locker' then
        local job = QBX.PlayerData.job
        return job and job.name == data.group_name and job.grade.level >= (data.min_grade or 0)
    end
    if data.type == 'gang_locker' then
        local gang = QBX.PlayerData.gang
        return gang and gang.name == data.group_name and gang.grade.level >= (data.min_grade or 0)
    end
    return true
end

local function inGroup(data)
    if data.type == 'job_locker' then
        local job = QBX.PlayerData.job
        return (job and job.name == data.group_name) == true
    end
    if data.type == 'gang_locker' then
        local gang = QBX.PlayerData.gang
        return (gang and gang.name == data.group_name) == true
    end
    return true
end

local function wantsBlip(data)
    return (data.blip == true or data.blip == 1) and config.blips[data.type] ~= nil and inGroup(data)
end

local function createBlip(data)
    local blipConfig = config.blips[data.type]
    local blip = AddBlipForCoord(data.x, data.y, data.z)
    SetBlipSprite(blip, blipConfig.sprite)
    SetBlipColour(blip, blipConfig.color)
    SetBlipScale(blip, blipConfig.scale)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(data.label or blipConfig.label)
    EndTextCommandSetBlipName(blip)
    return blip
end

local function promptLabel(data)
    return locale('info.store_prompt', locale('shop.' .. data.type))
end

local function createZone(key, data)
    if active[key] then return end
    local entry = { data = data }

    local zoneOpts = {
        onEnter = function()
            if allowedInZone(data) then
                lib.showTextUI(promptLabel(data))
            end
        end,
        onExit = function()
            lib.hideTextUI()
        end,
        inside = function()
            if IsControlJustPressed(0, 38) and not editor.isOpen() and allowedInZone(data) then
                lib.hideTextUI()
                TriggerEvent(TYPE_EVENTS[data.type] or TYPE_EVENTS.clothing)
            end
        end,
    }

    if data.points and #data.points >= 3 then
        local points = {}
        for i, point in ipairs(data.points) do
            points[i] = vec3(point[1] or point.x, point[2] or point.y, point[3] or point.z)
        end
        zoneOpts.points = points
        zoneOpts.thickness = data.height or 4.0
        entry.zone = lib.zones.poly(zoneOpts)
    else
        zoneOpts.coords = vec3(data.x, data.y, data.z)
        zoneOpts.size = vec3(data.width or 4.0, data.length or 4.0, data.height or 4.0)
        zoneOpts.rotation = data.heading or 0.0
        entry.zone = lib.zones.box(zoneOpts)
    end

    if wantsBlip(data) then
        entry.blip = createBlip(data)
    end

    active[key] = entry
end

local function refreshBlips()
    for _, entry in pairs(active) do
        local want = wantsBlip(entry.data)
        if want and not entry.blip then
            entry.blip = createBlip(entry.data)
        elseif not want and entry.blip then
            RemoveBlip(entry.blip)
            entry.blip = nil
        end
    end
end

RegisterNetEvent('QBCore:Client:OnJobUpdate', refreshBlips)
RegisterNetEvent('QBCore:Client:OnGangUpdate', refreshBlips)

local function removeZone(key)
    local entry = active[key]
    if not entry then return end
    if entry.zone then entry.zone:remove() end
    if entry.blip then RemoveBlip(entry.blip) end
    active[key] = nil
end

CreateThread(function()
    for i, store in ipairs(config.stores) do
        createZone('cfg:' .. i, {
            type = store.type,
            x = store.coords.x, y = store.coords.y, z = store.coords.z,
            heading = store.coords.w,
            width = store.size and store.size.x or 4.0,
            length = store.size and store.size.y or 4.0,
            height = store.size and store.size.z or 4.0,
            blip = store.blip,
        })
    end

    for i, locker in ipairs(config.lockers or {}) do
        createZone('cfglocker:' .. i, {
            type = locker.type == 'gang_locker' and 'gang_locker' or 'job_locker',
            group_name = locker.group,
            min_grade = locker.minGrade or 0,
            label = locker.label,
            x = locker.coords.x, y = locker.coords.y, z = locker.coords.z,
            heading = locker.coords.w,
            width = locker.size and locker.size.x or 4.0,
            length = locker.size and locker.size.y or 4.0,
            height = locker.size and locker.size.z or 4.0,
            blip = locker.blip,
        })
    end

    local dbZones = lib.callback.await('qbx_appearance:server:getZones', false)
    if dbZones then
        zones = dbZones
        for _, zone in ipairs(zones) do
            createZone('db:' .. zone.id, zone)
        end
    end
end)

RegisterNetEvent('qbx_appearance:client:zoneAdded', function(zone)
    zones[#zones + 1] = zone
    createZone('db:' .. zone.id, zone)
end)

RegisterNetEvent('qbx_appearance:client:zoneRemoved', function(id)
    removeZone('db:' .. id)
    for i = #zones, 1, -1 do
        if zones[i].id == id then table.remove(zones, i) end
    end
end)

RegisterNetEvent('qbx_appearance:client:zoneUpdated', function(zone)
    removeZone('db:' .. zone.id)
    for i = 1, #zones do
        if zones[i].id == zone.id then zones[i] = zone break end
    end
    createZone('db:' .. zone.id, zone)
end)

local function laserPolygon()
    local points = {}
    local height = 4.0
    local collecting = true
    local result

    lib.showTextUI(('[E] Add point  [G] Undo  [↑/↓] Height: %.0fm  [ENTER] Confirm (%d points)  [BACKSPACE] Cancel'):format(height, #points))

    local function refreshText()
        lib.showTextUI(('[E] Add point  [G] Undo  [↑/↓] Height: %.0fm  [ENTER] Confirm (%d points)  [BACKSPACE] Cancel'):format(height, #points))
    end

    while collecting do
        Wait(0)
        local hit, _, endCoords = lib.raycast.fromCamera(511, 4, 75.0)
        local ped = cache.ped
        local origin = GetPedBoneCoords(ped, 57005, 0.2, 0.0, 0.0)

        if hit then
            DrawLine(origin.x, origin.y, origin.z, endCoords.x, endCoords.y, endCoords.z, 255, 60, 60, 255)
            DrawMarker(28, endCoords.x, endCoords.y, endCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                0.12, 0.12, 0.12, 255, 60, 60, 180, false, false, 2, false, nil, nil, false)
        end

        for i = 1, #points do
            local a = points[i]
            local b = points[i + 1] or (hit and endCoords) or points[1]
            if b then
                DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, 0, 255, 120, 255)
                DrawLine(a.x, a.y, a.z + height, b.x, b.y, b.z + height, 0, 255, 120, 255)
                DrawLine(a.x, a.y, a.z, a.x, a.y, a.z + height, 0, 255, 120, 200)
                DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, a.x, a.y, a.z + height, 0, 255, 120, 40)
                DrawPoly(b.x, b.y, b.z, b.x, b.y, b.z + height, a.x, a.y, a.z + height, 0, 255, 120, 40)
            end
        end
        if #points >= 2 then
            local first, last = points[1], points[#points]
            DrawLine(last.x, last.y, last.z, first.x, first.y, first.z, 0, 160, 255, 160)
        end

        if IsControlJustPressed(0, 38) and hit then
            points[#points + 1] = vec3(endCoords.x, endCoords.y, endCoords.z)
            refreshText()
        elseif IsControlJustPressed(0, 47) and #points > 0 then
            points[#points] = nil
            refreshText()
        elseif IsControlJustPressed(0, 172) then
            height = math.min(30.0, height + 1.0)
            refreshText()
        elseif IsControlJustPressed(0, 173) then
            height = math.max(1.0, height - 1.0)
            refreshText()
        elseif IsControlJustPressed(0, 191) then
            if #points >= 3 then
                result = { points = points, height = height }
                collecting = false
            else
                exports.qbx_core:Notify(locale('error.zone_points'), 'error')
            end
        elseif IsControlJustPressed(0, 202) then
            collecting = false
        end
    end

    lib.hideTextUI()
    return result
end

local TYPE_OPTIONS = {
    { value = 'clothing', label = 'Clothing Store' },
    { value = 'barber', label = 'Barber Shop' },
    { value = 'tattoo', label = 'Tattoo Parlor' },
    { value = 'surgeon', label = 'Plastic Surgeon' },
    { value = 'job_locker', label = 'Job Locker' },
    { value = 'gang_locker', label = 'Gang Locker' },
}

local function typeLabel(zoneType)
    for _, option in ipairs(TYPE_OPTIONS) do
        if option.value == zoneType then return option.label end
    end
    return zoneType
end

---@param existing table?
local function settingsDialog(existing)
    local input = lib.inputDialog(existing and ('Edit Zone #' .. existing.id) or 'Create Appearance Zone', {
        { type = 'input', label = 'Name', description = 'Shown in lists and as the blip label',
          default = existing and existing.label or '', max = 64 },
        { type = 'select', label = 'Type', options = TYPE_OPTIONS, required = true,
          default = existing and existing.type or 'clothing' },
        { type = 'input', label = 'Job / gang name', description = 'Lockers only (e.g. police, ballas)',
          default = existing and existing.group_name or '' },
        { type = 'number', label = 'Minimum grade', description = 'Lockers only',
          default = existing and existing.min_grade or 0, min = 0 },
        { type = 'checkbox', label = 'Show blip on the map',
          checked = existing and (existing.blip == 1 or existing.blip == true) or false },
    })
    if not input then return nil end

    local zoneType = input[2]
    local isLocker = zoneType == 'job_locker' or zoneType == 'gang_locker'
    if isLocker and (not input[3] or input[3] == '') then
        exports.qbx_core:Notify(locale('error.zone_group'), 'error')
        return nil
    end

    return {
        label = input[1] ~= '' and input[1] or nil,
        type = zoneType,
        group_name = isLocker and input[3] or nil,
        min_grade = isLocker and input[4] or 0,
        blip = input[5] == true,
    }
end

local function polygonGeometry()
    local drawn = laserPolygon()
    if not drawn then return nil end
    local cx, cy, cz = 0.0, 0.0, 0.0
    for _, point in ipairs(drawn.points) do
        cx += point.x cy += point.y cz += point.z
    end
    local count = #drawn.points
    local geometry = {
        x = cx / count, y = cy / count, z = cz / count,
        height = drawn.height,
        points = {},
    }
    for i, point in ipairs(drawn.points) do
        geometry.points[i] = { x = point.x, y = point.y, z = point.z + drawn.height / 2 }
    end
    return geometry
end

local function boxGeometry()
    local dims = lib.inputDialog('Box Zone Size', {
        { type = 'number', label = 'Width (m)', default = 4, min = 1, max = 50, required = true },
        { type = 'number', label = 'Length (m)', default = 4, min = 1, max = 50, required = true },
        { type = 'number', label = 'Height (m)', default = 4, min = 1, max = 30, required = true },
    })
    if not dims then return nil end
    local coords = GetEntityCoords(cache.ped)
    return {
        x = coords.x, y = coords.y, z = coords.z,
        heading = GetEntityHeading(cache.ped),
        width = dims[1], length = dims[2], height = dims[3],
        points = nil,
    }
end

local function mergePayload(settings, geometry)
    local payload = {}
    for key, value in pairs(settings) do payload[key] = value end
    for key, value in pairs(geometry) do payload[key] = value end
    return payload
end

local function createTool()
    local settings = settingsDialog(nil)
    if not settings then return end

    local shape = lib.inputDialog('Zone Shape', {
        { type = 'select', label = 'Shape', options = {
            { value = 'poly', label = 'Polygon — draw with laser' },
            { value = 'box', label = 'Box — at my position' },
        }, required = true, default = 'poly' },
    })
    if not shape then return end

    local geometry = shape[1] == 'poly' and polygonGeometry() or boxGeometry()
    if not geometry then return end

    local id = lib.callback.await('qbx_appearance:server:addZone', false, mergePayload(settings, geometry))
    if id then
        exports.qbx_core:Notify(locale('success.zone_created', id), 'success')
    else
        exports.qbx_core:Notify(locale('error.zone_failed'), 'error')
    end
end

local function currentGeometry(zone)
    return {
        x = zone.x, y = zone.y, z = zone.z, heading = zone.heading,
        width = zone.width, length = zone.length, height = zone.height,
        points = zone.points,
    }
end

local function currentSettings(zone)
    return {
        label = zone.label, type = zone.type, group_name = zone.group_name,
        min_grade = zone.min_grade, blip = zone.blip == 1 or zone.blip == true,
    }
end

local function pushUpdate(zone, settings, geometry)
    local ok = lib.callback.await('qbx_appearance:server:updateZone', false,
        zone.id, mergePayload(settings, geometry))
    exports.qbx_core:Notify(
        ok and locale('success.zone_updated', zone.id) or locale('error.zone_failed'),
        ok and 'success' or 'error')
end

local function manageZone(zone)
    lib.registerContext({
        id = 'qbx_appearance_zone_edit',
        title = ('#%d %s'):format(zone.id, zone.label or typeLabel(zone.type)),
        menu = 'qbx_appearance_zone_list',
        options = {
            {
                title = 'Edit settings',
                description = 'Name, type, locker group, grade, blip',
                icon = 'pen',
                onSelect = function()
                    local settings = settingsDialog(zone)
                    if settings then pushUpdate(zone, settings, currentGeometry(zone)) end
                end,
            },
            {
                title = 'Redraw as polygon',
                description = 'Draw a new shape with the laser (keeps settings)',
                icon = 'draw-polygon',
                onSelect = function()
                    local geometry = polygonGeometry()
                    if geometry then pushUpdate(zone, currentSettings(zone), geometry) end
                end,
            },
            {
                title = 'Redraw as box here',
                description = 'Box at your current position (keeps settings)',
                icon = 'cube',
                onSelect = function()
                    local geometry = boxGeometry()
                    if geometry then pushUpdate(zone, currentSettings(zone), geometry) end
                end,
            },
            {
                title = 'Teleport to zone',
                icon = 'location-arrow',
                onSelect = function()
                    SetPedCoordsKeepVehicle(cache.ped, zone.x, zone.y, zone.z)
                end,
            },
            {
                title = 'Delete',
                description = 'Remove this zone for everyone',
                icon = 'trash',
                onSelect = function()
                    local confirm = lib.alertDialog({
                        header = 'Delete zone?',
                        content = ('#%d %s will be removed for everyone.'):format(zone.id, zone.label or typeLabel(zone.type)),
                        cancel = true,
                    })
                    if confirm == 'confirm'
                        and lib.callback.await('qbx_appearance:server:deleteZone', false, zone.id) then
                        exports.qbx_core:Notify(locale('success.zone_deleted', zone.id), 'success')
                    end
                end,
            },
        },
    })
    lib.showContext('qbx_appearance_zone_edit')
end

local function manageTool()
    if #zones == 0 then
        exports.qbx_core:Notify(locale('error.zone_none'), 'error')
        return
    end
    local coords = GetEntityCoords(cache.ped)
    local options = {}
    for _, zone in ipairs(zones) do
        local distance = #(coords - vec3(zone.x, zone.y, zone.z))
        options[#options + 1] = {
            title = ('#%d %s'):format(zone.id, zone.label or typeLabel(zone.type)),
            description = ('%s · %s · %.0fm away'):format(
                typeLabel(zone.type) .. (zone.group_name and (' (' .. zone.group_name .. ')') or ''),
                zone.points and 'polygon' or 'box', distance),
            distance = distance,
            onSelect = function() manageZone(zone) end,
        }
    end
    table.sort(options, function(a, b) return a.distance < b.distance end)
    lib.registerContext({
        id = 'qbx_appearance_zone_list',
        title = ('Zones (%d)'):format(#zones),
        menu = 'qbx_appearance_zone_tool',
        options = options,
    })
    lib.showContext('qbx_appearance_zone_list')
end

RegisterNetEvent('qbx_appearance:client:zoneTool', function()
    lib.registerContext({
        id = 'qbx_appearance_zone_tool',
        title = 'Appearance Zones',
        options = {
            {
                title = 'Create zone',
                description = 'Name & settings, then draw a laser polygon or place a box',
                icon = 'plus',
                onSelect = createTool,
            },
            {
                title = 'Manage zones',
                description = 'Edit, redraw, teleport to or delete existing zones',
                icon = 'list',
                onSelect = manageTool,
            },
        },
    })
    lib.showContext('qbx_appearance_zone_tool')
end)
