local pending = {}
local counter = 0

AddEventHandler('qbx_appearance:internal:result', function(id, result)
    local p = pending[id]
    if not p then return end
    pending[id] = nil
    p:resolve(result)
end)

local bridge = {}

function bridge.request(event, ...)
    counter += 1
    local id = counter
    local p = promise.new()
    pending[id] = p
    TriggerEvent(event, id, ...)
    SetTimeout(15000, function()
        if pending[id] then
            pending[id] = nil
            p:resolve({ ok = false, error = 'timeout' })
        end
    end)
    return Citizen.Await(p)
end

return bridge
