local appearance = require 'client.modules.appearance'
local convert = require 'shared.convert'

local pedCache = {}

local function getWorkPed(model)
    if pedCache[model] and DoesEntityExist(pedCache[model]) then return pedCache[model] end
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelAPed(hash) then return nil end
    lib.requestModel(hash, 10000)
    local coords = GetEntityCoords(cache.ped)
    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z - 50.0, 0.0, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    pedCache[model] = ped
    return ped
end

local function cleanup()
    for _, ped in pairs(pedCache) do
        if DoesEntityExist(ped) then DeleteEntity(ped) end
    end
    pedCache = {}
end

lib.callback.register('qbx_appearance:client:convertLegacySkin', function(skin, model)
    local ok, blob = pcall(function()
        local converted = convert.fromIllenium(skin)
        local ped = getWorkPed(converted.model or model or 'mp_m_freemode_01')
        if ped then
            appearance.normalizeLegacy(ped, converted)
        end
        return converted
    end)
    cleanup()
    return ok and blob or nil
end)

lib.callback.register('qbx_appearance:client:convertBatch', function(format, batch)
    local results = {}
    for i = 1, #batch do
        local row = batch[i]
        local ok, converted = pcall(function()
            local blob
            if format == 'qb-clothing' then
                blob = convert.fromQBClothing(row.skin, row.model)
            else
                blob = convert.fromIllenium(row.skin)
            end
            local ped = getWorkPed(blob.model or row.model or 'mp_m_freemode_01')
            if ped then
                appearance.normalizeLegacy(ped, blob)
            end
            return blob
        end)
        results[i] = ok and converted or false
        if i % 10 == 0 then Wait(0) end
    end
    cleanup()
    return results
end)
