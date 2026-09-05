local sharedConfig = require 'config.shared'
local appearance = require 'client.modules.appearance'
local state = require 'client.modules.state'
local defaults = require 'shared.defaults'

local slots = sharedConfig.physicalItems.slots

local function playSlotAnim(slot, off)
    local anim = off and (slot.animOff or slot.anim) or slot.anim
    if not anim then return end
    local flag = cache.vehicle and 51 or (anim.flag or 51)
    lib.playAnim(cache.ped, anim.dict, anim.clip, 3.0, 3.0, anim.dur or 1200, flag)
    local pause = (anim.dur or 1200) - 500
    Wait(pause < 500 and 500 or pause)
end

local function defaultComponent(slotKey)
    local slot = slots[slotKey]
    local model = GetEntityModel(cache.ped)
    local modelName = model == `mp_f_freemode_01` and 'mp_f_freemode_01'
        or model == `mp_m_freemode_01` and 'mp_m_freemode_01' or state.modelName
    local modelDefaults = defaults[modelName]
    if slot.component and modelDefaults then
        local d = modelDefaults.components[tostring(slot.component)]
        if d then return appearance.resolveGlobal(cache.ped, slot.component, d) end
    end
    return { collection = '', drawable = 0, texture = 0 }
end

RegisterNetEvent('qbx_appearance:client:stripSlot', function(slotKey)
    local slot = slots[slotKey]
    if not slot then return end
    local ped = cache.ped

    local current
    if slot.prop then
        current = appearance.getProp(ped, slot.prop)
    else
        current = appearance.getComponent(ped, slot.component)
        local naked = defaultComponent(slotKey)
        if current.collection == naked.collection and current.drawable == naked.drawable then
            current = nil
        end
    end
    if not current then
        exports.qbx_core:Notify(locale('error.nothing_worn'), 'error')
        return
    end

    current.model = state.modelName

    playSlotAnim(slot, true)
    local stripped
    if slot.prop then
        ClearPedProp(ped, slot.prop)
        stripped = true
    else
        stripped = appearance.setComponent(ped, slot.component, defaultComponent(slotKey))
    end
    if not stripped then
        exports.qbx_core:Notify(locale('error.item_invalid'), 'error')
        return
    end

    local ok = lib.callback.await('qbx_appearance:server:giveClothingItem', false, slotKey, current)
    if not ok then
        if slot.prop then
            appearance.setProp(ped, slot.prop, current)
        else
            appearance.setComponent(ped, slot.component, current)
        end
        return
    end
    state.persist()
    exports.qbx_core:Notify(locale('success.item_removed', slotKey), 'success')
end)

RegisterNetEvent('qbx_appearance:client:equipClothingItem', function(slotKey, invSlot, metadata)
    local slot = slots[slotKey]
    if not slot or type(metadata) ~= 'table' or not metadata.drawable then return end
    if metadata.model and metadata.model ~= state.modelName then
        exports.qbx_core:Notify(locale('error.item_wrong_model'), 'error')
        return
    end
    local ped = cache.ped
    local data = {
        collection = metadata.collection,
        drawable = metadata.drawable,
        texture = metadata.texture or 0,
    }
    if data.collection == '' and metadata.global then data.collection = nil data.global = true end

    playSlotAnim(slot, false)
    local applied
    if slot.prop then
        applied = appearance.setProp(ped, slot.prop, data)
    else
        applied = appearance.setComponent(ped, slot.component, data)
    end
    if not applied then
        exports.qbx_core:Notify(locale('error.item_invalid'), 'error')
        return
    end

    if lib.callback.await('qbx_appearance:server:consumeClothingItem', false, slotKey, invSlot) then
        state.persist()
        exports.qbx_core:Notify(locale('success.item_equipped', slotKey), 'success')
    end
end)
