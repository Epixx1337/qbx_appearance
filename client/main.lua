local config = require 'config.client'
local sharedConfig = require 'config.shared'
local defaults = require 'shared.defaults'
local convert = require 'shared.convert'
local appearance = require 'client.modules.appearance'
local camera = require 'client.modules.camera'
local editor = require 'client.modules.editor'
local state = require 'client.modules.state'
local outfits = require 'client.modules.outfits'
local studio = require 'client.modules.studio'
local bag = require 'client.modules.bag'
require 'client.modules.items'
require 'client.modules.convertworker'
require 'client.modules.zones'

local function applySaved(data)
    if not data then return end
    if type(data.model) == 'string' and joaat(data.model) ~= GetEntityModel(PlayerPedId()) then
        appearance.setPlayerModel(data.model, nil)
        state.modelName = data.model
    end
    state.apply(data)
end

RegisterNetEvent('qbx_appearance:client:loadAppearance', function(data)
    if not data then
        TriggerEvent('qbx_appearance:client:createCharacter')
        return
    end
    applySaved(data)
end)

local lastReload = 0
local function reloadSkin()
    if GetGameTimer() - lastReload < config.reloadSkinCooldown then return end
    local before = PlayerPedId()
    if IsEntityDead(before) or IsPedDeadOrDying(before, true) then return end
    local metadata = QBX.PlayerData and QBX.PlayerData.metadata
    if metadata and (metadata.isdead or metadata.inlaststand) then return end
    lastReload = GetGameTimer()
    local data = lib.callback.await('qbx_appearance:server:getAppearance', false)
    if not data then return end

    local health = GetEntityHealth(before)
    local armour = GetPedArmour(before)
    local model = type(data.model) == 'string' and data.model or state.modelName
    local ped = appearance.setPlayerModel(model, nil) or PlayerPedId()
    state.modelName = model
    state.apply(data)
    SetEntityMaxHealth(ped, 200)
    SetEntityHealth(ped, health)
    SetPedArmour(ped, armour)
end

RegisterNetEvent('qbx_appearance:client:reloadSkin', reloadSkin)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= cache.resource then return end
    CreateThread(function()
        Wait(1000)
        if not QBX.PlayerData or not QBX.PlayerData.citizenid then return end
        local data = lib.callback.await('qbx_appearance:server:getAppearance', false)
        if data then
            if type(data.model) == 'string' then state.modelName = data.model end
            state.tattoos = data.tattoos or {}
            state.hairFade = data.hair and data.hair.fade or nil
            appearance.applyDecorations(cache.ped, state.tattoos, state.hairFade)
        end
    end)
end)

local function openEditor(shopType, free, cb)
    local sections = config.shopSections[shopType] or config.shopSections.full
    editor.open({
        sections = sections,
        shopType = not free and shopType or nil,
    })
    editor.setCallback(cb)
end

RegisterNetEvent('qbx_appearance:client:openClothing', function() openEditor('clothing') end)
RegisterNetEvent('qbx_appearance:client:openBarber', function() openEditor('barber') end)
RegisterNetEvent('qbx_appearance:client:openTattoo', function() openEditor('tattoo') end)
RegisterNetEvent('qbx_appearance:client:openSurgeon', function() openEditor('surgeon') end)
RegisterNetEvent('qbx_appearance:client:openFull', function() openEditor('full', true) end)
RegisterNetEvent('qbx_appearance:client:openOutfits', function()
    editor.open({ sections = {} })
end)

RegisterNetEvent('qbx_appearance:client:createCharacter', function()
    local sections = lib.table.deepclone(config.shopSections.full)

    if sharedConfig.creation.freemodeOnly then
        sections.model = false
        local gender = QBX.PlayerData.charinfo and QBX.PlayerData.charinfo.gender
        local model = (gender == 1 or gender == 'female' or gender == 'f')
            and sharedConfig.creation.defaultFemale or sharedConfig.creation.defaultMale
        local ped = PlayerPedId()
        if joaat(model) ~= GetEntityModel(ped) then
            ped = appearance.setPlayerModel(model, nil) or ped
            state.modelName = model
        end
        local modelDefaults = defaults[model]
        if modelDefaults then
            for id, component in pairs(modelDefaults.components) do
                appearance.setComponent(ped, tonumber(id) --[[@as number]], component)
            end
        end
    end

    editor.open({
        sections = sections,
        charCreation = true,
    })
    editor.setCallback(function(result)
        if result then
            TriggerEvent('qbx_appearance:client:characterCreated', result)
        end
    end)
end)

