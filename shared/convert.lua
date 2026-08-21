local convert = {}

local FACE_FEATURES = {
    'noseWidth', 'nosePeakHigh', 'nosePeakSize', 'noseBoneHigh', 'nosePeakLowering',
    'noseBoneTwist', 'eyeBrownHigh', 'eyeBrownForward', 'cheeksBoneHigh', 'cheeksBoneWidth',
    'cheeksWidth', 'eyesOpening', 'lipsThickness', 'jawBoneWidth', 'jawBoneBackSize',
    'chinBoneLowering', 'chinBoneLenght', 'chinBoneSize', 'chinHole', 'neckThickness',
}

local HEAD_OVERLAYS = {
    'blemishes', 'beard', 'eyebrows', 'ageing', 'makeUp', 'blush', 'complexion',
    'sunDamage', 'lipstick', 'moleAndFreckles', 'chestHair', 'bodyBlemishes',
}

convert.QB_COMPONENTS = {
    ['mask'] = 1, ['arms'] = 3, ['pants'] = 4, ['bag'] = 5, ['shoes'] = 6,
    ['accessory'] = 7, ['t-shirt'] = 8, ['vest'] = 9, ['decals'] = 10, ['torso2'] = 11,
}
convert.QB_PROPS = {
    ['hat'] = 0, ['glass'] = 1, ['ear'] = 2, ['watch'] = 6, ['bracelet'] = 7,
}

local function legacyComponent(drawable, texture)
    return { collection = nil, global = true, drawable = drawable or 0, texture = texture or 0 }
end

---@param skin table illenium appearance blob
---@return table
function convert.fromIllenium(skin)
    local out = {
        model = skin.model or 'mp_m_freemode_01',
        headBlend = skin.headBlend,
        eyeColor = skin.eyeColor,
        components = {},
        props = {},
        tattoos = {},
    }

    if skin.faceFeatures then
        out.faceFeatures = {}
        for i, key in ipairs(FACE_FEATURES) do
            out.faceFeatures[i] = tonumber(skin.faceFeatures[key]) or 0.0
        end
    end

    if skin.headOverlays then
        out.headOverlays = {}
        for i, key in ipairs(HEAD_OVERLAYS) do
            local overlay = skin.headOverlays[key]
            if overlay then
                out.headOverlays[tostring(i - 1)] = {
                    style = overlay.style or 0,
                    opacity = overlay.opacity or 0.0,
                    firstColor = overlay.color or 0,
                    secondColor = overlay.secondColor or 0,
                }
            end
        end
    end

    if skin.components then
        for _, component in ipairs(skin.components) do
            local id = component.component_id
            if id and id ~= 0 then
                local entry
                if component.collection and component.collectionLocal and component.collectionLocal >= 0 then
                    entry = {
                        collection = component.collection == skin.model and '' or component.collection,
                        drawable = component.collectionLocal,
                        texture = component.texture or 0,
                    }
                else
                    entry = legacyComponent(component.drawable, component.texture)
                end
                if id == 2 then
                    out.hair = entry
                else
                    out.components[tostring(id)] = entry
                end
            end
        end
    end

    if skin.hair then
        out.hair = out.hair or legacyComponent(skin.hair.style, skin.hair.texture)
        out.hair.color = skin.hair.color or 0
        out.hair.highlight = skin.hair.highlight or skin.hair.color or 0
    end

    if skin.props then
        for _, prop in ipairs(skin.props) do
            local id = prop.prop_id
            if id and prop.drawable and prop.drawable >= 0 then
                if prop.collection and prop.collectionLocal and prop.collectionLocal >= 0 then
                    out.props[tostring(id)] = {
                        collection = prop.collection,
                        drawable = prop.collectionLocal,
                        texture = prop.texture or 0,
                    }
                else
                    out.props[tostring(id)] = legacyComponent(prop.drawable, prop.texture)
                end
            end
        end
    end

    if skin.tattoos then
        local female = skin.model == 'mp_f_freemode_01'
        for zone, list in pairs(skin.tattoos) do
            for _, tattoo in ipairs(list) do
                out.tattoos[#out.tattoos + 1] = {
                    overlay = female and (tattoo.hashFemale or tattoo.hashMale) or (tattoo.hashMale or tattoo.hashFemale),
                    collection = tattoo.collection,
                    zone = tattoo.zone or zone,
                    opacity = tattoo.opacity or 1.0,
                    label = tattoo.label or tattoo.name,
                }
            end
        end
    end

    return out
