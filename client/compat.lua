local appearance = require 'client.modules.appearance'
local state = require 'client.modules.state'
local outfits = require 'client.modules.outfits'
local editor = require 'client.modules.editor'
local convert = require 'shared.convert'
local config = require 'config.client'

RegisterNetEvent('illenium-appearance:client:changeOutfit', function(data)
    if type(data) ~= 'table' then return end
    local blob = convert.fromIlleniumParts(data.components, data.props, data.model)
    local failures = state.apply(blob)
    if #failures > 0 then
        lib.print.warn('legacy outfit drawables missing:', json.encode(failures))
    end
    if not data.disableSave then
        state.persist()
    end
end)

RegisterNetEvent('illenium-appearance:client:loadJobOutfit', function(data)
    if type(data) ~= 'table' or type(data.outfitData) ~= 'table' then return end
    state.apply(convert.fromQBOutfitData(data.outfitData))
end)

RegisterNetEvent('illenium-appearance:client:openClothingShop', function(isPedMenu)
    TriggerEvent(isPedMenu == true and 'qbx_appearance:client:openFull' or 'qbx_appearance:client:openClothing')
end)

RegisterNetEvent('illenium-appearance:client:openClothingShopMenu', function(isPedMenu)
    TriggerEvent(isPedMenu == true and 'qbx_appearance:client:openFull' or 'qbx_appearance:client:openClothing')
end)

RegisterNetEvent('illenium-appearance:client:OpenBarberShop', function()
    TriggerEvent('qbx_appearance:client:openBarber')
end)

RegisterNetEvent('illenium-appearance:client:OpenTattooShop', function()
    TriggerEvent('qbx_appearance:client:openTattoo')
end)

RegisterNetEvent('illenium-appearance:client:OpenSurgeonShop', function()
    TriggerEvent('qbx_appearance:client:openFull')
end)

RegisterNetEvent('illenium-appearance:client:openOutfitMenu', function()
    TriggerEvent('qbx_appearance:client:openFull')
end)

RegisterNetEvent('illenium-appearance:client:openJobOutfitsMenu', function()
    TriggerEvent('qbx_appearance:client:openJobOutfits')
end)

RegisterNetEvent('illenium-appearance:client:reloadSkin', function()
    TriggerEvent('qbx_appearance:client:reloadSkin')
end)

RegisterNetEvent('illenium-appearance:client:ClearStuckProps', function()
    ClearAllPedProps(cache.ped)
    for _, anchorId in ipairs(appearance.PROP_IDS) do
        ClearPedProp(cache.ped, anchorId)
    end
end)

RegisterNetEvent('illenium-apearance:client:outfitsCommand', function(isJob)
    TriggerEvent(isJob and 'qbx_appearance:client:openJobOutfits' or 'qbx_appearance:client:openGangOutfits')
end)

RegisterNetEvent('qb-clothes:client:CreateFirstCharacter', function()
    TriggerEvent('qbx_appearance:client:createCharacter')
end)

RegisterNetEvent('qb-clothing:client:openMenu', function()
    TriggerEvent('qbx_appearance:client:openFull')
end)

RegisterNetEvent('qb-clothing:client:openOutfitMenu', function()
    TriggerEvent('qbx_appearance:client:openFull')
end)

RegisterNetEvent('qb-clothing:client:loadOutfit', function(data)
    if type(data) ~= 'table' then return end
    local outfitData = data.outfitData or data
    state.apply(convert.fromQBOutfitData(outfitData))
end)

local function registerLegacyExport(name, fn)
    AddEventHandler(('__cfx_export_illenium-appearance_%s'):format(name), function(setCb)
        setCb(fn)
    end)
end

local function fillGlobalIndexes(ped, legacy)
    for _, component in ipairs(legacy.components) do
        if component.collection ~= '' and component.collectionLocal >= 0 then
            local global = GetPedDrawableGlobalIndexFromCollection(
                ped, component.component_id, component.collection, component.collectionLocal)
            if global and global >= 0 then component.drawable = global end
        end
    end
    for _, prop in ipairs(legacy.props) do
        if prop.collection ~= '' and prop.collectionLocal >= 0 then
            local global = GetPedPropGlobalIndexFromCollection(
                ped, prop.prop_id, prop.collection, prop.collectionLocal)
            if global and global >= 0 then prop.drawable = global end
        end
    end
    return legacy