RegisterNetEvent('qbx_appearance:client:outfitShareRequest', function(requestId, label, fromName)
    local result = lib.alertDialog({
        header = locale('info.outfit_share_header'),
        content = locale('info.outfit_share_content', label, fromName),
        centered = true,
        cancel = true,
        labels = { confirm = locale('info.accept'), cancel = locale('info.decline') },
    })
    TriggerServerEvent('qbx_appearance:server:outfitShareResponse', requestId, result == 'confirm')
end)

local usingOutfitBag = false

RegisterNetEvent('qbx_appearance:client:useOutfitBag', function(data)
    if usingOutfitBag or type(data) ~= 'table' or type(data.outfit) ~= 'table' then return end
    if data.model and data.model ~= state.modelName then
        exports.qbx_core:Notify(locale('error.item_wrong_model'), 'error')
        return
    end
    usingOutfitBag = true
    local scene = bag.startScene()
    outfits.apply(data.outfit, data.kind, data.model)
    Wait(600)
    lib.callback.await('qbx_appearance:server:consumeOutfitBag', false, data.slot)
    bag.endScene(scene)
    usingOutfitBag = false
    exports.qbx_core:Notify(locale('success.outfit_changed'), 'success')
end)

RegisterNetEvent('qbx_appearance:client:openStudio', function(target, overwrite, bodyMode)
    local models
    if target == 'male' then
        models = { 'mp_m_freemode_01' }
    elseif target == 'female' then
        models = { 'mp_f_freemode_01' }
    elseif target == 'both' then
        models = { 'mp_m_freemode_01', 'mp_f_freemode_01' }
    else
        models = { false }
    end
    CreateThread(function()
        studio.wasCancelled = false
        for _, model in ipairs(models) do
            if studio.wasCancelled then break end
            studio.start(nil, {
                model = model or nil,
                overwrite = overwrite == true,
                bodyMode = bodyMode == true,
            })
            while studio.isActive() do Wait(500) end
            Wait(1000)
        end
    end)
end)

RegisterNetEvent('qbx_appearance:client:openStudioFaces', function(section)
    studio.startFaces(section)
end)

RegisterNetEvent('qbx_appearance:client:openStudioPeds', function(overwrite)
    studio.startPeds(overwrite)
end)

RegisterNetEvent('qbx_appearance:client:openStudioManual', function()
    studio.start(nil, { manual = true })
end)

RegisterNetEvent('qbx_appearance:client:openStudioFailed', function()
    studio.reshootFailed()
end)

---@param cb fun(appearance: table|nil)
---@param opts table?
local function startPlayerCustomization(cb, opts)
    editor.open({
        sections = opts and opts.sections or config.shopSections.full,
        charCreation = opts and opts.charCreation or false,
    })
    editor.setCallback(cb)
end

exports('startPlayerCustomization', startPlayerCustomization)
exports('getPedAppearance', function() return state.snapshot() end)
exports('setPedAppearance', function(data) state.apply(data) end)
exports('setPlayerAppearance', function(data) applySaved(data) end)
exports('applyOutfit', function(outfit, kind, model) outfits.apply(outfit, kind, model) end)

exports('setPedSkin', function(ped, skin)
    if type(skin) ~= 'table' then return end
    local blob = convert.fromIllenium(skin)
    if not ped or ped == cache.ped or ped == PlayerPedId() then
        state.apply(blob)
    else
        appearance.setPedAppearance(ped, blob)
    end
end)

local function nui(name, handler)
    RegisterNUICallback(name, function(data, cb)
        local ok, result = pcall(handler, data)
        if not ok then
            lib.print.error(('nui callback %s failed: %s'):format(name, result))
            cb({ error = tostring(result) })
            return
        end
        cb(result == nil and 1 or result)
    end)
