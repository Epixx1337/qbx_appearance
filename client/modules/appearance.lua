local config = require 'config.shared'

local appearance = {}

local FREEMODE_MODELS = {
    [`mp_m_freemode_01`] = true,
    [`mp_f_freemode_01`] = true,
}

appearance.COMPONENT_IDS = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
appearance.PROP_IDS = { 0, 1, 2, 6, 7 }

---@param model number|string
---@return boolean
function appearance.isFreemodeModel(model)
    if type(model) == 'string' then model = joaat(model) end
    return FREEMODE_MODELS[model] == true
end

---@param ped number
---@param componentId number
---@param collection string
---@param drawable number
---@return number?
function appearance.resolveDrawable(ped, componentId, collection, drawable)
    local global = GetPedDrawableGlobalIndexFromCollection(ped, componentId, collection or '', drawable)
    if global == -1 then return nil end
    return global
end

---@param ped number
---@param anchorId number
---@param collection string
---@param drawable number
---@return number?
function appearance.resolveProp(ped, anchorId, collection, drawable)
    local global = GetPedPropGlobalIndexFromCollection(ped, anchorId, collection or '', drawable)
    if global == -1 then return nil end
    return global
end

---@param ped number
---@param componentId number
---@return { collection: string, drawable: number, texture: number, [string]: any }
function appearance.getComponent(ped, componentId)
    return {
        collection = GetPedDrawableVariationCollectionName(ped, componentId) or '',
        drawable = GetPedDrawableVariationCollectionLocalIndex(ped, componentId),
        texture = GetPedTextureVariation(ped, componentId),
    }
end

---@param ped number
---@param anchorId number
---@return { collection: string, drawable: number, texture: number }?
function appearance.getProp(ped, anchorId)
    if GetPedPropIndex(ped, anchorId) == -1 then return nil end
    return {
        collection = GetPedPropCollectionName(ped, anchorId) or '',
        drawable = GetPedPropCollectionLocalIndex(ped, anchorId),
        texture = GetPedPropTextureIndex(ped, anchorId),
    }
end

---@param ped number
---@param componentId number
---@param data { collection: string?, drawable: number, texture: number?, global: boolean? }
---@return boolean applied false when the pair no longer exists and nothing was changed
function appearance.setComponent(ped, componentId, data)
    if data.global and not data.collection then
        if data.drawable >= GetNumberOfPedDrawableVariations(ped, componentId) then return false end
        SetPedComponentVariation(ped, componentId, data.drawable, data.texture or 0, 0)
        return true
    end
    local collection = data.collection or ''
    local texture = data.texture or 0
    if not IsPedCollectionComponentVariationValid(ped, componentId, collection, data.drawable, texture) then
        if IsPedCollectionComponentVariationValid(ped, componentId, collection, data.drawable, 0) then
            texture = 0
        else
            return false
        end
    end
    SetPedCollectionComponentVariation(ped, componentId, collection, data.drawable, texture, 0)
    return true
end

---@param ped number
---@param anchorId number
---@param data { collection: string?, drawable: number, texture: number?, global: boolean? }|nil nil clears the prop
---@return boolean
function appearance.setProp(ped, anchorId, data)
    if not data then
        ClearPedProp(ped, anchorId)
        return true
    end
    if data.global and not data.collection then
        if data.drawable >= GetNumberOfPedPropDrawableVariations(ped, anchorId) then return false end
        SetPedPropIndex(ped, anchorId, data.drawable, data.texture or 0, true)
        return true
    end
    local collection = data.collection or ''
    if not appearance.resolveProp(ped, anchorId, collection, data.drawable) then
        return false
    end
    SetPedCollectionPropIndex(ped, anchorId, collection, data.drawable, data.texture or 0, true)
    return true
end

---@param ped number
---@param blend table
function appearance.setHeadBlend(ped, blend)
    if not blend then return end
    SetPedHeadBlendData(ped,
        blend.shapeFirst or 0, blend.shapeSecond or 0, blend.shapeThird or 0,
        blend.skinFirst or 0, blend.skinSecond or 0, blend.skinThird or 0,
        blend.shapeMix or 0.5, blend.skinMix or 0.5, blend.thirdMix or 0.0, false)
end

---@param ped number
---@param features number[] 20 entries, -1.0..1.0
function appearance.setFaceFeatures(ped, features)
    if not features then return end
    for i = 0, 19 do
        SetPedFaceFeature(ped, i, features[i + 1] or 0.0)
    end
end

local HAIR_COLOR_OVERLAYS = { [1] = true, [2] = true, [10] = true }
local MAKEUP_COLOR_OVERLAYS = { [4] = true, [5] = true, [8] = true }