end

---@param components table[]?
---@param props table[]?
---@param model string? collection names equal to the model name mean base collection
---@return table
function convert.fromIlleniumParts(components, props, model)
    local out = { components = {}, props = {} }
    if components then
        for _, component in ipairs(components) do
            local id = component.component_id
            if id then
                local entry
                if component.collection and component.collectionLocal and component.collectionLocal >= 0 then
                    entry = {
                        collection = component.collection == model and '' or component.collection,
                        drawable = component.collectionLocal,
                        texture = component.texture or 0,
                    }
                else
                    entry = legacyComponent(component.drawable, component.texture)
                end
                if id == 2 then
                    out.hair = entry
                else
                    out.components[tostring(id)] = entry
                end
            end
        end
    end
    if props then
        for _, prop in ipairs(props) do
            local id = prop.prop_id
            if id and prop.drawable and prop.drawable >= 0 then
                if prop.collection and prop.collectionLocal and prop.collectionLocal >= 0 then
                    out.props[tostring(id)] = {
                        collection = prop.collection,
                        drawable = prop.collectionLocal,
                        texture = prop.texture or 0,
                    }
                else
                    out.props[tostring(id)] = legacyComponent(prop.drawable, prop.texture)
                end
            end
        end
    end
    return out
end

---@param appearance table
---@return table
function convert.toIllenium(appearance)
    local out = {
        model = appearance.model or 'mp_m_freemode_01',
        headBlend = appearance.headBlend,
        eyeColor = appearance.eyeColor or 0,
        components = {},
        props = {},
        tattoos = {},
    }

    if appearance.faceFeatures then
        out.faceFeatures = {}
        for i, key in ipairs(FACE_FEATURES) do
            out.faceFeatures[key] = appearance.faceFeatures[i] or 0.0
        end
    end

    if appearance.headOverlays then
        out.headOverlays = {}
        for i, key in ipairs(HEAD_OVERLAYS) do
            local overlay = appearance.headOverlays[tostring(i - 1)]
            out.headOverlays[key] = overlay and {
                style = overlay.style or 0,
                opacity = overlay.opacity or 0.0,
                color = overlay.firstColor or 0,
                secondColor = overlay.secondColor or 0,
            } or { style = 0, opacity = 0.0, color = 0, secondColor = 0 }
        end
    end

    for i = 0, 11 do
        local component = i == 2 and appearance.hair or (appearance.components and appearance.components[tostring(i)])
        out.components[#out.components + 1] = {
            component_id = i,
            drawable = component and component.drawable or 0,
            texture = component and component.texture or 0,
            collection = component and component.collection or '',
            collectionLocal = component and component.drawable or 0,
        }
    end

    for _, id in ipairs({ 0, 1, 2, 6, 7 }) do
        local prop = appearance.props and appearance.props[tostring(id)]
        out.props[#out.props + 1] = {
            prop_id = id,
            drawable = prop and prop.drawable or -1,
            texture = prop and prop.texture or -1,
            collection = prop and prop.collection or '',
            collectionLocal = prop and prop.drawable or -1,
        }
    end

    if appearance.hair then
        out.hair = {
            style = appearance.hair.drawable or 0,
            texture = appearance.hair.texture or 0,
            color = appearance.hair.color or 0,
            highlight = appearance.hair.highlight or 0,
        }
    end

    if appearance.tattoos then
        for _, tattoo in ipairs(appearance.tattoos) do
            local zone = tattoo.zone or 'ZONE_TORSO'
            out.tattoos[zone] = out.tattoos[zone] or {}
            table.insert(out.tattoos[zone], {
                name = tattoo.overlay,
                label = tattoo.label or tattoo.overlay,
                hashMale = tattoo.overlay,
                hashFemale = tattoo.overlay,
                zone = zone,
                collection = tattoo.collection,
                opacity = tattoo.opacity or 1.0,
            })
        end
    end

    return out