end

nui('getConfig', function()
    return {
        primaryColor = GetConvar('ox:primaryColor', 'blue'),
        primaryShade = GetConvarInt('ox:primaryShade', 8),
        locale = GetConvar('ox:locale', 'en'),
    }
end)

nui('close', function()
    if studio.isActive() then
        studio.control('stop')
    elseif bag.resolvePick then
        bag.resolvePick(nil)
    elseif editor.isOpen() then
        editor.cancel()
    end
end)

nui('camera:rotate', function(data) camera.rotate(data.dx or 0, data.dy) end)
nui('camera:zoom', function(data) camera.zoom(data.dir or 0, data.y) end)
nui('camera:preset', function(data) camera.preset(data.name) end)
nui('camera:flip', function() camera.flip() end)
nui('camera:tattooZone', function(data) camera.tattooZone(data.zone, data.back) end)

nui('editor:setModel', function(data) return editor.setModel(data.model) end)
nui('editor:setComponent', function(data) editor.setComponent(data) end)
nui('editor:setProp', function(data) editor.setProp(data) end)
nui('editor:setHeadBlend', function(data) editor.setHeadBlend(data) end)
nui('editor:setFaceFeature', function(data) editor.setFaceFeature(data) end)
nui('editor:setHeadOverlay', function(data) editor.setHeadOverlay(data) end)
nui('editor:setEyeColor', function(data) editor.setEyeColor(data.index) end)
nui('editor:setHair', function(data) editor.setHair(data) end)
nui('editor:setTattoos', function(data) editor.setTattoos(data.tattoos or {}) end)
nui('editor:previewTattoo', function(data) editor.previewTattoo(data) end)
nui('editor:undress', function(data) return editor.undress(data.what) end)
nui('editor:getTextures', function(data) return { count = editor.getTextures(data) } end)
nui('editor:save', function() editor.save() end)
nui('editor:cancel', function() editor.cancel() end)
nui('editor:spotlight', function(data) editor.setSpotlight(data.on == true) end)
nui('editor:pose', function(data) editor.setPose(tonumber(data.index) or 1) end)