---@param ped number
---@param overlays table<string|number, { style: number, opacity: number, colorType: number?, firstColor: number?, secondColor: number? }>
function appearance.setHeadOverlays(ped, overlays)
    if not overlays then return end
    for id, overlay in pairs(overlays) do
        local overlayId = tonumber(id) --[[@as number]]
        SetPedHeadOverlay(ped, overlayId, overlay.style or 0, overlay.opacity or 0.0)
        local colorType = overlay.colorType
        if not colorType then
            colorType = HAIR_COLOR_OVERLAYS[overlayId] and 1 or (MAKEUP_COLOR_OVERLAYS[overlayId] and 2 or 0)
        end
        SetPedHeadOverlayColor(ped, overlayId, colorType, overlay.firstColor or 0, overlay.secondColor or 0)
    end
end

---@param ped number
---@param hair table
function appearance.setHair(ped, hair)
    if not hair then return end
    if hair.drawable ~= nil then
        appearance.setComponent(ped, 2, hair)
    end
    if hair.color then
        SetPedHairColor(ped, hair.color, hair.highlight or hair.color)
    end
end

---@param ped number
---@param tattoos table[]?
---@param hairFade { collection: string, overlay: string }?
function appearance.applyDecorations(ped, tattoos, hairFade)
    ClearPedDecorations(ped)
    if hairFade and hairFade.collection and hairFade.overlay then
        AddPedDecorationFromHashes(ped, joaat(hairFade.collection), joaat(hairFade.overlay))
    end
    if not tattoos then return end
    local maxLayers = config.tattoos.maxOpacityLayers
    for i = 1, #tattoos do
        local tattoo = tattoos[i]
        local layers = math.max(1, math.ceil((tattoo.opacity or 1.0) * maxLayers))
        local collection, overlay = joaat(tattoo.collection), joaat(tattoo.overlay)
        for _ = 1, layers do
            AddPedDecorationFromHashes(ped, collection, overlay)
        end
    end
end

---@param ped number
---@param known { tattoos: table[]?, hairFade: table? }? decoration state is write-only in game, caller supplies it
---@return table
function appearance.getPedAppearance(ped, known)
    local model = GetEntityModel(ped)
    local freemode = appearance.isFreemodeModel(model)
    local data = {
        model = model,
        components = {},
        props = {},
        tattoos = known and known.tattoos or {},
    }

    for _, componentId in ipairs(appearance.COMPONENT_IDS) do
        data.components[tostring(componentId)] = appearance.getComponent(ped, componentId)
    end
    for _, anchorId in ipairs(appearance.PROP_IDS) do
        data.props[tostring(anchorId)] = appearance.getProp(ped, anchorId)
    end

    if freemode then
        local shapeFirst, shapeSecond, shapeThird, skinFirst, skinSecond, skinThird,
            shapeMix, skinMix, thirdMix = Citizen.InvokeNative(0x2746BD9D88C5C5D0, ped,
                Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0),
                Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0),
                Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0),
                Citizen.PointerValueFloatInitialized(0), Citizen.PointerValueFloatInitialized(0),
                Citizen.PointerValueFloatInitialized(0))
        data.headBlend = {
            shapeFirst = shapeFirst, shapeSecond = shapeSecond, shapeThird = shapeThird,
            skinFirst = skinFirst, skinSecond = skinSecond, skinThird = skinThird,
            shapeMix = shapeMix, skinMix = skinMix, thirdMix = thirdMix,
        }
        data.faceFeatures = {}
        for i = 0, 19 do
            data.faceFeatures[i + 1] = GetPedFaceFeature(ped, i)
        end
        data.headOverlays = {}
        for i = 0, 12 do
            local _, style, colorType, firstColor, secondColor, opacity = GetPedHeadOverlayData(ped, i)
            if style ~= 255 then
                data.headOverlays[tostring(i)] = {
                    style = style, opacity = opacity, colorType = colorType,
                    firstColor = firstColor, secondColor = secondColor,
                }
            end
        end
        data.eyeColor = GetPedEyeColor(ped)
        data.hair = appearance.getComponent(ped, 2)
        data.hair.color = GetPedHairColor(ped)
        data.hair.highlight = GetPedHairHighlightColor(ped)
        if known and known.hairFade then
            data.hair.fade = known.hairFade
        end
    end

    return data
end

