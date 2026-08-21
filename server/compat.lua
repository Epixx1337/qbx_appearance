local db = require 'server.modules.db'
local convert = require 'shared.convert'
local sharedConfig = require 'config.shared'

local function getCitizenId(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and player.PlayerData.citizenid or nil
end

RegisterNetEvent('illenium-appearance:server:saveAppearance', function(data)
    local citizenid = getCitizenId(source)
    if not citizenid or type(data) ~= 'table' then return end
    db.saveAppearance(citizenid, convert.fromIllenium(data))
end)

lib.callback.register('illenium-appearance:server:getAppearance', function(source)
    local citizenid = getCitizenId(source)
    if not citizenid then return nil end
    local data = db.getAppearance(citizenid)
    return data and convert.toIllenium(data) or nil
end)

lib.callback.register('illenium-appearance:server:getOutfits', function(source)
    local citizenid = getCitizenId(source)
    if not citizenid then return {} end
    local rows = db.getOutfits(citizenid)
    local out = {}
    for _, row in ipairs(rows) do
        local outfit = db.getOutfit(citizenid, row.id)
        if outfit then
            local legacy = convert.toIllenium(outfit.outfit)
            out[#out + 1] = {
                id = row.id, name = row.label, model = row.model,
                components = legacy.components, props = legacy.props,
            }
        end
    end
    return out
end)

RegisterNetEvent('illenium-appearance:server:saveOutfit', function(name, model, components, props)
    local citizenid = getCitizenId(source)
    if not citizenid or type(name) ~= 'string' then return end
    local max = sharedConfig.outfits.maxSaved
    if max > 0 and db.countOutfits(citizenid) >= max then return end
    local blob = convert.fromIlleniumParts(components, props, model)
    db.saveOutfit(citizenid, name:sub(1, 64), 'clothing', tostring(model or 'mp_m_freemode_01'), blob)
end)

RegisterNetEvent('illenium-appearance:server:updateOutfit', function(id, model, components, props)
    local citizenid = getCitizenId(source)
    if not citizenid or type(id) ~= 'number' then return end
    db.overwriteOutfit(citizenid, id, convert.fromIlleniumParts(components, props, model))
end)

RegisterNetEvent('illenium-appearance:server:deleteOutfit', function(id)
    local citizenid = getCitizenId(source)
    if not citizenid or type(id) ~= 'number' then return end
    db.deleteOutfit(citizenid, id)
end)

lib.callback.register('illenium-appearance:server:getManagementOutfits', function(source, mType, gender)
    local groupType = mType == 'Gang' and 'gang' or 'job'
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return {} end
    local group = groupType == 'gang' and player.PlayerData.gang or player.PlayerData.job
    if not group or not group.name then return {} end

    gender = type(gender) == 'string' and gender:lower() or 'male'
    local rows = db.getGroupOutfits(groupType, group.name, group.grade.level)
    local out = {}
    for _, row in ipairs(rows) do
        if row.gender == 'any' or row.gender == gender then
            local legacy = convert.toIllenium(row.outfit)
            out[#out + 1] = {
                id = row.id, name = row.label, model = row.model, gender = row.gender,
                components = legacy.components, props = legacy.props,
            }
        end
    end
    return out
end)

RegisterNetEvent('illenium-appearance:server:saveManagementOutfit', function(data)
    local src = source
    if type(data) ~= 'table' then return end
    local groupType = data.Type == 'Gang' and 'gang' or 'job'
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    local group = groupType == 'gang' and player.PlayerData.gang or player.PlayerData.job
    if not group or not group.isboss or group.name ~= data.JobName then return end

    db.saveGroupOutfit(groupType, group.name, {
        label = tostring(data.Name or 'Outfit'):sub(1, 64),
        minGrade = math.max(0, math.floor(tonumber(data.MinRank) or 0)),
        gender = data.Gender == 'female' and 'female' or 'male',
        model = tostring(data.Model or 'mp_m_freemode_01'),
        outfit = convert.fromIlleniumParts(data.Components, data.Props, data.Model),
    }, player.PlayerData.citizenid)
end)

RegisterNetEvent('illenium-appearance:server:deleteManagementOutfit', function(id)
    local src = source
    if type(id) ~= 'number' then return end
    local player = exports.qbx_core:GetPlayer(src)
    if not player then return end
    for _, groupType in ipairs({ 'job', 'gang' }) do
        local group = groupType == 'gang' and player.PlayerData.gang or player.PlayerData.job
        if group and group.name and group.isboss then
            db.deleteGroupOutfit(groupType, group.name, id)
        end
    end
end)

RegisterNetEvent('illenium-appearance:server:resetOutfitCache', function() end)
RegisterNetEvent('illenium-appearance:server:syncUniform', function() end)
RegisterNetEvent('illenium-appearance:server:endPaidSession', function() end)
