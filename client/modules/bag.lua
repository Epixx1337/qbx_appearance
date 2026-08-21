local sharedConfig = require 'config.shared'
local outfits = require 'client.modules.outfits'

local bag = {}
local busy = false
local bagConfig = sharedConfig.clothingBag

local SCENE_DICT = 'anim@heists@money_grab@duffel'
local BAG_MODEL = `p_ld_heist_bag_s_1`
local STRAP_MODEL = `p_csh_strap_01_s`

local function playScene(scene, phase, looped)
    local pos = GetAnimInitialOffsetPosition(SCENE_DICT, phase,
        scene.pos.x, scene.pos.y, scene.pos.z, scene.pos.x, scene.pos.y, scene.pos.z, 0, 2)
    local s = NetworkCreateSynchronisedScene(pos.x, pos.y, pos.z,
        scene.rot.x, scene.rot.y, scene.rot.z, 2, false, looped, 1065353216, 0, 1.3)
    NetworkAddPedToSynchronisedScene(scene.ped, s, SCENE_DICT, phase, 1.5, -4.0, 1, 16, 1148846080, 0)
    NetworkAddEntityToSynchronisedScene(scene.bag, s, SCENE_DICT, phase .. '_bag', 4.0, -8.0, 1)
    NetworkAddEntityToSynchronisedScene(scene.strap, s, SCENE_DICT, phase .. '_strap', 4.0, -8.0, 1)
    NetworkStartSynchronisedScene(s)
end

local function startBagScene()
    local ped = cache.ped
    lib.requestAnimDict(SCENE_DICT, 5000)
    lib.requestModel(BAG_MODEL, 5000)
    lib.requestModel(STRAP_MODEL, 5000)

    local coords = GetEntityCoords(ped)
    local scene = {
        ped = ped,
        pos = coords,
        rot = GetEntityRotation(ped, 2),
        bag = CreateObject(BAG_MODEL, coords.x, coords.y, coords.z, true, true, false),
        strap = CreateObject(STRAP_MODEL, coords.x, coords.y, coords.z, true, true, false),
    }
    SetModelAsNoLongerNeeded(BAG_MODEL)
    SetModelAsNoLongerNeeded(STRAP_MODEL)
    FreezeEntityPosition(ped, true)

    playScene(scene, 'enter', false)
    Wait(math.max(0, GetAnimDuration(SCENE_DICT, 'enter') * 1000 - 200))
    playScene(scene, 'loop', true)

    return scene
end

local function endBagScene(scene)
    playScene(scene, 'exit', false)
    Wait(math.max(0, GetAnimDuration(SCENE_DICT, 'exit') * 1000 - 200))
    FreezeEntityPosition(scene.ped, false)
    ClearPedTasks(scene.ped)
    if DoesEntityExist(scene.bag) then DeleteEntity(scene.bag) end
    if DoesEntityExist(scene.strap) then DeleteEntity(scene.strap) end
    RemoveAnimDict(SCENE_DICT)
end

local function pickOutfit(list)
    if bagConfig.menu == 'oxmenu' then
        local p = promise.new()
        local options = {}
        for _, outfit in ipairs(list) do
            options[#options + 1] = {
                title = outfit.label,
                description = outfit.kind ~= 'full' and locale('info.outfit_kind_' .. outfit.kind) or nil,
                onSelect = function() p:resolve(outfit.id) end,
            }
        end
        lib.registerContext({
            id = 'qbx_appearance_bag',
            title = locale('menu.bag_title'),
            options = options,
            onExit = function() p:resolve(nil) end,
        })
        lib.showContext('qbx_appearance_bag')
        return Citizen.Await(p)
    end

    local p = promise.new()
    bag.resolvePick = function(id) p:resolve(id) end
    SendNUIMessage({ action = 'bag:open', data = { outfits = list } })
    SetNuiFocus(true, true)
    local result = Citizen.Await(p)
    bag.resolvePick = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'bag:close' })
    return result
end

bag.startScene = startBagScene
bag.endScene = endBagScene

RegisterNetEvent('qbx_appearance:client:useBag', function(invSlot)
    if busy then return end
    busy = true

    local list = lib.callback.await('qbx_appearance:server:getOutfits', false)
    if not list or #list == 0 then
        exports.qbx_core:Notify(locale('error.no_outfits'), 'error')
        busy = false
        return
    end

    local scene = startBagScene()
    local outfitId = pickOutfit(list)

    if outfitId then
        local data = lib.callback.await('qbx_appearance:server:bagEquip', false, invSlot, outfitId)
        if data then
            outfits.apply(data.outfit, data.kind, data.model)
            exports.qbx_core:Notify(locale('success.outfit_changed'), 'success')
        else
            exports.qbx_core:Notify(locale('error.bag_cooldown_short'), 'error')
        end
    end

    endBagScene(scene)
    busy = false
end)

return bag