nui('outfits:list', function()
    return lib.callback.await('qbx_appearance:server:getOutfits', false)
end)
nui('outfits:save', function(data)
    local kind = data.kind or 'full'
    local id = lib.callback.await('qbx_appearance:server:saveOutfit', false, {
        label = data.label, kind = kind,
        model = state.modelName, outfit = outfits.build(kind),
    })
    exports.qbx_core:Notify(
        id and locale('success.outfit_saved') or locale('error.outfit_save_failed'),
        id and 'success' or 'error')
    return { id = id }
end)
nui('outfits:apply', function(data)
    local outfit = lib.callback.await('qbx_appearance:server:getOutfit', false, data.id)
    if not outfit then return end
    local part = (data.part == 'clothing' or data.part == 'style') and data.part or nil
    outfits.apply(outfit.outfit, part or outfit.kind, outfit.model)
end)
nui('outfits:overwrite', function(data)
    local existing = lib.callback.await('qbx_appearance:server:getOutfit', false, data.id)
    if not existing then return { ok = false } end
    local ok = lib.callback.await('qbx_appearance:server:overwriteOutfit', false,
        data.id, outfits.build(existing.kind))
    return { ok = ok }
end)
nui('outfits:share', function(data)
    if sharedConfig.physicalItems.enabled then
        local ok = lib.callback.await('qbx_appearance:server:shareOutfitItem', false, data.id)
        exports.qbx_core:Notify(
            ok and locale('success.outfit_bag_given') or locale('error.outfit_share_failed'),
            ok and 'success' or 'error')
        return { mode = 'item', ok = ok == true }
    end
    local nearby = lib.getNearbyPlayers(GetEntityCoords(cache.ped), 5.0, false)
    local ids = {}
    for _, player in ipairs(nearby) do
        ids[#ids + 1] = GetPlayerServerId(player.id)
    end
    if #ids == 0 then
        exports.qbx_core:Notify(locale('error.no_nearby_players'), 'error')
        return { mode = 'players', players = {} }
    end
    local names = lib.callback.await('qbx_appearance:server:getNearbyNames', false, ids)
    return { mode = 'players', players = names or {} }
end)
nui('outfits:shareTo', function(data)
    local ok = lib.callback.await('qbx_appearance:server:shareOutfitTo', false, data.id, data.target)
    exports.qbx_core:Notify(
        ok and locale('success.outfit_share_sent') or locale('error.outfit_share_failed'),
        ok and 'success' or 'error')
    return { ok = ok == true }
end)
nui('outfits:rename', function(data)
    return { ok = lib.callback.await('qbx_appearance:server:renameOutfit', false, data.id, data.label) }
end)
nui('outfits:delete', function(data)
    return { ok = lib.callback.await('qbx_appearance:server:deleteOutfit', false, data.id) }
end)

nui('group:list', function(data)
    return lib.callback.await('qbx_appearance:server:getGroupOutfits', false, data.type)
end)
nui('group:info', function(data)
    local groupType = data.type
    local group = QBX.PlayerData[groupType]
    if not group or not group.name then return { isboss = false } end
    local grades = {}
    local groupData = groupType == 'gang' and exports.qbx_core:GetGang(group.name)
        or exports.qbx_core:GetJob(group.name)
    if groupData and groupData.grades then
        for level, grade in pairs(groupData.grades) do
            grades[#grades + 1] = { level = tonumber(level), name = grade.name }
        end
        table.sort(grades, function(a, b) return a.level < b.level end)
    end
    return { isboss = group.isboss or false, name = group.name, label = group.label, grades = grades }
end)
nui('group:save', function(data)
    local id = lib.callback.await('qbx_appearance:server:saveGroupOutfit', false, data.type, {
        label = data.label, minGrade = data.minGrade, gender = data.gender,
        model = state.modelName, outfit = outfits.build('clothing'),
    })
    exports.qbx_core:Notify(
        id and locale('success.outfit_saved') or locale('error.outfit_save_failed'),
        id and 'success' or 'error')
    return { id = id }
end)
nui('group:apply', function(data)
    local list = lib.callback.await('qbx_appearance:server:getGroupOutfits', false, data.type)
    if not list then return end
    for _, entry in ipairs(list) do
        if entry.id == data.id then
            outfits.apply(entry.outfit, 'clothing')
            break
        end
    end
end)
nui('group:delete', function(data)
    return { ok = lib.callback.await('qbx_appearance:server:deleteGroupOutfit', false, data.type, data.id) }
end)

local function openGroupOutfits(groupType)
    local list = lib.callback.await('qbx_appearance:server:getGroupOutfits', false, groupType)
    if not list or #list == 0 then
        exports.qbx_core:Notify(locale('error.no_outfits'), 'error')
        return
    end
    local options = {}
    for _, entry in ipairs(list) do
        options[#options + 1] = {
            title = entry.label,
            onSelect = function() outfits.apply(entry.outfit, 'clothing') end,
        }
    end
    lib.registerContext({ id = 'qbx_appearance_group', title = locale('menu.group_outfits'), options = options })
    lib.showContext('qbx_appearance_group')
end

RegisterNetEvent('qbx_appearance:client:openJobOutfits', function() openGroupOutfits('job') end)
RegisterNetEvent('qbx_appearance:client:openGangOutfits', function() openGroupOutfits('gang') end)

nui('studio:control', function(data) studio.control(data.action, data) end)
nui('studio:processed', function(data) studio.resolveProcessed(data.id, data.result) end)
nui('studio:editItem', function(data)
    if not data or type(data.id) ~= 'number' then return end
    local item = {
        id = data.id, isProp = data.isProp == true,
        collection = tostring(data.collection or ''), drawable = tonumber(data.drawable) or 0,
    }
    editor.cancel()
    Wait(600)
    studio.start(nil, { manual = true, work = { item } })
end)
nui('bag:pick', function(data)
    if bag.resolvePick then bag.resolvePick(data.id) end
end)
