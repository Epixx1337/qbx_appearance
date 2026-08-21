local appearance = require 'client.modules.appearance'

local state = {
    tattoos = {},
    hairFade = nil,
    modelName = 'mp_m_freemode_01',
    lastSaved = nil,
}

---@return table
function state.snapshot()
    local ped = PlayerPedId()
    local snapshot = appearance.getPedAppearance(ped, {
        tattoos = state.tattoos,
        hairFade = state.hairFade,
    })
    local model = snapshot.model
    if model == `mp_m_freemode_01` then snapshot.model = 'mp_m_freemode_01'
    elseif model == `mp_f_freemode_01` then snapshot.model = 'mp_f_freemode_01'
    elseif joaat(state.modelName) == model then snapshot.model = state.modelName end
    if type(snapshot.model) == 'string' then state.modelName = snapshot.model end
    return snapshot
end

---@param data table
---@return string[] failures
function state.apply(data)
    local ped = PlayerPedId()
    if type(data.model) == 'string' then state.modelName = data.model end
    if data.tattoos then state.tattoos = data.tattoos end
    if data.hair and data.hair.fade ~= nil then
        state.hairFade = data.hair.fade ~= false and data.hair.fade or nil
    end
    local failures = appearance.setPedAppearance(ped, data)
    appearance.applyDecorations(ped, state.tattoos, state.hairFade)
    return failures
end

function state.persist()
    local snapshot = state.snapshot()
    state.lastSaved = snapshot
    TriggerServerEvent('qbx_appearance:server:saveAppearance', snapshot)
    return snapshot
end

return state
