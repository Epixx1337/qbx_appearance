local state = require 'client.modules.state'
local appearance = require 'client.modules.appearance'

local outfits = {}

---@param outfit table
---@param kind 'full'|'clothing'|'style'|nil
---@param model string? switch to this model first when it differs
function outfits.apply(outfit, kind, model)
    if model and (kind == 'full' or not kind) then
        local hash = joaat(model)
        if GetEntityModel(PlayerPedId()) ~= hash then
            appearance.setPlayerModel(model, nil)
            state.modelName = model
        end
    end

    local blob
    if kind == 'clothing' then
        blob = { components = outfit.components, props = outfit.props }
    elseif kind == 'style' then
        blob = {
            hair = outfit.hair, tattoos = outfit.tattoos,
            headOverlays = outfit.headOverlays, eyeColor = outfit.eyeColor,
        }
    else
        blob = outfit
    end

    local failures = state.apply(blob)
    if #failures > 0 then
        lib.print.warn('outfit drawables no longer exist:', json.encode(failures))
        exports.qbx_core:Notify(locale('error.outfit_partial'), 'error')
    end
    state.persist()
end

---@param kind 'full'|'clothing'|'style'
---@return table
function outfits.build(kind)
    local snapshot = state.snapshot()
    if kind == 'clothing' then
        return { components = snapshot.components, props = snapshot.props }
    end
    if kind == 'style' then
        return {
            hair = snapshot.hair, tattoos = snapshot.tattoos,
            headOverlays = snapshot.headOverlays, eyeColor = snapshot.eyeColor,
        }
    end
    return snapshot
end

return outfits