---@param ped number
---@param data table
---@return string[] failures human-readable list of drawables that no longer exist
function appearance.setPedAppearance(ped, data)
    local failures = {}
    local freemode = appearance.isFreemodeModel(GetEntityModel(ped))

    if freemode then
        if data.headBlend then appearance.setHeadBlend(ped, data.headBlend) end
        if data.faceFeatures then appearance.setFaceFeatures(ped, data.faceFeatures) end
        if data.headOverlays then appearance.setHeadOverlays(ped, data.headOverlays) end
        if data.eyeColor then SetPedEyeColor(ped, data.eyeColor) end
        if data.hair then appearance.setHair(ped, data.hair) end
    end

    if data.components then
        for id, component in pairs(data.components) do
            local componentId = tonumber(id) --[[@as number]]
            if componentId ~= 2 or not data.hair then
                if not appearance.setComponent(ped, componentId, component) then
                    failures[#failures + 1] = ('component %s: %s/%s'):format(id, component.collection, component.drawable)
                end
            end
        end
    end

    if data.props then
        for _, anchorId in ipairs(appearance.PROP_IDS) do
            local prop = data.props[tostring(anchorId)]
            if not appearance.setProp(ped, anchorId, prop) then
                failures[#failures + 1] = ('prop %s: %s/%s'):format(anchorId, prop.collection, prop.drawable)
            end
        end
    end

    if data.tattoos or (data.hair and data.hair.fade) then
        appearance.applyDecorations(ped, data.tattoos, data.hair and data.hair.fade)
    end

    return failures
end

---@param model string|number
---@param data table?
---@return number? ped nil when the model could not be loaded
function appearance.setPlayerModel(model, data)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelInCdimage(hash) or not IsModelAPed(hash) then return nil end
    lib.requestModel(hash, 10000)
    SetPlayerModel(cache.playerId, hash)
    SetModelAsNoLongerNeeded(hash)
    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    if appearance.isFreemodeModel(hash) then
        SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.0, false)
    end
    if data then appearance.setPedAppearance(ped, data) end
    return ped
end

---@param ped number
---@param componentId number
---@param isProp boolean?
---@return { collection: string, count: number }[]
function appearance.enumerateCollections(ped, componentId, isProp)
    local out = {}
    local total = GetPedCollectionsCount(ped)
    for i = 0, total - 1 do
        local name = GetPedCollectionName(ped, i)
        local count = isProp
            and GetNumberOfPedCollectionPropDrawableVariations(ped, componentId, name)
            or GetNumberOfPedCollectionDrawableVariations(ped, componentId, name)
        if count > 0 then
            out[#out + 1] = { collection = name, count = count }
        end
    end
    return out
end

---@param ped number
---@param componentId number
---@param entry { global: boolean?, collection: string?, drawable: number, texture: number? }
---@return { collection: string, drawable: number, texture: number }
function appearance.resolveGlobal(ped, componentId, entry)
    if not entry.global or entry.collection then
        return { collection = entry.collection or '', drawable = entry.drawable, texture = entry.texture or 0 }
    end
    local name = GetPedCollectionNameFromDrawable(ped, componentId, entry.drawable)
    local localIndex = GetPedCollectionLocalIndexFromDrawable(ped, componentId, entry.drawable)
    if name and localIndex and localIndex >= 0 then
        return { collection = name, drawable = localIndex, texture = entry.texture or 0 }
    end
    return { collection = '', drawable = 0, texture = 0 }
end

---@param ped number ped of the appearance's model
---@param data table
---@return table
function appearance.normalizeLegacy(ped, data)
    local function normalize(entry, id, isProp)
        if not entry or not entry.global or entry.collection then return entry end
        local name, localIndex
        if isProp then
            name = GetPedCollectionNameFromProp(ped, id, entry.drawable)
            localIndex = GetPedCollectionLocalIndexFromProp(ped, id, entry.drawable)
        else
            name = GetPedCollectionNameFromDrawable(ped, id, entry.drawable)
            localIndex = GetPedCollectionLocalIndexFromDrawable(ped, id, entry.drawable)
        end
        if name and localIndex and localIndex >= 0 then
            entry.collection = name
            entry.drawable = localIndex
            entry.global = nil
        end
        return entry
    end

    if data.components then
        for id, component in pairs(data.components) do
            normalize(component, tonumber(id) --[[@as number]], false)
        end
    end
    if data.hair then normalize(data.hair, 2, false) end
    if data.props then
        for id, prop in pairs(data.props) do
            normalize(prop, tonumber(id) --[[@as number]], true)
        end
    end
    return data
end

---@param ped number
---@param componentId number
---@param collection string
---@param drawable number
---@param isProp boolean?
---@return number
function appearance.getTextureCount(ped, componentId, collection, drawable, isProp)
    if isProp then
        return GetNumberOfPedCollectionPropTextureVariations(ped, componentId, collection, drawable)
    end
    return GetNumberOfPedCollectionTextureVariations(ped, componentId, collection, drawable)
end

return appearance
