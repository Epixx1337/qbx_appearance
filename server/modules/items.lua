local db = require 'server.modules.db'
local bridge = require 'server.modules.bridge'
local sharedConfig = require 'config.shared'

local bagConfig = sharedConfig.clothingBag
local bagCooldowns = {}

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

exports.qbx_core:CreateUseableItem(bagConfig.item, function(source, item)
    local player = getPlayer(source)
    if not player then return end
    local citizenid = player.PlayerData.citizenid
    local last = bagCooldowns[citizenid]
    if last and os.time() - last < bagConfig.cooldown then
        exports.qbx_core:Notify(source, locale('error.bag_cooldown', bagConfig.cooldown - (os.time() - last)), 'error')
        return
    end
    TriggerClientEvent('qbx_appearance:client:useBag', source, item.slot)
end)

lib.callback.register('qbx_appearance:server:bagEquip', function(source, invSlot, outfitId)
    local player = getPlayer(source)
    if not player or type(invSlot) ~= 'number' or type(outfitId) ~= 'number' then return nil end
    local citizenid = player.PlayerData.citizenid

    local last = bagCooldowns[citizenid]
    if last and os.time() - last < bagConfig.cooldown then return nil end

    local slotItem = exports.ox_inventory:GetSlot(source, invSlot)
    if not slotItem or slotItem.name ~= bagConfig.item then return nil end

    if bagConfig.uses > 0 then
        local metadata = slotItem.metadata or {}
        local usesLeft = metadata.uses or bagConfig.uses
        if usesLeft <= 1 then
            exports.ox_inventory:RemoveItem(source, bagConfig.item, 1, nil, invSlot)
            exports.qbx_core:Notify(source, locale('info.bag_used_up'), 'inform')
        else
            metadata.uses = usesLeft - 1
            metadata.description = locale('info.bag_uses', metadata.uses)
            exports.ox_inventory:SetMetadata(source, invSlot, metadata)
        end
    end

    bagCooldowns[citizenid] = os.time()
    return db.getOutfit(citizenid, outfitId)
end)

if sharedConfig.physicalItems.enabled then
    local slots = sharedConfig.physicalItems.slots
    local itemName = sharedConfig.physicalItems.item

    for slotKey, slot in pairs(slots) do
        lib.addCommand(slot.command, {
            help = locale('command.strip_slot', slotKey),
        }, function(source)
            TriggerClientEvent('qbx_appearance:client:stripSlot', source, slotKey)
        end)
    end

    exports.qbx_core:CreateUseableItem(itemName, function(source, item)
        local slotKey = item.metadata and item.metadata.slot
        if not slotKey or not slots[slotKey] then return end
        TriggerClientEvent('qbx_appearance:client:equipClothingItem', source, slotKey, item.slot, item.metadata)
    end)

    lib.callback.register('qbx_appearance:server:giveClothingItem', function(source, slotKey, data)
        local slot = slots[slotKey]
        if not slot or type(data) ~= 'table' or type(data.drawable) ~= 'number' then return false end

        local collection = tostring(data.collection or '')
        local drawable = math.floor(data.drawable)
        local COMP_FOLDERS = {
            [1] = 'masks', [4] = 'pants', [5] = 'bags', [6] = 'shoes', [11] = 'tops',
        }
        local PROP_FOLDERS = {
            [0] = 'hats', [1] = 'glasses', [2] = 'ears', [6] = 'watches', [7] = 'bracelets',
        }
        local folder = slot.prop and PROP_FOLDERS[slot.prop] or COMP_FOLDERS[slot.component] or 'tops'
        local model = tostring(data.model or 'mp_m_freemode_01')
        local gender = model == 'mp_f_freemode_01' and 'Female'
            or model == 'mp_m_freemode_01' and 'Male' or model
        local thumb = ('%s/%s_%s_%d'):format(
            folder,
            model,
            collection == '' and 'base' or collection,
            drawable
        ):gsub('[^%w_/-]', '_')

        local imageurl = ('nui://qbx_appearance/screenshots/clothing/%s.webp'):format(thumb)
        if sharedConfig.imageSource == 'cdn' then
            local mapped = bridge.request('qbx_appearance:internal:cdnMap')
            local url = mapped and mapped.ok and mapped.map and mapped.map[('clothing/%s.webp'):format(thumb)]
            if url then imageurl = url end
        end

        local metadata = {
            slot = slotKey,
            model = model,
            collection = collection,
            drawable = drawable,
            texture = math.floor(tonumber(data.texture) or 0),
            label = ('%s #%d (%s)'):format(slot.label, drawable, gender),
            description = locale('info.clothing_item_desc', slotKey),
            imageurl = imageurl,
        }

        if not exports.ox_inventory:CanCarryItem(source, itemName, 1) then
            exports.qbx_core:Notify(source, locale('error.inventory_full'), 'error')
            return false
        end
        local success, response = exports.ox_inventory:AddItem(source, itemName, 1, metadata)
        if not success then
            lib.print.warn(('giveClothingItem failed for %s: %s'):format(GetPlayerName(source), tostring(response)))
            exports.qbx_core:Notify(source, locale('error.inventory_full'), 'error')
            return false
        end
        local invSlot = type(response) == 'table' and (response.slot or (response[1] and response[1].slot))
        lib.print.info(('gave %s (%s) to %s in slot %s'):format(itemName, slotKey, GetPlayerName(source), tostring(invSlot)))
        return true
    end)

    lib.callback.register('qbx_appearance:server:consumeClothingItem', function(source, slotKey, invSlot)
        if not slots[slotKey] or type(invSlot) ~= 'number' then return false end
        local slotItem = exports.ox_inventory:GetSlot(source, invSlot)
        if not slotItem or slotItem.name ~= itemName then return false end
        if not slotItem.metadata or slotItem.metadata.slot ~= slotKey then return false end
        return exports.ox_inventory:RemoveItem(source, itemName, 1, nil, invSlot) == true
    end)
end
