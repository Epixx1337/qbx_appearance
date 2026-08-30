local appearance = require 'client.modules.appearance'
local camera = require 'client.modules.camera'
local state = require 'client.modules.state'
local pedsConfig = require 'config.peds'
local tattooConfig = require 'config.tattoos'
local sharedConfig = require 'config.shared'
local defaults = require 'shared.defaults'

local editor = {}
local session

local HEAD_OVERLAY_IDS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 }

local POSES = {
    { label = 'Idle' },
    { label = 'Hands Up', dict = 'missminuteman_1ig_2', clip = 'handsup_base' },
    { label = 'Flex', dict = 'amb@world_human_muscle_flex@arms_at_side@idle_a', clip = 'idle_a' },
    { label = 'Sit', dict = 'anim@amb@business@bgen@bgen_no_work@', clip = 'sit_phone_phoneputdown_idle_nowork' },
    { label = 'Lean', dict = 'anim@amb@nightclub@lazlow@lo_alone@', clip = 'lowkey_idle_a' },
}

local spotlightOn = false

local function isFemale()
    return GetEntityModel(cache.ped) == `mp_f_freemode_01`
end

local function allowedModels()
    local models = { 'mp_m_freemode_01', 'mp_f_freemode_01' }
    local seen = { mp_m_freemode_01 = true, mp_f_freemode_01 = true }
    local blacklist = {}
    for _, model in ipairs(pedsConfig.blacklist) do blacklist[model] = true end

    local function add(model)
        if not blacklist[model] and not seen[model] then
            seen[model] = true
            models[#models + 1] = model
        end
    end

    local access = session.pedAccess or {}

    local globalLocked = pedsConfig.freemodeOnly
        or (sharedConfig.creation.freemodeOnly and session.charCreation)

    if not globalLocked then
        for _, model in ipairs(pedsConfig.whitelist) do add(model) end
        if pedsConfig.allowAnimalPeds then
            for _, model in ipairs(pedsConfig.animalModels) do add(model) end
        end
        if pedsConfig.allowHumanPeds and pedsConfig.models then
            for _, model in ipairs(pedsConfig.models) do add(model) end
        end
    end

    for _, model in ipairs(access.models or {}) do add(model) end
    if access.allowAnimalPeds then
        for _, model in ipairs(pedsConfig.animalModels) do add(model) end
    end
    if access.allowHumanPeds and pedsConfig.models then
        for _, model in ipairs(pedsConfig.models) do add(model) end
    end

    return models
end

local function tattooCatalog()
    local female = isFemale()
    local out = {}
    for i, tattoo in ipairs(tattooConfig.list) do
        local overlay = type(tattoo.overlay) == 'table'
            and (female and tattoo.overlay.female or tattoo.overlay.male)
            or tattoo.overlay
        if overlay and overlay ~= '' then
            out[#out + 1] = {
                index = i, overlay = overlay, collection = tattoo.collection,
                zone = tattoo.zone, label = tattoo.label,
            }
        end
    end
    return out
end

local function filterBlockedCollections(list, blocked)
    if not blocked or not next(blocked.collections) then return list end
    local out = {}
    for _, entry in ipairs(list) do
        if not blocked.collections[entry.collection] then
            out[#out + 1] = entry
        end
    end
    return out
end

local function buildCatalog()
    local ped = cache.ped
    local freemode = appearance.isFreemodeModel(GetEntityModel(ped))
    local access = session.pedAccess or {}
    local clothingAccess = session.clothingAccess
    local hasPersonalPeds = (access.models and #access.models > 0)
        or access.allowAnimalPeds or access.allowHumanPeds
    local catalog = {
        model = state.modelName,
        freemode = freemode,
        freemodeOnly = (pedsConfig.freemodeOnly
            or (session.charCreation and sharedConfig.creation.freemodeOnly))
            and not hasPersonalPeds,
        models = allowedModels(),
        components = {},
        props = {},
        poses = {},
        canStudio = lib.callback.await('qbx_appearance:server:canStudio', false) == true,
    }
    for i, pose in ipairs(POSES) do
        catalog.poses[i] = pose.label
    end

    for _, id in ipairs(appearance.COMPONENT_IDS) do
        catalog.components[tostring(id)] = filterBlockedCollections(
            appearance.enumerateCollections(ped, id, false), clothingAccess)
    end
    for _, id in ipairs(appearance.PROP_IDS) do
        catalog.props[tostring(id)] = filterBlockedCollections(
            appearance.enumerateCollections(ped, id, true), clothingAccess)
    end
    catalog.blockedItems = clothingAccess and clothingAccess.items or nil

    if freemode then
        catalog.overlays = {}
        for _, id in ipairs(HEAD_OVERLAY_IDS) do
            catalog.overlays[tostring(id)] = GetPedHeadOverlayNum(id)
        end
        catalog.hairColors = {}
        for i = 0, GetNumHairColors() - 1 do
            local r, g, b = GetPedHairRgbColor(i)
            catalog.hairColors[i + 1] = { r, g, b }
        end
        catalog.makeupColors = {}
        for i = 0, GetNumMakeupColors() - 1 do
            local r, g, b = GetPedMakeupRgbColor(i)
            catalog.makeupColors[i + 1] = { r, g, b }
        end
        catalog.eyeColors = 32
        catalog.faceShapes = 46
        catalog.skinTones = 46
        catalog.tattoos = tattooCatalog()
        catalog.hairFades = tattooConfig.hairFades[isFemale() and 'female' or 'male']
        catalog.maxTattoos = sharedConfig.tattoos.maxPerPlayer
    end

    return catalog
end

---@param opts { sections: table, charCreation: boolean?, shopType: string?, targetPed: number? }
function editor.open(opts)
    if session then return end
    session = {
        sections = opts.sections,
        charCreation = opts.charCreation or false,
        shopType = opts.shopType,
        before = state.snapshot(),
        beforeModelName = state.modelName,
        beforeTattoos = lib.table.deepclone(state.tattoos),
        beforeFade = state.hairFade,
        pedAccess = lib.callback.await('qbx_appearance:server:getPedAccess', false),
        clothingAccess = lib.callback.await('qbx_appearance:server:getClothingAccess', false),
    }

    camera.start(cache.ped)
    SendNUIMessage({ action = 'editor:open', data = {
        sections = session.sections,
        charCreation = session.charCreation,
        catalog = buildCatalog(),
        current = session.before,
        cdnMap = editor.cdnMap(),
    } })
    SetNuiFocus(true, true)
end

local cachedCdnMap

function editor.cdnMap()
    if sharedConfig.imageSource ~= 'cdn' then return nil end
    if not cachedCdnMap then
        cachedCdnMap = lib.callback.await('qbx_appearance:server:cdnMap', false) or {}
    end
    return cachedCdnMap
end

local function close()
    camera.stop()
    spotlightOn = false
    ClearPedTasks(cache.ped)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'editor:close' })
    local cb = session and session.callback
    session = nil
    return cb
end

local function redress()
    if not session or not session.undressed then return end
    local ped = cache.ped
    for _, saved in pairs(session.undressed) do
        for id, component in pairs(saved.components) do
            appearance.setComponent(ped, id, component)
        end
        for id, prop in pairs(saved.props) do
            appearance.setProp(ped, id, prop)
        end
    end
    session.undressed = nil
end

---@param cb fun(appearance: table|nil)? invoked with the final appearance or nil on cancel
function editor.setCallback(cb)
    if session then session.callback = cb end
end

function editor.isOpen()
    return session ~= nil
end

function editor.save()
    if not session then return end
    if session.shopType then
        local paid = lib.callback.await('qbx_appearance:server:chargeShop', false, session.shopType)
        if not paid then return end
    end
    redress()
    local snapshot = state.persist()
    local cb = close()
    if cb then cb(snapshot) end
    exports.qbx_core:Notify(locale('success.appearance_saved'), 'success')
end

function editor.cancel()
    if not session then return end
    local before, tattoos, fade = session.before, session.beforeTattoos, session.beforeFade
    local beforeModelName = session.beforeModelName
    local cb = close()
    state.tattoos = tattoos
    state.hairFade = fade
    if joaat(beforeModelName) ~= GetEntityModel(PlayerPedId()) then
        appearance.setPlayerModel(beforeModelName, nil)
        state.modelName = beforeModelName
    end
    state.apply(before)
    if cb then cb(nil) end
end

function editor.setModel(model)
    if not session then return nil end
    local snapshot = state.snapshot()
    local ped = appearance.setPlayerModel(model, nil)
    if not ped then return nil end
    state.modelName = model
    state.tattoos = {}
    state.hairFade = nil

    local modelDefaults = defaults[model]
    if modelDefaults then
        for id, component in pairs(modelDefaults.components) do
            appearance.setComponent(ped, tonumber(id) --[[@as number]], component)
        end
    elseif appearance.isFreemodeModel(joaat(model)) then
        state.apply({ components = snapshot.components })
    end
    camera.start(ped)
    return buildCatalog()
end

function editor.setComponent(data)
    if not session then return end
    appearance.setComponent(cache.ped, data.id, data)
end

function editor.setProp(data)
    if not session then return end
    if data.clear then
        appearance.setProp(cache.ped, data.id, nil)
    else
        appearance.setProp(cache.ped, data.id, data)
    end
end

function editor.setHeadBlend(blend)
    if not session then return end
    appearance.setHeadBlend(cache.ped, blend)
end

function editor.setFaceFeature(data)
    if not session then return end
    SetPedFaceFeature(cache.ped, data.index, data.value + 0.0)
end

function editor.setHeadOverlay(data)
    if not session then return end
    appearance.setHeadOverlays(cache.ped, { [tostring(data.id)] = data })
end

function editor.setEyeColor(index)
    if not session then return end
    SetPedEyeColor(cache.ped, index)
end

function editor.setHair(data)
    if not session then return end
    appearance.setHair(cache.ped, data)
    if data.fade ~= nil then
        state.hairFade = data.fade ~= false and data.fade or nil
        appearance.applyDecorations(cache.ped, state.tattoos, state.hairFade)
    end
end

function editor.setTattoos(tattoos)
    if not session then return end
    if #tattoos > sharedConfig.tattoos.maxPerPlayer then return end
    state.tattoos = tattoos
    appearance.applyDecorations(cache.ped, state.tattoos, state.hairFade)
end

function editor.previewTattoo(tattoo)
    if not session then return end
    local preview = lib.table.deepclone(state.tattoos)
    preview[#preview + 1] = tattoo
    appearance.applyDecorations(cache.ped, preview, state.hairFade)
end

local UNDRESS_SLOTS = {
    torso = { components = { 3, 8, 9, 10, 11 } },
    pants = { components = { 4 } },
    shoes = { components = { 6 } },
    accessories = { components = { 1, 5, 7 }, props = appearance.PROP_IDS },
}

local UNDRESS_ANIMS = {
    torso = { dict = 'clothingtie', clip = 'try_tie_negative_a', dur = 1200 },
    pants = { dict = 're@construction', clip = 'out_of_breath', dur = 1300 },
    shoes = { dict = 'random@domestic', clip = 'pickup_low', dur = 1200, flag = 0 },
    accessories = { dict = 'clothingtie', clip = 'try_tie_positive_a', dur = 1500 },
}

local function playUndressAnim(what)
    local anim = UNDRESS_ANIMS[what]
    if not anim then return end
    lib.playAnim(cache.ped, anim.dict, anim.clip, 3.0, 3.0, anim.dur, anim.flag or 51)
    local pause = anim.dur - 500
    Wait(pause < 500 and 500 or pause)
end

---@return { active: boolean }?
function editor.undress(what)
    if not session then return end
    local slots = UNDRESS_SLOTS[what]
    if not slots then return end
    local ped = cache.ped
    session.undressed = session.undressed or {}
    playUndressAnim(what)
    if not session then return end

    local saved = session.undressed[what]
    if saved then
        for id, component in pairs(saved.components) do
            appearance.setComponent(ped, id, component)
        end
        for id, prop in pairs(saved.props) do
            appearance.setProp(ped, id, prop)
        end
        session.undressed[what] = nil
        return { active = false }
    end

    local model = GetEntityModel(ped)
    local modelName = model == `mp_f_freemode_01` and 'mp_f_freemode_01'
        or model == `mp_m_freemode_01` and 'mp_m_freemode_01' or state.modelName
    local modelDefaults = defaults[modelName]
    local naked = modelDefaults and modelDefaults.components or {}
    saved = { components = {}, props = {} }
    for _, id in ipairs(slots.components) do
        saved.components[id] = appearance.getComponent(ped, id)
        appearance.setComponent(ped, id, naked[tostring(id)] or { collection = '', drawable = 0, texture = 0 })
    end
    for _, id in ipairs(slots.props or {}) do
        saved.props[id] = appearance.getProp(ped, id)
        ClearPedProp(ped, id)
    end
    session.undressed[what] = saved
    return { active = true }
end


function editor.getTextures(data)
    if not session then return 0 end
    return appearance.getTextureCount(cache.ped, data.id, data.collection, data.drawable, data.isProp)
end

---@param enabled boolean
function editor.setSpotlight(enabled)
    if enabled == spotlightOn then return end
    spotlightOn = enabled
    if not enabled then return end
    CreateThread(function()
        while spotlightOn and session do
            local ped = cache.ped
            local coords = GetEntityCoords(ped)
            local forward = GetEntityForwardVector(ped)
            local origin = coords + forward * 2.5 + vec3(0.0, 0.0, 2.6)
            local dir = (coords + vec3(0.0, 0.0, 0.55)) - origin
            dir = dir / #dir
            DrawSpotLight(origin.x, origin.y, origin.z, dir.x, dir.y, dir.z,
                255, 255, 255, 14.0, 1.4, 0.0, 13.0, 1.0)
            Wait(0)
        end
        spotlightOn = false
    end)
end

---@param index number
function editor.setPose(index)
    if not session then return end
    local pose = POSES[index]
    if not pose or not pose.dict then
        ClearPedTasks(cache.ped)
        return
    end
    lib.requestAnimDict(pose.dict, 5000)
    TaskPlayAnim(cache.ped, pose.dict, pose.clip, 4.0, 4.0, -1, 1, 0.0, false, false, false)
    RemoveAnimDict(pose.dict)
end

return editor