end

registerLegacyExport('getPedAppearance', function(ped)
    if not ped or ped == PlayerPedId() then
        return fillGlobalIndexes(PlayerPedId(), convert.toIllenium(state.snapshot()))
    end
    return fillGlobalIndexes(ped, convert.toIllenium(appearance.getPedAppearance(ped)))
end)

registerLegacyExport('getPedModel', function(ped)
    local model = GetEntityModel(ped or cache.ped)
    if model == `mp_f_freemode_01` then return 'mp_f_freemode_01' end
    if model == `mp_m_freemode_01` then return 'mp_m_freemode_01' end
    return state.modelName
end)

registerLegacyExport('setPlayerAppearance', function(data)
    if type(data) ~= 'table' then return end
    local blob = convert.fromIllenium(data)
    if type(blob.model) == 'string' and joaat(blob.model) ~= GetEntityModel(PlayerPedId()) then
        appearance.setPlayerModel(blob.model, nil)
        state.modelName = blob.model
    end
    state.apply(blob)
end)

registerLegacyExport('setPedAppearance', function(ped, data)
    if type(data) ~= 'table' then return end
    local blob = convert.fromIllenium(data)
    if not ped or ped == cache.ped then
        state.apply(blob)
    else
        appearance.setPedAppearance(ped, blob)
    end
end)

registerLegacyExport('setPedTattoos', function(ped, tattoos)
    local blob = convert.fromIllenium({ model = state.modelName, tattoos = tattoos })
    if not ped or ped == cache.ped then
        state.tattoos = blob.tattoos
        appearance.applyDecorations(cache.ped, state.tattoos, state.hairFade)
    else
        appearance.applyDecorations(ped, blob.tattoos, nil)
    end
end)

registerLegacyExport('setPedComponent', function(ped, component)
    local blob = convert.fromIlleniumParts({ component }, nil, nil)
    for id, data in pairs(blob.components) do
        appearance.setComponent(ped or cache.ped, tonumber(id) --[[@as number]], data)
    end
    if blob.hair then appearance.setComponent(ped or cache.ped, 2, blob.hair) end
end)

registerLegacyExport('setPedComponents', function(ped, components)
    local blob = convert.fromIlleniumParts(components, nil, nil)
    appearance.setPedAppearance(ped or cache.ped, blob)
end)

registerLegacyExport('setPedProp', function(ped, prop)
    local blob = convert.fromIlleniumParts(nil, { prop }, nil)
    for id, data in pairs(blob.props) do
        appearance.setProp(ped or cache.ped, tonumber(id) --[[@as number]], data)
    end
end)

registerLegacyExport('setPedProps', function(ped, props)
    local blob = convert.fromIlleniumParts(nil, props, nil)
    for id, data in pairs(blob.props) do
        appearance.setProp(ped or cache.ped, tonumber(id) --[[@as number]], data)
    end
end)

registerLegacyExport('startPlayerCustomization', function(cb, customizationConfig)
    local sections = config.shopSections.full
    if type(customizationConfig) == 'table' then
        sections = {
            model = customizationConfig.ped ~= false,
            headBlend = customizationConfig.headBlend ~= false,
            faceFeatures = customizationConfig.faceFeatures ~= false,
            headOverlays = customizationConfig.headOverlays ~= false,
            eyeColor = customizationConfig.headOverlays ~= false,
            hair = customizationConfig.headOverlays ~= false,
            components = customizationConfig.components ~= false,
            props = customizationConfig.props ~= false,
            tattoos = customizationConfig.tattoos ~= false,
        }
    end
    editor.open({ sections = sections })
    editor.setCallback(function(result)
        if cb then cb(result and convert.toIllenium(result) or nil) end
    end)
end)