end

---@param skin table old qb-clothing flat skin
---@param model string?
---@return table
function convert.fromQBClothing(skin, model)
    local function item(key)
        local entry = skin[key]
        if type(entry) ~= 'table' then return nil end
        return entry.item, entry.texture
    end

    local out = {
        model = model or 'mp_m_freemode_01',
        components = {},
        props = {},
        tattoos = {},
    }

    local face, face2 = item('face'), item('face2')
    local mix = type(skin.facemix) == 'table' and skin.facemix or {}
    out.headBlend = {
        shapeFirst = face or 0, shapeSecond = face2 or 0, shapeThird = 0,
        skinFirst = face or 0, skinSecond = face2 or 0, skinThird = 0,
        shapeMix = (mix.shapeMix or 5) / 10, skinMix = (mix.skinMix or 5) / 10, thirdMix = 0.0,
    }

    local hairStyle, hairTexture = item('hair')
    if hairStyle then
        out.hair = legacyComponent(hairStyle, hairTexture)
        out.hair.color = type(skin.hair) == 'table' and skin.hair.color or 0
        out.hair.highlight = out.hair.color
    end

    local overlayKeys = {
        eyebrows = 2, beard = 1, ageing = 3, makeup = 4, blush = 5, lipstick = 8, moles = 9,
    }
    out.headOverlays = {}
    for key, overlayId in pairs(overlayKeys) do
        local style, texture = item(key)
        if style and style >= 0 then
            out.headOverlays[tostring(overlayId)] = {
                style = style, opacity = 1.0, firstColor = texture or 0, secondColor = 0,
            }
        end
    end

    local eyeColor = item('eye_color')
    if eyeColor then out.eyeColor = eyeColor end

    local featureKeys = {
        nose_0 = 1, nose_1 = 2, nose_2 = 3, nose_3 = 4, nose_4 = 5, nose_5 = 6,
        eyebrown_high = 7, eyebrown_forward = 8, cheek_1 = 9, cheek_2 = 10, cheek_3 = 11,
        eye_opening = 12, lips_thickness = 13, jaw_bone_width = 14, jaw_bone_back_lenght = 15,
        chimp_bone_lowering = 16, chimp_bone_lenght = 17, chimp_bone_width = 18,
        chimp_hole = 19, neck_thikness = 20,
    }
    out.faceFeatures = {}
    for i = 1, 20 do out.faceFeatures[i] = 0.0 end
    for key, index in pairs(featureKeys) do
        local value = item(key)
        if value then out.faceFeatures[index] = value / 10 end
    end

    for key, componentId in pairs(convert.QB_COMPONENTS) do
        local drawable, texture = item(key)
        if drawable and drawable >= 0 then
            out.components[tostring(componentId)] = legacyComponent(drawable, texture)
        end
    end

    for key, propId in pairs(convert.QB_PROPS) do
        local drawable, texture = item(key)
        if drawable and drawable > 0 then
            out.props[tostring(propId)] = legacyComponent(drawable - 1, texture)
        end
    end

    return out
end

---@param outfitData table
---@return table
function convert.fromQBOutfitData(outfitData)
    local out = { components = {}, props = {} }
    for key, entry in pairs(outfitData) do
        if type(entry) == 'table' and entry.item then
            local componentId = convert.QB_COMPONENTS[key]
            local propId = convert.QB_PROPS[key]
            if componentId then
                out.components[tostring(componentId)] = legacyComponent(entry.item, entry.texture)
            elseif propId then
                if entry.item == -1 or entry.item == 0 then
                    out.props[tostring(propId)] = nil
                else
                    out.props[tostring(propId)] = legacyComponent(entry.item, entry.texture)
                end
            end
        end
    end
    return out
end

return convert
