local appearance = require 'client.modules.appearance'
local backdrop = require 'client.modules.backdrop'
local state = require 'client.modules.state'
local pedsConfig = require 'config.peds'
local sharedConfig = require 'config.shared'
local defaults = require 'shared.defaults'

local studio = {}

local STUDIO_POS = vec3(-1894.5, -3352.5, 180.0)
local STUDIO_HEADING = 180.0

local FRAMING = {
    components = {
        [0] = { bone = 31086, dist = 0.7, fov = 20.0 },
        [1] = { bone = 31086, dist = 0.8, fov = 22.0 },
        [2] = { bone = 31086, dist = 0.8, fov = 24.0 },
        [3] = { bone = 24818, dist = 2.1, fov = 32.0, zOff = -0.15 },
        [4] = { bone = 11816, dist = 2.0, fov = 34.0, zOff = -0.3 },
        [5] = { bone = 24818, dist = 1.8, fov = 34.0 },
        [6] = { bone = 14201, bone2 = 52301, dist = 1.3, fov = 26.0 },
        [7] = { bone = 24818, dist = 1.2, fov = 26.0 },
        [8] = { bone = 24818, dist = 1.4, fov = 28.0 },
        [9] = { bone = 24818, dist = 1.6, fov = 30.0 },
        [10] = { bone = 24818, dist = 1.6, fov = 30.0 },
        [11] = { bone = 24818, dist = 1.7, fov = 32.0 },
    },
    props = {
        [0] = { bone = 31086, dist = 0.8, fov = 22.0, zOff = 0.08 },
        [1] = { bone = 31086, dist = 0.6, fov = 18.0 },
        [2] = { bone = 31086, dist = 0.6, fov = 18.0 },
        [6] = { bone = 18905, altBone = 57005, dist = 0.5, fov = 16.0 },
        [7] = { bone = 57005, altBone = 18905, dist = 0.5, fov = 16.0 },
    },
}

local session
local takeShot

studio.failedLog = {}

local function failKey(model, item)
    return ('%s|%s|%d|%s|%d'):format(model, item.isProp and 'p' or 'c', item.id,
        item.collection, item.drawable)
end

local function swait(ms)
    Wait(math.floor(ms / (session and session.speed or 1.0)))
end

local function initHeadBlend(ped, hash)
    if not appearance.isFreemodeModel(hash) then return end
    SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.0, false)
    local deadline = GetGameTimer() + 3000
    while not HasPedHeadBlendFinished(ped) and GetGameTimer() < deadline do
        Wait(50)
    end
end

local IDLE_POSE = { dict = 'move_m@generic', clip = 'idle' }

local function holdStill(ped)
    ClearPedTasksImmediately(ped)
    if not IsPedHuman(ped) then return end
    lib.requestAnimDict(IDLE_POSE.dict, 5000)
    TaskPlayAnim(ped, IDLE_POSE.dict, IDLE_POSE.clip, 8.0, 8.0, -1, 1, 0.0, false, false, false)
    Wait(300)
    SetEntityAnimSpeed(ped, IDLE_POSE.dict, IDLE_POSE.clip, 0.0)
end

local function statuePed(ped)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanPlayAmbientAnims(ped, false)
    SetPedCanPlayAmbientBaseAnims(ped, false)
    pcall(function() SetPedCanPlayAmbientIdles(ped, false, true) end)
    holdStill(ped)
end

