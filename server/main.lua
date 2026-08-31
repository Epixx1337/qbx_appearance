local db = require 'server.modules.db'
local sharedConfig = require 'config.shared'
local config = require 'config.server'
local convert = require 'shared.convert'
require 'server.modules.items'
require 'server.modules.convert'
require 'server.modules.zones'

local function getCitizenId(source)
    local player = exports.qbx_core:GetPlayer(source)
    return player and player.PlayerData.citizenid or nil
end

local function validateAppearance(data)
    if type(data) ~= 'table' then return false end
    if data.model and type(data.model) ~= 'string' and type(data.model) ~= 'number' then return false end
    if data.tattoos and (type(data.tattoos) ~= 'table' or #data.tattoos > sharedConfig.tattoos.maxPerPlayer) then
        return false
    end
    for _, key in ipairs({ 'components', 'props', 'headOverlays' }) do
        if data[key] and type(data[key]) ~= 'table' then return false end
    end
    return true
end

---@param citizenid string
---@return table? skin
---@return string? model
exports('GetSkin', function(citizenid)
    local data = db.getAppearance(tostring(citizenid))
    if not data then return nil end
    return convert.toIllenium(data), tostring(data.model or 'mp_m_freemode_01')
end)

lib.callback.register('qbx_appearance:server:getAppearance', function(source)
    local citizenid = getCitizenId(source)
    if not citizenid then return nil end
    return db.getAppearance(citizenid)
end)

lib.callback.register('qbx_appearance:server:saveAppearance', function(source, appearance)
    local citizenid = getCitizenId(source)
    if not citizenid or not validateAppearance(appearance) then return false end
    db.saveAppearance(citizenid, appearance)
    return true
end)

RegisterNetEvent('qbx_appearance:server:saveAppearance', function(appearance)
    local citizenid = getCitizenId(source)
    if not citizenid or not validateAppearance(appearance) then return end
    db.saveAppearance(citizenid, appearance)
end)

lib.callback.register('qbx_appearance:server:chargeShop', function(source, shopType)
    local price = config.prices[shopType]
    if not price or price <= 0 then return true end
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false end
    if player.Functions.RemoveMoney('cash', price, ('appearance %s'):format(shopType)) then return true end
    if player.Functions.RemoveMoney('bank', price, ('appearance %s'):format(shopType)) then return true end
    exports.qbx_core:Notify(source, locale('error.cannot_afford'), 'error')
    return false
end)

lib.callback.register('qbx_appearance:server:getOutfits', function(source)
    local citizenid = getCitizenId(source)
    if not citizenid then return {} end
    return db.getOutfits(citizenid)
end)

lib.callback.register('qbx_appearance:server:getOutfit', function(source, id)
    local citizenid = getCitizenId(source)
    if not citizenid or type(id) ~= 'number' then return nil end
    return db.getOutfit(citizenid, id)
end)

lib.callback.register('qbx_appearance:server:saveOutfit', function(source, data)
    local citizenid = getCitizenId(source)
    if not citizenid or type(data) ~= 'table' then return nil end
    local label = tostring(data.label or ''):sub(1, 64)
    if label == '' or not validateAppearance(data.outfit or {}) then return nil end
    local max = sharedConfig.outfits.maxSaved
    if max > 0 and db.countOutfits(citizenid) >= max then
        exports.qbx_core:Notify(source, locale('error.outfit_limit'), 'error')
        return nil
    end
    local kind = data.kind == 'clothing' and 'clothing' or data.kind == 'style' and 'style' or 'full'
    return db.saveOutfit(citizenid, label, kind, tostring(data.model or 'mp_m_freemode_01'), data.outfit)
end)

lib.callback.register('qbx_appearance:server:overwriteOutfit', function(source, id, outfit)
    local citizenid = getCitizenId(source)
    if not citizenid or type(id) ~= 'number' or not validateAppearance(outfit or {}) then return false end
    return db.overwriteOutfit(citizenid, id, outfit)
end)

lib.callback.register('qbx_appearance:server:renameOutfit', function(source, id, label)
    local citizenid = getCitizenId(source)
    label = tostring(label or ''):sub(1, 64)
    if not citizenid or type(id) ~= 'number' or label == '' then return false end
    return db.renameOutfit(citizenid, id, label)
end)

lib.callback.register('qbx_appearance:server:deleteOutfit', function(source, id)
    local citizenid = getCitizenId(source)
    if not citizenid or type(id) ~= 'number' then return false end
    return db.deleteOutfit(citizenid, id)
end)

local function getGroup(source, groupType)
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end
    local group = groupType == 'gang' and player.PlayerData.gang or player.PlayerData.job
    if not group or not group.name or group.name == 'none' then return nil end
    return group
end

local function getCharName(source)
    local player = exports.qbx_core:GetPlayer(source)
    local info = player and player.PlayerData.charinfo
    return info and ('%s %s'):format(info.firstname, info.lastname) or GetPlayerName(source)
end

local function dedupOutfitLabel(citizenid, label)
    local existing = {}
    for _, outfit in ipairs(db.getOutfits(citizenid)) do
        existing[outfit.label] = true
    end
    if not existing[label] then return label end
    local n = 2
    while existing[('%s (%d)'):format(label, n)] do n += 1 end
    return ('%s (%d)'):format(label, n)
end

lib.callback.register('qbx_appearance:server:shareOutfitItem', function(source, id)
    if not sharedConfig.physicalItems.enabled then return false end
    local citizenid = getCitizenId(source)
    if not citizenid or type(id) ~= 'number' then return false end
    local outfit = db.getOutfit(citizenid, id)
    if not outfit then return false end
    if not exports.ox_inventory:CanCarryItem(source, 'outfit_bag', 1) then
        exports.qbx_core:Notify(source, locale('error.inventory_full'), 'error')
        return false
    end
    local success = exports.ox_inventory:AddItem(source, 'outfit_bag', 1, {
        label = locale('info.outfit_bag_label', outfit.label),
        description = locale('info.outfit_bag_desc', getCharName(source)),
        outfitLabel = outfit.label,
        kind = outfit.kind,
        model = outfit.model,
        outfit = json.encode(outfit.outfit),
    })
    return success == true
end)

exports.qbx_core:CreateUseableItem('outfit_bag', function(source, item)
    local metadata = item.metadata
    local outfit = metadata and metadata.outfit and json.decode(metadata.outfit)
    if not outfit then return end
    TriggerClientEvent('qbx_appearance:client:useOutfitBag', source, {
        outfit = outfit, kind = metadata.kind, model = metadata.model, slot = item.slot,
    })
end)

lib.callback.register('qbx_appearance:server:consumeOutfitBag', function(source, invSlot)
    if type(invSlot) ~= 'number' then return false end
    local slotItem = exports.ox_inventory:GetSlot(source, invSlot)
    if not slotItem or slotItem.name ~= 'outfit_bag' then return false end
    return exports.ox_inventory:RemoveItem(source, 'outfit_bag', 1, nil, invSlot) == true
end)

lib.callback.register('qbx_appearance:server:getNearbyNames', function(_, ids)
    if type(ids) ~= 'table' then return {} end
    local names = {}
    for _, id in ipairs(ids) do
        if type(id) == 'number' and GetPlayerName(id) then
            names[#names + 1] = { id = id, name = getCharName(id) }
        end
    end
    return names
end)

local pendingShares = {}
local shareCounter = 0

lib.callback.register('qbx_appearance:server:shareOutfitTo', function(source, id, target)
    local citizenid = getCitizenId(source)
    target = tonumber(target)
    if not citizenid or type(id) ~= 'number' or not target
        or target == source or not GetPlayerName(target) then
        return false
    end
    if #(GetEntityCoords(GetPlayerPed(source)) - GetEntityCoords(GetPlayerPed(target))) > 8.0 then
        return false
    end
    local outfit = db.getOutfit(citizenid, id)
    if not outfit then return false end

    shareCounter += 1
    pendingShares[shareCounter] = { outfit = outfit, target = target, expires = os.time() + 60 }
    TriggerClientEvent('qbx_appearance:client:outfitShareRequest', target,
        shareCounter, outfit.label, getCharName(source))
    return true
end)

RegisterNetEvent('qbx_appearance:server:outfitShareResponse', function(requestId, accepted)
    local src = source
    local pending = pendingShares[requestId]
    if not pending or pending.target ~= src or os.time() > pending.expires then return end
    pendingShares[requestId] = nil
    if not accepted then return end
    local citizenid = getCitizenId(src)
    if not citizenid then return end
    local max = sharedConfig.outfits.maxSaved
    if max > 0 and db.countOutfits(citizenid) >= max then
        exports.qbx_core:Notify(src, locale('error.outfit_limit'), 'error')
        return
    end
    local label = dedupOutfitLabel(citizenid, pending.outfit.label)
    db.saveOutfit(citizenid, label, pending.outfit.kind, pending.outfit.model, pending.outfit.outfit)
    exports.qbx_core:Notify(src, locale('success.outfit_received', label), 'success')
end)

lib.callback.register('qbx_appearance:server:getGroupOutfits', function(source, groupType)
    if groupType ~= 'job' and groupType ~= 'gang' then return {} end
    local group = getGroup(source, groupType)
    if not group then return {} end
    local outfits = db.getGroupOutfits(groupType, group.name, group.grade.level)
    if group.isboss then return outfits end
    local player = exports.qbx_core:GetPlayer(source)
    local gender = player and player.PlayerData.charinfo
        and (player.PlayerData.charinfo.gender == 1 and 'female' or 'male') or nil
    if not gender then return outfits end
    local filtered = {}
    for _, outfit in ipairs(outfits) do
        if outfit.gender == 'any' or outfit.gender == gender then
            filtered[#filtered + 1] = outfit
        end
    end
    return filtered
end)

lib.callback.register('qbx_appearance:server:saveGroupOutfit', function(source, groupType, data)
    if groupType ~= 'job' and groupType ~= 'gang' then return nil end
    local group = getGroup(source, groupType)
    if not group or not group.isboss then return nil end
    if type(data) ~= 'table' or not validateAppearance(data.outfit or {}) then return nil end
    local label = tostring(data.label or ''):sub(1, 64)
    if label == '' then return nil end
    local max = sharedConfig.outfits.maxGroupOutfits
    if max > 0 and db.countGroupOutfits(groupType, group.name) >= max then
        exports.qbx_core:Notify(source, locale('error.outfit_limit'), 'error')
        return nil
    end
    return db.saveGroupOutfit(groupType, group.name, {
        label = label,
        minGrade = math.max(0, math.floor(tonumber(data.minGrade) or 0)),
        gender = data.gender == 'female' and 'female' or data.gender == 'male' and 'male' or 'any',
        model = tostring(data.model or 'mp_m_freemode_01'),
        outfit = data.outfit,
    }, getCitizenId(source))
end)

lib.callback.register('qbx_appearance:server:deleteGroupOutfit', function(source, groupType, id)
    if groupType ~= 'job' and groupType ~= 'gang' then return false end
    local group = getGroup(source, groupType)
    if not group or not group.isboss or type(id) ~= 'number' then return false end
    return db.deleteGroupOutfit(groupType, group.name, id)
end)

local bridge = require 'server.modules.bridge'
local requestCapture = bridge.request

local function canUseStudio(source)
    return IsPlayerAceAllowed(source --[[@as string]], config.studioAce)
        or exports.qbx_core:HasPermission(source, 'admin')
end

local imageProviders = {
    qbox = {
        url = 'https://api.qbox.re/v1/file', field = 'file', responsePath = 'data.url',
        storagePath = 'data.path', deleteUrl = 'https://api.qbox.re/v1/file/%s',
    },
    fivemanage = {
        url = 'https://api.fivemanage.com/api/v3/file', field = 'file', responsePath = 'data.url',
        storagePath = 'data.id', deleteUrl = 'https://api.fivemanage.com/api/v3/file/%s',
    },
    fivemerr = { url = 'https://api.fivemerr.com/v1/media/images', field = 'file', responsePath = 'url' },
}

local function imageProvider()
    local cfg = config.imageUpload
    if not cfg or not cfg.apiKey or cfg.apiKey == '' then return end
    local provider = cfg.provider == 'custom' and cfg.custom or imageProviders[cfg.provider]
    if not provider or not provider.url or provider.url == '' then return end
    return {
        url = provider.url,
        field = provider.field or 'file',
        responsePath = provider.responsePath or 'url',
        storagePath = provider.storagePath,
        deleteUrl = provider.deleteUrl,
        apiKey = cfg.apiKey,
    }
end

lib.callback.register('qbx_appearance:server:studioWrite', function(source, bucket, filename, base64)
    if not canUseStudio(source) then return { ok = false, error = 'no permission' } end
    local result = requestCapture('qbx_appearance:internal:write', tostring(bucket), tostring(filename), base64)
    if result and result.ok and result.file and config.imageUpload and config.imageUpload.autoUpload then
        local provider = imageProvider()
        if provider then
            TriggerEvent('qbx_appearance:internal:cdnQueue', result.file, provider)
        end
    end
    return result
end)

lib.callback.register('qbx_appearance:server:cdnInfo', function(source)
    if not canUseStudio(source) then return { configured = false } end
    return {
        configured = imageProvider() ~= nil,
        auto = config.imageUpload and config.imageUpload.autoUpload == true or false,
    }
end)

lib.callback.register('qbx_appearance:server:cdnMap', function()
    local result = requestCapture('qbx_appearance:internal:cdnMap')
    return result and result.ok and result.map or {}
end)

local cdnSyncing = false

lib.callback.register('qbx_appearance:server:cdnSync', function(source, mode)
    if not canUseStudio(source) then return { ok = false, error = 'no permission' } end
    local provider = imageProvider()
    if not provider then return { ok = false, error = 'not configured' } end
    if cdnSyncing then return { ok = false, error = 'already running' } end

    local listed = requestCapture('qbx_appearance:internal:list')
    if not listed or not listed.ok then return { ok = false, error = 'list failed' } end
    local mapped = requestCapture('qbx_appearance:internal:cdnMap')
    local map = mapped and mapped.ok and mapped.map or {}

    local missing = {}
    for _, file in ipairs(listed.files) do
        if mode == 'all' or not map[file] then missing[#missing + 1] = file end
    end
    if #missing == 0 then return { ok = true, total = 0 } end

    cdnSyncing = true
    CreateThread(function()
        local failed = 0
        for i = 1, #missing do
            local result = requestCapture('qbx_appearance:internal:cdnUpload', missing[i], provider)
            if not result or not result.ok then
                failed += 1
                lib.print.warn(('cdn upload failed for %s: %s'):format(missing[i], result and result.error or 'timeout'))
            end
            if i % 100 == 0 then
                lib.print.info(('cdn sync: %d/%d uploaded'):format(i, #missing))
            end
        end
        cdnSyncing = false
        lib.print.info(('cdn sync finished: %d uploaded, %d failed'):format(#missing - failed, failed))
        if GetPlayerName(source) then
            exports.qbx_core:Notify(source,
                locale('info.cdn_sync_done', #missing - failed, failed), failed > 0 and 'error' or 'success', 8000)
        end
    end)
    return { ok = true, total = #missing }
end)

lib.callback.register('qbx_appearance:server:studioEnd', function()
    return true
end)

lib.callback.register('qbx_appearance:server:studioExisting', function(source)
    if not canUseStudio(source) then return { ok = false } end
    return requestCapture('qbx_appearance:internal:list')
end)

lib.callback.register('qbx_appearance:server:canStudio', function(source)
    return canUseStudio(source)
end)

lib.callback.register('qbx_appearance:server:studioTuning', function(source)
    if not canUseStudio(source) then return { ok = false } end
    return requestCapture('qbx_appearance:internal:getTuning')
end)

lib.callback.register('qbx_appearance:server:studioSaveTuning', function(source, tuning)
    if not canUseStudio(source) or type(tuning) ~= 'table' then return { ok = false } end
    return requestCapture('qbx_appearance:internal:saveTuning', tuning)
end)

lib.callback.register('qbx_appearance:server:getPedAccess', function(source)
    local access = { models = {}, allowAnimalPeds = false, allowHumanPeds = false }
    if #config.pedAccess == 0 then return access end

    local owned = {}
    local citizenid = getCitizenId(source)
    if citizenid then owned['citizenid:' .. citizenid] = true end
    for _, identifier in ipairs(GetPlayerIdentifiers(source --[[@as string]])) do
        owned[identifier] = true
    end

    for _, entry in ipairs(config.pedAccess) do
        for _, identifier in ipairs(entry.identifiers or {}) do
            if owned[identifier] then
                for _, model in ipairs(entry.models or {}) do
                    access.models[#access.models + 1] = model
                end
                access.allowAnimalPeds = access.allowAnimalPeds or entry.allowAnimalPeds == true
                access.allowHumanPeds = access.allowHumanPeds or entry.allowHumanPeds == true
                break
            end
        end
    end
    return access
end)

local function ownedIdentifiers(source)
    local owned = {}
    local citizenid = getCitizenId(source)
    if citizenid then owned['citizenid:' .. citizenid] = true end
    for _, identifier in ipairs(GetPlayerIdentifiers(source --[[@as string]])) do
        owned[identifier] = true
    end
    return owned
end

local function matchesClothingRule(source, player, rule, owned)
    if rule.jobs then
        local job = player.PlayerData.job
        local minGrade = job and rule.jobs[job.name]
        if minGrade and job.grade.level >= minGrade then return true end
    end
    if rule.gangs then
        local gang = player.PlayerData.gang
        local minGrade = gang and rule.gangs[gang.name]
        if minGrade and gang.grade.level >= minGrade then return true end
    end
    if rule.identifiers then
        for _, identifier in ipairs(rule.identifiers) do
            if owned[identifier] then return true end
        end
    end
    if rule.roles and config.clothingAccess.roleProvider then
        local ok, roles = pcall(config.clothingAccess.roleProvider, source)
        if ok and type(roles) == 'table' then
            local held = {}
            for _, role in ipairs(roles) do held[tostring(role)] = true end
            for _, role in ipairs(rule.roles) do
                if held[tostring(role)] then return true end
            end
        end
    end
    return false
end

lib.callback.register('qbx_appearance:server:getClothingAccess', function(source)
    local rules = config.clothingAccess and config.clothingAccess.rules or {}
    if #rules == 0 then return nil end
    local player = exports.qbx_core:GetPlayer(source)
    if not player then return nil end

    local owned = ownedIdentifiers(source)
    local blocked = { collections = {}, items = {} }

    for _, rule in ipairs(rules) do
        local matched = matchesClothingRule(source, player, rule, owned)
        local block = rule.mode == 'blacklist' and matched or rule.mode ~= 'blacklist' and not matched
        if block then
            for _, collection in ipairs(rule.collections or {}) do
                blocked.collections[collection] = true
            end
            for _, item in ipairs(rule.items or {}) do
                local key = ('%s_%d|%s|%d'):format(
                    item.prop and 'prop' or 'comp',
                    item.prop or item.component or 0,
                    item.collection or '',
                    item.drawable or 0)
                blocked.items[key] = true
            end
        end
    end

    if not next(blocked.collections) and not next(blocked.items) then return nil end
    return blocked
end)

lib.addCommand('reloadskin', {
    help = 'Re-apply your saved appearance',
}, function(source)
    TriggerClientEvent('qbx_appearance:client:reloadSkin', source)
end)

local APPEARANCE_SCOPES = {
    full = 'qbx_appearance:client:openFull',
    clothing = 'qbx_appearance:client:openClothing',
    outfits = 'qbx_appearance:client:openOutfits',
    barber = 'qbx_appearance:client:openBarber',
    tattoo = 'qbx_appearance:client:openTattoo',
    surgeon = 'qbx_appearance:client:openSurgeon',
}

local function openAppearanceCommand(source, args)
    local event = APPEARANCE_SCOPES[args.scope or 'full']
    if not event then
        exports.qbx_core:Notify(source, locale('error.appearance_scope'), 'error')
        return
    end
    local target = args.id or source
    if args.id and not GetPlayerName(args.id) then
        exports.qbx_core:Notify(source, locale('error.player_offline'), 'error')
        return
    end
    TriggerClientEvent(event, target)
end

lib.addCommand('pedmenu', {
    help = 'Open the appearance editor for yourself or a player',
    restricted = 'group.admin',
    params = {
        { name = 'scope', type = 'string', help = 'full | clothing | outfits | barber | tattoo | surgeon (default: full)', optional = true },
        { name = 'id', type = 'playerId', help = 'target player (default: yourself)', optional = true },
    },
}, openAppearanceCommand)

if config.studioCommands then
    lib.addCommand('screenshotclothing', {
        help = 'Batch-shoot clothing thumbnails (male + female by default)',
        restricted = config.studioGroup,
        params = {
            { name = 'target', type = 'string', help = 'male | female | both | current (default: both)', optional = true },
            { name = 'overwrite', type = 'string', help = 'pass "overwrite" to re-shoot existing files', optional = true },
        },
    }, function(source, args)
        local target = args.target
        if target ~= 'male' and target ~= 'female' and target ~= 'current' then
            target = 'both'
        end
        TriggerClientEvent('qbx_appearance:client:openStudio', source, target, args.overwrite == 'overwrite')
    end)

    lib.addCommand('screenshotmissing', {
        help = 'Re-shoot files still missing on disk, on a dressed body with the head visible ("none" drawables)',
        restricted = config.studioGroup,
        params = {
            { name = 'target', type = 'string', help = 'male | female | both | current (default: both)', optional = true },
        },
    }, function(source, args)
        local target = args.target
        if target ~= 'male' and target ~= 'female' and target ~= 'current' then
            target = 'both'
        end
        TriggerClientEvent('qbx_appearance:client:openStudio', source, target, false, true)
    end)

    lib.addCommand('screenshotfaces', {
        help = 'Batch-shoot character creator thumbnails (faces, skin tones, eye colors)',
        restricted = config.studioGroup,
        params = {
            { name = 'section', type = 'string', help = 'all | faces | skins | eyes (default: all)', optional = true },
        },
    }, function(source, args)
        TriggerClientEvent('qbx_appearance:client:openStudioFaces', source, args.section)
    end)

    lib.addCommand('screenshotstudio', {
        help = 'Open the screenshot studio in manual mode (full control per shot)',
        restricted = config.studioGroup,
    }, function(source)
        TriggerClientEvent('qbx_appearance:client:openStudioManual', source)
    end)

    lib.addCommand('screenshotfailed', {
        help = 'Re-shoot the items that failed in previous batch runs, manually one by one',
        restricted = config.studioGroup,
    }, function(source)
        TriggerClientEvent('qbx_appearance:client:openStudioFailed', source)
    end)

    lib.addCommand('screenshotpeds', {
        help = 'Batch-shoot ped model portraits for the model picker',
        restricted = config.studioGroup,
        params = {
            { name = 'overwrite', type = 'string', help = 'pass "overwrite" to re-shoot existing portraits', optional = true },
        },
    }, function(source, args)
        TriggerClientEvent('qbx_appearance:client:openStudioPeds', source, args.overwrite == 'overwrite')
    end)
end

local startingApartment = require '@qbx_core.config.client'.characters.startingApartment

local function migrateLegacySkin(src, citizenid)
    local ok, row = pcall(MySQL.single.await,
        'SELECT `skin`, `model` FROM `playerskins` WHERE `citizenid` = ? AND `active` = 1', { citizenid })
    if not ok or not row then return nil end
    local skin = json.decode(row.skin)
    if not skin then return nil end
    local blob = lib.callback.await('qbx_appearance:client:convertLegacySkin', src, skin, row.model)
    if type(blob) ~= 'table' then return nil end
    db.saveAppearance(citizenid, blob)
    lib.print.info(('migrated legacy skin for %s'):format(citizenid))
    return blob
end

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source --[[@as number]]
    local citizenid = getCitizenId(src)
    if not citizenid then return end
    local appearance = db.getAppearance(citizenid)

    if not appearance then
        appearance = migrateLegacySkin(src, citizenid)
    end

    if not appearance and startingApartment and GetResourceState('qbx_properties') == 'started' then
        return -- the property script opens character creation once the player is inside their first home
    end

    TriggerClientEvent('qbx_appearance:client:loadAppearance', src, appearance)
end)

lib.versionCheck('Qbox-project/qbx_appearance')