local function unstatuePed(ped)
    if not DoesEntityExist(ped) then return end
    ClearPedTasksImmediately(ped)
    pcall(function() SetPedCanPlayAmbientIdles(ped, true, false) end)
    SetPedCanPlayAmbientBaseAnims(ped, true)
    SetPedCanPlayAmbientAnims(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetEntityInvincible(ped, false)
    FreezeEntityPosition(ped, false)
end

local function tuningKey(item)
    return (item.isProp and 'prop_' or 'comp_') .. item.id
end

local function collectionKey(item)
    return ('%s|%s'):format(tuningKey(item), item.collection == '' and 'base' or item.collection)
end

local function itemTuning(item)
    if not session.tuning then return nil end
    return session.tuning[collectionKey(item)] or session.tuning[tuningKey(item)]
end

---@param item table
---@param clipExtra number? temporary extra distance from clip auto-retries
---@param altSide boolean? aim at altBone (wrist props that render on the other arm)
local function frameItem(item, clipExtra, altSide)
    local framing = (item.isProp and FRAMING.props or FRAMING.components)[item.id]
        or { bone = 24818, dist = 1.8, fov = 32.0 }
    if altSide and framing.altBone then
        framing = { bone = framing.altBone, dist = framing.dist, fov = framing.fov, zOff = framing.zOff }
    end
    local ped = session.ped
    local nudge = session.nudge
    local tuning = itemTuning(item)
    local tx = (tuning and tuning.x or 0.0) + nudge.x
    local ty = (tuning and tuning.y or 0.0) + nudge.y
    local tz = (tuning and tuning.z or 0.0) + nudge.z
    local tdist = (tuning and tuning.dist or 0.0) + nudge.dist + (clipExtra or 0.0)
    local tfov = (tuning and tuning.fov or 0.0) + nudge.fov

    local focus = GetPedBoneCoords(ped, framing.bone, 0.0, 0.0, 0.0)
    if framing.bone2 then
        focus = (focus + GetPedBoneCoords(ped, framing.bone2, 0.0, 0.0, 0.0)) / 2
    end
    focus += vec3(0.0, 0.0, framing.zOff or 0.0)
    focus += vec3(tx, ty, tz)
    local behind = item.isProp == false and item.id == 5
    local forward = (session.baseForward or GetEntityForwardVector(ped)) * (behind and -1.0 or 1.0)
    local hero = math.rad(sharedConfig.studio.heroAngle or 0.0)
    local dir = vec3(
        forward.x * math.cos(hero) - forward.y * math.sin(hero),
        forward.x * math.sin(hero) + forward.y * math.cos(hero),
        0.0
    )
    local dist = framing.dist + tdist
    local camPos = focus + dir * dist
        + vec3(0.0, 0.0, dist * (sharedConfig.studio.cameraHeight or 0.0))
    local fov = framing.fov + tfov
    SetCamCoord(session.cam, camPos.x, camPos.y, camPos.z)
    PointCamAtCoord(session.cam, focus.x, focus.y, focus.z)
    SetCamFov(session.cam, fov)
    backdrop.place(focus, camPos, fov)
end

local COMP_FOLDERS = {
    [1] = 'masks', [2] = 'hair', [3] = 'arms', [4] = 'pants', [5] = 'bags',
    [6] = 'shoes', [7] = 'accessories', [8] = 'undershirts', [9] = 'armor',
    [10] = 'decals', [11] = 'tops',
}
local PROP_FOLDERS = {
    [0] = 'hats', [1] = 'glasses', [2] = 'ears', [6] = 'watches', [7] = 'bracelets',
}

local function itemBucket(item)
    local folder = item.isProp and PROP_FOLDERS[item.id] or COMP_FOLDERS[item.id]
    return 'clothing/' .. (folder or 'tops')
end

local function fileName(item)
    local collection = item.collection == '' and 'base' or item.collection
    return ('%s_%s_%d'):format(session.modelName, collection, item.drawable):gsub('[^%w_-]', '_')
end

local function buildWorkList(slots)
    local ped = session.ped
    local work = {}
    for _, slot in ipairs(slots) do
        local collections = appearance.enumerateCollections(ped, slot.id, slot.isProp)
        local seen = {}
        for _, entry in ipairs(collections) do
            for drawable = 0, entry.count - 1 do
                local global = slot.isProp
                    and GetPedPropGlobalIndexFromCollection(ped, slot.id, entry.collection, drawable)
                    or GetPedDrawableGlobalIndexFromCollection(ped, slot.id, entry.collection, drawable)
                if not global or global < 0 or not seen[global] then
                    if global and global >= 0 then seen[global] = true end
                    work[#work + 1] = {
                        id = slot.id, isProp = slot.isProp or false,
                        collection = entry.collection, drawable = drawable,
                    }
                end
            end
        end
    end
    return work
end

local function sectionsFromWork(work)
    local sections = {}
    local currentKey
    local seen
    for i, item in ipairs(work) do
        local folder = (item.isProp and PROP_FOLDERS[item.id] or COMP_FOLDERS[item.id]) or tostring(item.id)
        if folder ~= currentKey then
            currentKey = folder
            seen = {}
            sections[#sections + 1] = { key = folder, start = i, count = 0, slot = tuningKey(item), collections = {} }
        end
        local section = sections[#sections]
        section.count += 1
        local collection = item.collection == '' and 'base' or item.collection
        if not seen[collection] then
            seen[collection] = true
            section.collections[#section.collections + 1] = collection
        end
    end
    return sections
end

local slot0HideAllowed

local function probeHeadHide(ped)
    if slot0HideAllowed ~= nil then return slot0HideAllowed end
    local prevDrawable = GetPedDrawableVariation(ped, 0)
    SetPedComponentVariation(ped, 0, -1, 0, 0)
    slot0HideAllowed = GetPedDrawableVariation(ped, 0) == -1
    SetPedComponentVariation(ped, 0, prevDrawable >= 0 and prevDrawable or 0, 0, 0)
    if slot0HideAllowed then
        lib.print.info('face hide ENABLED — clothing shots will be captured without the head')
    else
        lib.print.warn('face hide DISABLED: set the CLIENT convar `allowEmptyHeadDrawable true`')
        lib.print.warn('  in the F8 console, or add `+set allowEmptyHeadDrawable true` to')
        lib.print.warn('  %localappdata%\\FiveM\\FiveM.app\\commandline.txt (setr in server.cfg does NOT work)')
    end
    return slot0HideAllowed
end

local EMPTY_AT_ZERO = { [1] = true, [5] = true, [9] = true }
---@param keepComponent number? component slot to leave untouched
local function hideAll(keepComponent)
    local ped = session.ped
    local useNone = keepComponent == nil
    for _, componentId in ipairs(appearance.COMPONENT_IDS) do
        if componentId ~= 0 and componentId ~= keepComponent then
            SetPedComponentVariation(ped, componentId,
                (useNone and EMPTY_AT_ZERO[componentId]) and 0 or -1, 0, 0)
        end
    end
    for _, anchorId in ipairs(appearance.PROP_IDS) do
        ClearPedProp(ped, anchorId)
    end
    if keepComponent ~= 0 and probeHeadHide(ped) then
        SetPedComponentVariation(ped, 0, -1, 0, 0)
    end
end


---@param keepComponent number?
local function dressBody(keepComponent)
    local ped = session.ped
    for _, componentId in ipairs(appearance.COMPONENT_IDS) do
        if componentId ~= 0 and componentId ~= keepComponent then
            SetPedComponentVariation(ped, componentId, -1, 0, 0)
        end
    end
    local modelDefaults = defaults[session.modelName]
    if modelDefaults then
        for id, component in pairs(modelDefaults.components) do
            local componentId = tonumber(id) --[[@as number]]
            if componentId ~= keepComponent then
                appearance.setComponent(ped, componentId, component)
            end
        end
    end
    for _, anchorId in ipairs(appearance.PROP_IDS) do
        ClearPedProp(ped, anchorId)
    end
end

local PRELOAD_TIMEOUT = 5000

local function applyItem(item)
    local ped = session.ped
    session.hairShot = not item.isProp and item.id == 2 or nil

    if session.poseActive then
        session.poseActive = false
        holdStill(ped)
    end

    if item.isProp then
        if session.bodyMode then dressBody(nil) else hideAll(nil) end
        SetPedCollectionPreloadPropData(ped, item.id, item.collection, item.drawable, 0)
        local deadline = GetGameTimer() + PRELOAD_TIMEOUT
        while not HasPedPreloadPropDataFinished(ped) and GetGameTimer() < deadline do
            Wait(25)
        end
        SetPedCollectionPropIndex(ped, item.id, item.collection, item.drawable, 0, true)
        ReleasePedPreloadPropData(ped)

        local pose = sharedConfig.studio.propPoses and sharedConfig.studio.propPoses[item.id]
        if pose then
            lib.requestAnimDict(pose.dict, 5000)
            TaskPlayAnim(ped, pose.dict, pose.clip, 8.0, -8.0, -1, 49, 0.0, false, false, false)
            Wait(pose.settle or 600)
            session.poseActive = true
        end
    else
        SetPedCollectionPreloadVariationData(ped, item.id, item.collection, item.drawable, 0)
        local deadline = GetGameTimer() + PRELOAD_TIMEOUT
        while not HasPedPreloadVariationDataFinished(ped) and GetGameTimer() < deadline do
            Wait(25)
        end
        appearance.setComponent(ped, item.id, { collection = item.collection, drawable = item.drawable })
        ReleasePedPreloadVariationData(ped)
        if session.bodyMode then dressBody(item.id) else hideAll(item.id) end
        if item.id == 10 then
            local base = sharedConfig.studio.decalBase[session.modelName]
            if base then
                for _, entry in ipairs(base) do
                    appearance.setComponent(ped, entry.component,
                        { collection = entry.collection, drawable = entry.drawable, texture = entry.texture })
                end
            end
        end
    end
end

local function rehideHead()
    if not slot0HideAllowed then return end
    SetPedComponentVariation(session.ped, 0, -1, 0, 0)
    Wait(0)
    if GetPedDrawableVariation(session.ped, 0) ~= -1 and not session.warnedClobber then
        session.warnedClobber = true
        lib.print.warn('slot 0 (face) hide is being clobbered by the engine on this ped — captures may include the head')
    end
end

local function hairPalette()
    local colors = {}
    for i = 0, GetNumHairColors() - 1 do
        local r, g, b = GetPedHairRgbColor(i)
        colors[i + 1] = { r, g, b }
    end
    return colors
end

local function syncOpen()
    SendNUIMessage({ action = 'studio:open', data = {
        total = #session.work, manual = session.manual, headHide = session.headHide,
        sections = sectionsFromWork(session.work), tuning = session.tuning,
        cdn = session.cdn, model = session.modelName,
        hairColors = sharedConfig.studio.recolorHair and hairPalette() or {},
        hairColor = session.hairColorOverride or sharedConfig.studio.hairColor,
    } })
end

local pendingProcess = {}
local processCounter = 0

function studio.resolveProcessed(id, result)
    local p = pendingProcess[id]
    if not p then return end
    pendingProcess[id] = nil
    p:resolve(result or { ok = false, error = 'no result' })
end

local function captureRaw()
    local p = promise.new()
    local settled = false
    local function settle(value)
        if settled then return end
        settled = true
        p:resolve(value)
    end
    exports.screencapture:requestScreenshot({ encoding = 'png' }, settle)
    SetTimeout(10000, function() settle(nil) end)
    return Citizen.Await(p)
end

local MATTE_PARTNER = {
    green = 'magenta', magenta = 'green',
    blue = 'orange', orange = 'blue',
}

---@param bucket 'clothing'|'faces'|'peds'
---@param filename string
---@return table result { ok, clipped?, visible, error? }
function takeShot(bucket, filename)
    local primary = session and session.primaryBg or 'green'
    local raw1, raw2
    if session and (session.poseActive or session.opaque) then
        backdrop.setColor(primary)
        swait(120)
        raw1 = captureRaw()
    else
        local partner = MATTE_PARTNER[primary] or 'magenta'
        local settle = session and session.hairShot and 400 or 80
        backdrop.setColor(primary)
        swait(settle)
        raw1 = captureRaw()
        backdrop.setColor(partner)
        swait(settle)
        raw2 = captureRaw()
        backdrop.setColor(primary)
        if not raw2 or raw2 == '' then
            return { ok = false, error = 'capture failed' }
        end
    end
    if not raw1 or raw1 == '' then
        return { ok = false, error = 'capture failed' }
    end

    processCounter += 1
    local id = processCounter
    local p = promise.new()
    pendingProcess[id] = p
    local tint
    if session and session.hairShot and sharedConfig.studio.recolorHair then
        local r, g, b = GetPedHairRgbColor(session.hairColorOverride or sharedConfig.studio.hairColor)
        tint = { r, g, b }
    end
    SendNUIMessage({ action = 'studio:process', data = {
        id = id, uri1 = raw1, uri2 = raw2, opaque = session and session.opaque or nil,
        despill = session and session.hairShot or nil,
        tint = tint,
    } })
    SetTimeout(15000, function()
        if pendingProcess[id] then
            pendingProcess[id] = nil
            p:resolve({ ok = false, error = 'process timeout' })
        end
    end)
    local result = Citizen.Await(p)

    if result.ok and result.dataUri and filename then
        local base64 = result.dataUri
        result.dataUri = nil
        if #base64 > 120000 then
            return { ok = false, error = 'image too large for transport' }
        end
        local writeP = promise.new()
        local settled = false
        local function settle(value)
            if settled then return end
            settled = true
            writeP:resolve(value)
        end
        lib.callback('qbx_appearance:server:studioWrite', false, settle, bucket, filename, base64)
        SetTimeout(10000, function() settle({ ok = false, error = 'write timeout' }) end)
        local write = Citizen.Await(writeP)
        if not write or not write.ok then
            return { ok = false, error = write and write.error or 'write failed' }
        end
    end
    return result
end

local function shootCurrent()
    local item = session.work[session.index]
    if not item or session.shooting then return end
    session.shooting = true
    applyItem(item)
    frameItem(item)
    swait(400)

    local clipExtra = 0.0
    local clipTries = 0
    local streamTries = 0
    local flipped = false
    while true do
        if session.stopped then break end
        if not item.isProp and not session.bodyMode then rehideHead() end
        local result = takeShot(itemBucket(item), fileName(item))
        swait(50)
        if not result or not result.ok then
            local nothingVisible = result and result.error == 'nothing visible after matting'
            if nothingVisible and streamTries < 1 then
                streamTries += 1
                swait(800)
                applyItem(item)
                frameItem(item, clipExtra, flipped)
                swait(300)
            elseif nothingVisible and not flipped and item.isProp
                and FRAMING.props[item.id] and FRAMING.props[item.id].altBone then
                flipped = true
                frameItem(item, clipExtra, true)
                swait(200)
            elseif nothingVisible then
                session.empty += 1
                break
            else
                session.failures[#session.failures + 1] = fileName(item)
                studio.failedLog[failKey(session.modelName, item)] = {
                    model = session.modelName,
                    item = { id = item.id, isProp = item.isProp, collection = item.collection, drawable = item.drawable },
                    error = result and result.error or 'unknown',
                }
                break
            end
        elseif result.clipped and clipTries < 3 then
            clipTries += 1
            clipExtra += 0.18
            frameItem(item, clipExtra, flipped)
            swait(200)
        else
            session.done += 1
            studio.failedLog[failKey(session.modelName, item)] = nil
            break
        end
    end

    session.shooting = false
    SendNUIMessage({ action = 'studio:progress', data = {
        index = session.index, total = #session.work,
        item = session.work[session.index], failures = #session.failures,
        empty = session.empty,
    } })
end

---@param slots { id: number, isProp: boolean? }[]? slots to shoot; nil = everything
---@param opts { manual: boolean?, work: table[]?, model: string?, overwrite: boolean?, bodyMode: boolean? }? manual starts paused with full control; work overrides the plan (single-item re-shoots); model selects the mannequin's ped model; overwrite re-shoots files already on disk; bodyMode shoots on a dressed body with the head visible (missing "none" entries)
function studio.start(slots, opts)
    if session then return end
    opts = opts or {}
    studio.wasCancelled = false

    local playerPed = PlayerPedId()
    local model = GetEntityModel(playerPed)
    local modelName = opts.model
        or (model == `mp_f_freemode_01` and 'mp_f_freemode_01')
        or (model == `mp_m_freemode_01` and 'mp_m_freemode_01')
        or state.modelName

    local hash = joaat(modelName)
    if not IsModelInCdimage(hash) or not IsModelAPed(hash) then
        exports.qbx_core:Notify(locale('error.item_invalid'), 'error')
        return
    end

    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end

    local beforePos = GetEntityCoords(playerPed)
    SetEntityCoords(playerPed, STUDIO_POS.x - 4.0, STUDIO_POS.y, STUDIO_POS.z, false, false, false, false)
    FreezeEntityPosition(playerPed, true)
    SetEntityVisible(playerPed, false, false)
    SetEntityInvincible(playerPed, true)

    lib.requestModel(hash, 10000)
    local capturePed = CreatePed(4, hash, STUDIO_POS.x, STUDIO_POS.y, STUDIO_POS.z, STUDIO_HEADING, false, false)
    SetModelAsNoLongerNeeded(hash)
    statuePed(capturePed)

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, false, 0, false, false)
    DisplayRadar(false)
    DisableIdleCamera(true)

    session = {
        ped = capturePed, playerPed = playerPed, cam = cam, modelName = modelName,
        beforePos = beforePos, baseForward = GetEntityForwardVector(capturePed),
        index = 1, done = 0, paused = opts.manual == true, stopped = false,
        manual = opts.manual == true, bodyMode = opts.bodyMode == true,
        failures = {}, empty = 0, primaryBg = 'green', speed = 1.0,
        nudge = { x = 0.0, y = 0.0, z = 0.0, dist = 0.0, fov = 0.0 },
    }

    session.workOverride = opts.work ~= nil
    if opts.work then
        session.work = opts.work
    else
        slots = slots or (function()
            local all = {}
            for _, id in ipairs(appearance.COMPONENT_IDS) do
                if id ~= 0 then all[#all + 1] = { id = id } end
            end
            for _, id in ipairs(appearance.PROP_IDS) do all[#all + 1] = { id = id, isProp = true } end
            return all
        end)()
        session.slots = slots
        session.work = buildWorkList(slots)

        if not opts.manual and opts.overwrite ~= true then
            local existing = lib.callback.await('qbx_appearance:server:studioExisting', false)
            if existing and existing.ok and existing.files then
                local have = {}
                for _, file in ipairs(existing.files) do have[file] = true end
                local filtered = {}
                for _, item in ipairs(session.work) do
                    if not have[('%s/%s.webp'):format(itemBucket(item), fileName(item))] then
                        filtered[#filtered + 1] = item
                    end
                end
                lib.print.info(('clothing: %d total, %d already on disk, %d to capture')
                    :format(#session.work, #session.work - #filtered, #filtered))
                session.work = filtered
            end
        end
    end

    backdrop.start()
    backdrop.setColor('green')
    frameItem(session.work[1] or { id = 11, isProp = false })
    DoScreenFadeIn(300)
    Wait(500)

    slot0HideAllowed = nil
    session.headHide = probeHeadHide(session.ped)

    local tuningResult = lib.callback.await('qbx_appearance:server:studioTuning', false)
    session.tuning = tuningResult and tuningResult.tuning or {}

    session.cdn = lib.callback.await('qbx_appearance:server:cdnInfo', false) or { configured = false }

    syncOpen()
    SetNuiFocus(true, true)

    if session.paused then
        local item = session.work[1]
        if item then
            applyItem(item)
            frameItem(item)
            SendNUIMessage({ action = 'studio:progress', data = {
                index = 1, total = #session.work, item = item, failures = 0,
            } })
        end
    end

    CreateThread(function()
        while session and not session.stopped and session.index <= #session.work do
            if session.paused then
                Wait(200)
            else
                shootCurrent()
                session.index += 1
                if session.pauseAfterIndex and session.index > session.pauseAfterIndex then
                    session.pauseAfterIndex = nil
                    session.paused = true
                    session.index = math.min(session.index, #session.work)
                end
            end
        end
        if session then studio.stop() end
    end)
end

local function reportFailures()
    local count = 0
    for _, entry in pairs(studio.failedLog) do
        count += 1
        lib.print.warn(('failed: %s %s %d · %s #%d (%s)'):format(
            entry.model, entry.item.isProp and 'prop' or 'comp', entry.item.id,
            entry.item.collection == '' and 'base' or entry.item.collection,
            entry.item.drawable, entry.error))
    end
    if count > 0 then
        lib.print.warn(('%d item(s) failed — run /screenshotfailed to re-shoot them manually'):format(count))
        exports.qbx_core:Notify(locale('info.failed_items', count), 'error', 8000)
    end
end

function studio.stop()
    if not session then return end
    session.stopped = true
    local s = session
    session = nil
    reportFailures()

    lib.callback.await('qbx_appearance:server:studioEnd', false)
    backdrop.stop()
    RenderScriptCams(false, false, 0, false, false)
    DestroyCam(s.cam, false)
    DisplayRadar(true)
    DisableIdleCamera(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'studio:close' })

    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    if DoesEntityExist(s.ped) then DeleteEntity(s.ped) end
    local playerPed = s.playerPed
    SetEntityCoords(playerPed, s.beforePos.x, s.beforePos.y, s.beforePos.z, false, false, false, false)
    SetEntityVisible(playerPed, true, false)
    SetEntityInvincible(playerPed, false)
    FreezeEntityPosition(playerPed, false)
    DoScreenFadeIn(300)
end

local function waitBatchControls()
    while session and session.paused and not session.takeNow
        and not session.skipNow and not session.stopped do
        Wait(100)
    end
    if not session then return 'stop' end
    if session.stopped then return 'stop' end
    if session.skipNow then
        session.skipNow = false
        return 'skip'
    end
    session.takeNow = false
    return 'shoot'
end

local function applyAdjust(data)
    local ped = session.ped
    if data.dx and data.dx ~= 0 and ped and DoesEntityExist(ped) then
        SetEntityHeading(ped, (GetEntityHeading(ped) + data.dx * 0.4) % 360.0)
    end
    if data.dy and data.dy ~= 0 then
        session.nudge.z = session.nudge.z + data.dy * 0.0022
        if session.reframe then
            session.reframe()
        else
            local item = session.work and session.work[session.index]
            if item then frameItem(item) end
        end
    end
end

function studio.control(action, data)
    if not session then return end
    if session.faces then
        if action == 'stop' then
            session.stopped = true
            studio.wasCancelled = true
        elseif action == 'pause' then
            session.paused = true
        elseif action == 'resume' then
            session.paused = false
        elseif action == 'shoot' then
            session.takeNow = true
        elseif action == 'next' then
            session.skipNow = true
        elseif action == 'adjust' and data then
            applyAdjust(data)
        elseif action == 'zoom' and data and data.dir then
            session.nudge.dist = (session.nudge.dist or 0.0) - data.dir * 0.1
            if session.reframe then session.reframe() end
        elseif action == 'speed' and data then
            session.speed = data.value == 2 and 2.0 or 1.0
        elseif action == 'saveTuning' then
            local key = session.eyes and 'faces_eyes' or 'faces'
            local saved = session.tuning[key] or { z = 0.0, dist = 0.0 }
            session.tuning[key] = {
                z = saved.z + session.nudge.z,
                dist = saved.dist + session.nudge.dist,
            }
            session.nudge.z, session.nudge.dist = 0.0, 0.0
            lib.callback.await('qbx_appearance:server:studioSaveTuning', false, session.tuning)
            if session.reframe then session.reframe() end
            exports.qbx_core:Notify(locale('success.tuning_saved', key), 'success')
        end
        return
    end
    if action == 'pause' then
        session.paused = true
    elseif action == 'resume' then
        session.paused = false
    elseif action == 'stop' then
        session.stopped = true
        studio.wasCancelled = true
    elseif action == 'back' then
        session.paused = true
        session.index = math.max(1, session.index - 1)
        local item = session.work[session.index]
        if item then applyItem(item) frameItem(item) end
    elseif action == 'next' then
        session.paused = true
        session.index = math.min(#session.work, session.index + 1)
        local item = session.work[session.index]
        if item then applyItem(item) frameItem(item) end
    elseif action == 'jump' and data and data.index then
        session.paused = true
        session.index = math.max(1, math.min(#session.work, data.index))
        local item = session.work[session.index]
        if item then applyItem(item) frameItem(item) end
    elseif action == 'background' and data and data.color then
        if MATTE_PARTNER[data.color] then
            session.primaryBg = data.color
            backdrop.setColor(data.color)
        end
    elseif action == 'speed' and data then
        session.speed = data.value == 2 and 2.0 or 1.0
    elseif action == 'nudge' and data then
        local n = session.nudge
        n.x = data.x or n.x n.y = data.y or n.y n.z = data.z or n.z
        n.dist = data.dist or n.dist n.fov = data.fov or n.fov
        local item = session.work[session.index]
        if item then frameItem(item) end
    elseif action == 'zoom' and data and data.dir then
        local n = session.nudge
        n.dist = n.dist - data.dir * 0.08
        local item = session.work[session.index]
        if item then frameItem(item) end
    elseif action == 'adjust' and data then
        applyAdjust(data)
    elseif action == 'saveTuning' then
        local item = session.work[session.index]
        if not item then return end
        local key = (data and data.scope == 'collection') and collectionKey(item) or tuningKey(item)
        local saved = session.tuning[key] or itemTuning(item) or { x = 0.0, y = 0.0, z = 0.0, dist = 0.0, fov = 0.0 }
        local n = session.nudge
        session.tuning[key] = {
            x = saved.x + n.x, y = saved.y + n.y, z = saved.z + n.z,
            dist = saved.dist + n.dist, fov = saved.fov + n.fov,
        }
        n.x, n.y, n.z, n.dist, n.fov = 0.0, 0.0, 0.0, 0.0, 0.0
        lib.callback.await('qbx_appearance:server:studioSaveTuning', false, session.tuning)
        frameItem(item)
        SendNUIMessage({ action = 'studio:tuning', data = { tuning = session.tuning } })
        exports.qbx_core:Notify(locale('success.tuning_saved', key), 'success')
    elseif action == 'setTuning' and data and type(data.key) == 'string' then
        if not data.key:match('^comp_%d+') and not data.key:match('^prop_%d+') then return end
        if type(data.values) == 'table' then
            local v = data.values
            session.tuning[data.key] = {
                x = tonumber(v.x) or 0.0, y = tonumber(v.y) or 0.0, z = tonumber(v.z) or 0.0,
                dist = tonumber(v.dist) or 0.0, fov = tonumber(v.fov) or 0.0,
            }
        else
            session.tuning[data.key] = nil
        end
        lib.callback.await('qbx_appearance:server:studioSaveTuning', false, session.tuning)
        local item = session.work[session.index]
        if item then frameItem(item) end
        SendNUIMessage({ action = 'studio:tuning', data = { tuning = session.tuning } })
    elseif action == 'model' and data and type(data.model) == 'string' then
        studio.setModel(data.model)
    elseif action == 'hairColor' and data and type(data.index) == 'number' then
        session.hairColorOverride = math.floor(data.index)
    elseif action == 'shootCategory' and data and type(data.key) == 'string' then
        studio.shootCategory(data.key, type(data.collection) == 'string' and data.collection or nil)
    elseif action == 'shootCollection' and data and type(data.name) == 'string' then
        studio.shootCollection(data.name)
    elseif action == 'cdnSync' then
        local mode = data and data.mode == 'all' and 'all' or 'missing'
        CreateThread(function()
            local result = lib.callback.await('qbx_appearance:server:cdnSync', false, mode)
            if not result or not result.ok then
                exports.qbx_core:Notify(locale('error.cdn_sync_failed', result and result.error or 'timeout'), 'error')
            elseif result.total == 0 then
                exports.qbx_core:Notify(locale('info.cdn_sync_none'), 'inform')
            else
                exports.qbx_core:Notify(locale('info.cdn_sync_started', result.total), 'inform', 6000)
            end
        end)
    elseif action == 'shoot' then
        CreateThread(shootCurrent)
    end
end

function studio.isActive()
    return session ~= nil
end

local function mapCollection(collection, modelName)
    if modelName == 'mp_m_freemode_01' then
        local mapped = collection:gsub('^mp_f_', 'mp_m_')
        if mapped == collection then mapped = collection:gsub('^Female', 'Male') end
        return mapped
    elseif modelName == 'mp_f_freemode_01' then
        local mapped = collection:gsub('^mp_m_', 'mp_f_')
        if mapped == collection then mapped = collection:gsub('^Male', 'Female') end
        return mapped
    end
    return collection
end

function studio.shootCategory(key, collection)
    if not session or session.shooting or session.categoryRun then return end
    session.categoryRun = true
    CreateThread(function()
        local models = { session.modelName }
        if not session.workOverride then
            local other = session.modelName == 'mp_m_freemode_01' and 'mp_f_freemode_01'
                or session.modelName == 'mp_f_freemode_01' and 'mp_m_freemode_01' or nil
            if other then models[#models + 1] = other end
        end
        for _, model in ipairs(models) do
            if not session or session.stopped then break end
            if session.modelName ~= model then
                studio.setModel(model)
                Wait(500)
            end
            if not session or session.stopped then break end
            local target = collection and mapCollection(collection, session.modelName) or nil
            if target == 'base' then target = '' end
            local filtered = {}
            for _, item in ipairs(buildWorkList(session.slots)) do
                local folder = (item.isProp and PROP_FOLDERS[item.id] or COMP_FOLDERS[item.id]) or tostring(item.id)
                if folder == key and (not target or item.collection == target) then
                    filtered[#filtered + 1] = item
                end
            end
            if #filtered > 0 then
                session.work = filtered
                session.index = 1
                session.pauseAfterIndex = #filtered
                syncOpen()
                session.paused = false
                while session and not session.stopped and not session.paused do
                    Wait(200)
                end
            end
        end
        if session then
            session.categoryRun = nil
            session.work = buildWorkList(session.slots)
            session.index = 1
            session.paused = true
            syncOpen()
            local item = session.work[session.index]
            if item then applyItem(item) frameItem(item) end
        end
    end)
end

function studio.setModel(modelName)
    if not session or session.shooting or session.workOverride then return end
    if session.modelName == modelName then return end
    local hash = joaat(modelName)
    if not IsModelInCdimage(hash) or not IsModelAPed(hash) then return end

    lib.requestModel(hash, 10000)
    local old = session.ped
    session.ped = CreatePed(4, hash, STUDIO_POS.x, STUDIO_POS.y, STUDIO_POS.z, STUDIO_HEADING, false, false)
    SetModelAsNoLongerNeeded(hash)
    statuePed(session.ped)
    session.baseForward = GetEntityForwardVector(session.ped)
    if DoesEntityExist(old) then DeleteEntity(old) end

    session.modelName = modelName
    session.paused = true
    session.index = 1
    session.done = 0
    session.empty = 0
    session.failures = {}
    slot0HideAllowed = nil
    session.headHide = probeHeadHide(session.ped)
    session.work = buildWorkList(session.slots)

    local item = session.work[1]
    if item then
        applyItem(item)
        frameItem(item)
    end
    syncOpen()
end

function studio.shootCollection(name)
    if not session or session.shooting or session.categoryRun or session.workOverride then return end
    session.categoryRun = true
    CreateThread(function()
        local models = { session.modelName }
        local other = session.modelName == 'mp_m_freemode_01' and 'mp_f_freemode_01'
            or session.modelName == 'mp_f_freemode_01' and 'mp_m_freemode_01' or nil
        if other then models[#models + 1] = other end

        for _, model in ipairs(models) do
            if not session or session.stopped then break end
            if session.modelName ~= model then
                studio.setModel(model)
                Wait(500)
            end
            if not session or session.stopped then break end
            local target = mapCollection(name, session.modelName)
            if target == 'base' then target = '' end
            local filtered = {}
            for _, item in ipairs(buildWorkList(session.slots)) do
                if item.collection == target then filtered[#filtered + 1] = item end
            end
            if #filtered > 0 then
                session.work = filtered
                session.index = 1
                session.pauseAfterIndex = #filtered
                syncOpen()
                session.paused = false
                while session and not session.stopped and not session.paused do
                    Wait(200)
                end
            else
                lib.print.warn(('collection %s has no items on %s'):format(target, session.modelName))
            end
        end

        if session then
            session.categoryRun = nil
            session.work = buildWorkList(session.slots)
            session.index = 1
            session.paused = true
            syncOpen()
            local item = session.work[1]
            if item then applyItem(item) frameItem(item) end
        end
    end)
end

function studio.reshootFailed()
    if session then return end
    local byModel = {}
    for _, entry in pairs(studio.failedLog) do
        byModel[entry.model] = byModel[entry.model] or {}
        table.insert(byModel[entry.model], entry.item)
    end
    if not next(byModel) then
        exports.qbx_core:Notify(locale('info.no_failed_items'), 'inform')
        return
    end
    CreateThread(function()
        studio.wasCancelled = false
        for model, items in pairs(byModel) do
            if studio.wasCancelled then break end
            studio.start(nil, { manual = true, work = items, model = model })
            while studio.isActive() do Wait(500) end
            Wait(1000)
        end
    end)
end

---@param section 'all'|'faces'|'skins'|'eyes'?
function studio.startFaces(section)
    if session then return end
    if section ~= 'faces' and section ~= 'skins' and section ~= 'eyes' then section = 'all' end
    local playerPed = PlayerPedId()

    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end

    local before = state.snapshot()
    local beforeModelName = state.modelName
    local beforePos = GetEntityCoords(playerPed)

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, false, 0, false, false)
    DisplayRadar(false)
    DisableIdleCamera(true)
    backdrop.start()
    backdrop.setColor('green')

    local TOTAL = (section == 'faces' and 46)
        or (section == 'skins' and 92)
        or (section == 'eyes' and 32)
        or 46 + 46 * 2 + 32
    session = {
        faces = true, stopped = false, done = 0, speed = 1.0,
        clipExtra = 0.0, nudge = { z = 0.0, dist = 0.0 },
    }
    local tuningResult = lib.callback.await('qbx_appearance:server:studioTuning', false)
    session.tuning = tuningResult and tuningResult.tuning or {}
    SendNUIMessage({ action = 'studio:open', data = { total = TOTAL } })
    SetNuiFocus(true, true)

    local function frameHead(ped)
        local tune = session.tuning[session.eyes and 'faces_eyes' or 'faces'] or {}
        local dist = (session.eyes and 0.32 or 0.75)
            + (tune.dist or 0.0) + session.nudge.dist + session.clipExtra
        local zOff = (session.eyes and 0.06 or 0.05) + (tune.z or 0.0) + session.nudge.z
        local focus = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0) + vec3(0.0, 0.0, zOff)
        local camPos = focus + (session.baseForward or GetEntityForwardVector(ped)) * dist
        SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
        PointCamAtCoord(cam, focus.x, focus.y, focus.z)
        SetCamFov(cam, 20.0)
        backdrop.place(focus, camPos, 20.0)
    end

    local function shoot(name)
        local control = waitBatchControls()
        if control == 'stop' or control == 'skip' then return end
        local deadline = GetGameTimer() + 3000
        while not HasPedHeadBlendFinished(session.ped) and GetGameTimer() < deadline do
            Wait(50)
        end
        PlayFacialAnim(session.ped, 'dead_1', session.facialDict)
        pcall(function() SetPedCanPlayAmbientIdles(session.ped, false, true) end)
        Wait(150)
        session.reframe()
        swait(250)
        for _ = 1, session.eyes and 1 or 3 do
            local result = takeShot('faces', name)
            if not result or not result.ok or not result.clipped then break end
            session.clipExtra += 0.1
            session.reframe()
            swait(150)
        end
        session.clipExtra = 0.0
        session.done += 1
        SendNUIMessage({ action = 'studio:progress', data = { index = session.done, total = TOTAL, failures = 0 } })
    end

    local models = (section == 'faces' or section == 'eyes')
        and { 'mp_m_freemode_01' } or { 'mp_m_freemode_01', 'mp_f_freemode_01' }
    for _, modelName in ipairs(models) do
        if session.stopped then break end
        local ped = appearance.setPlayerModel(modelName, nil)
        if ped then
            local female = modelName == 'mp_f_freemode_01'
            SetEntityCoords(ped, STUDIO_POS.x, STUDIO_POS.y, STUDIO_POS.z, false, false, false, false)
            SetEntityHeading(ped, STUDIO_HEADING)
            statuePed(ped)
            SetEntityHealth(ped, GetEntityMaxHealth(ped))
            session.ped = ped
            session.baseForward = GetEntityForwardVector(ped)
            session.facialDict = female and 'facials@gen_female@base' or 'facials@gen_male@base'
            PlayFacialAnim(ped, 'dead_1', session.facialDict)
            session.reframe = function() frameHead(ped) end
            DoScreenFadeIn(200)
            frameHead(ped)

            if not female and (section == 'all' or section == 'faces') then
                for shape = 0, 45 do
                    if session.stopped then break end
                    SetPedHeadBlendData(ped, shape, shape, 0, 0, 0, 0, 1.0, 0.0, 0.0, false)
                    frameHead(ped)
                    shoot(('face_%d'):format(shape))
                end
            end
            if section == 'all' or section == 'skins' then
                for tone = 0, 45 do
                    if session.stopped then break end
                    SetPedHeadBlendData(ped, 0, 0, 0, tone, tone, 0, 0.0, 1.0, 0.0, false)
                    frameHead(ped)
                    shoot(('%s_skin_%d'):format(female and 'f' or 'm', tone))
                end
            end
            if not female and (section == 'all' or section == 'eyes') then
                SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.0, false)
                session.eyes = true
                session.opaque = true
                frameHead(ped)
                for eye = 0, 31 do
                    if session.stopped then break end
                    SetPedEyeColor(ped, eye)
                    Wait(100)
                    shoot(('eye_%d'):format(eye))
                end
                session.eyes = false
                session.opaque = false
            end
        end
    end

    session = nil
    lib.callback.await('qbx_appearance:server:studioEnd', false)
    backdrop.stop()
    RenderScriptCams(false, false, 0, false, false)
    DestroyCam(cam, false)
    DisplayRadar(true)
    DisableIdleCamera(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'studio:close' })

    DoScreenFadeOut(200)
    while not IsScreenFadedOut() do Wait(0) end
    local restored = PlayerPedId()
    if joaat(beforeModelName) ~= GetEntityModel(restored) then
        restored = appearance.setPlayerModel(beforeModelName, nil) or restored
        state.modelName = beforeModelName
    end
    state.apply(before)
    SetEntityCoords(restored, beforePos.x, beforePos.y, beforePos.z, false, false, false, false)
    unstatuePed(restored)
    PlayFacialAnim(restored, 'mood_normal_1',
        GetEntityModel(restored) == `mp_f_freemode_01` and 'facials@gen_female@base' or 'facials@gen_male@base')
    DoScreenFadeIn(300)
end

---@param overwrite boolean?
function studio.startPeds(overwrite)
    if session then return end

    local models = { 'mp_m_freemode_01', 'mp_f_freemode_01' }
    local seen = { mp_m_freemode_01 = true, mp_f_freemode_01 = true }
    local blacklist = {}
    for _, model in ipairs(pedsConfig.blacklist) do blacklist[model] = true end
    local function add(model)
        if not seen[model] and not blacklist[model] then
            seen[model] = true
            models[#models + 1] = model
        end
    end
    if not pedsConfig.freemodeOnly then
        for _, model in ipairs(pedsConfig.whitelist) do add(model) end
        if pedsConfig.allowHumanPeds then
            for _, model in ipairs(pedsConfig.models or {}) do add(model) end
        end
        if pedsConfig.allowAnimalPeds then
            for _, model in ipairs(pedsConfig.animalModels) do add(model) end
        end
    end

    if not overwrite then
        local existing = lib.callback.await('qbx_appearance:server:studioExisting', false)
        if existing and existing.ok and existing.files then
            local have = {}
            for _, file in ipairs(existing.files) do have[file] = true end
            local filtered = {}
            for _, model in ipairs(models) do
                if not have[('peds/%s.webp'):format(model)] then
                    filtered[#filtered + 1] = model
                end
            end
            lib.print.info(('ped portraits: %d requested, %d already on disk, %d to capture')
                :format(#models, #models - #filtered, #filtered))
            models = filtered
        end
    end

    if #models == 0 then
        exports.qbx_core:Notify(locale('info.peds_done'), 'inform')
        return
    end

    local playerPed = PlayerPedId()
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end

    local beforePos = GetEntityCoords(playerPed)
    SetEntityCoords(playerPed, STUDIO_POS.x - 4.0, STUDIO_POS.y, STUDIO_POS.z, false, false, false, false)
    FreezeEntityPosition(playerPed, true)
    SetEntityVisible(playerPed, false, false)
    SetEntityInvincible(playerPed, true)

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    RenderScriptCams(true, false, 0, false, false)
    DisplayRadar(false)
    DisableIdleCamera(true)
    backdrop.start()
    backdrop.setColor('green')

    session = { faces = true, stopped = false, done = 0, speed = 1.0, nudge = { z = 0.0, dist = 0.0 } }
    SendNUIMessage({ action = 'studio:open', data = { total = #models } })
    SetNuiFocus(true, true)
    DoScreenFadeIn(300)

    local FOV = 36.0
    local fitFactor = 0.5 / math.tan(math.rad(FOV) / 2) * 1.08
    local function frameCapturePed(ped)
        local min, max = GetModelDimensions(GetEntityModel(ped))
        local height = max.z - min.z
        local center = GetEntityCoords(ped) + vec3(0.0, 0.0, (min.z + max.z) / 2 + session.nudge.z)
        local dist = math.max(height * fitFactor, (max.y - min.y) * 1.8, 1.2) + session.nudge.dist
        local camPos = center + GetEntityForwardVector(ped) * dist + vec3(0.0, 0.0, height * 0.03)
        SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
        PointCamAtCoord(cam, center.x, center.y, center.z)
        SetCamFov(cam, FOV)
        backdrop.place(center, camPos, FOV)
    end

    local failures = 0
    for i, model in ipairs(models) do
        if session.stopped then break end
        local hash = joaat(model)
        if IsModelInCdimage(hash) and IsModelAPed(hash) then
            lib.requestModel(hash, 10000)
            local ped = CreatePed(4, hash, STUDIO_POS.x, STUDIO_POS.y, STUDIO_POS.z, STUDIO_HEADING, false, false)
            SetModelAsNoLongerNeeded(hash)
            initHeadBlend(ped, hash)
            statuePed(ped)
            SetEntityHealth(ped, GetEntityMaxHealth(ped))
            session.ped = ped
            session.reframe = function() frameCapturePed(ped) end
            frameCapturePed(ped)
            swait(350)
            local control = waitBatchControls()
            if control == 'stop' then
                DeleteEntity(ped)
                break
            end
            if control ~= 'skip' then
                local result = takeShot('peds', model)
                if not result or not result.ok then failures += 1 end
            end
            DeleteEntity(ped)
        else
            failures += 1
            lib.print.warn(('ped portrait: model %s is not a valid ped'):format(model))
        end
        session.done = i
        SendNUIMessage({ action = 'studio:progress', data = { index = i, total = #models, failures = failures } })
    end

    session = nil
    lib.callback.await('qbx_appearance:server:studioEnd', false)
    backdrop.stop()
    RenderScriptCams(false, false, 0, false, false)
    DestroyCam(cam, false)
    DisplayRadar(true)
    DisableIdleCamera(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'studio:close' })

    DoScreenFadeOut(200)
    while not IsScreenFadedOut() do Wait(0) end
    SetEntityCoords(playerPed, beforePos.x, beforePos.y, beforePos.z, false, false, false, false)
    FreezeEntityPosition(playerPed, false)
    SetEntityVisible(playerPed, true, false)
    SetEntityInvincible(playerPed, false)
    DoScreenFadeIn(300)
end

return studio
