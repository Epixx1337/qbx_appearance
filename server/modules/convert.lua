local db = require 'server.modules.db'
local config = require 'config.server'

local function runConversion(source, format)
    local rows = MySQL.query.await('SELECT `citizenid`, `model`, `skin` FROM `playerskins` WHERE `active` = 1')
    if not rows or #rows == 0 then
        exports.qbx_core:Notify(source, locale('error.no_legacy_rows'), 'error')
        return
    end

    exports.qbx_core:Notify(source, locale('info.convert_started', #rows), 'inform')
    local converted, failed = 0, 0
    local batchSize = config.convert.batchSize

    for offset = 1, #rows, batchSize do
        local batch = {}
        for i = offset, math.min(offset + batchSize - 1, #rows) do
            local row = rows[i]
            local ok, skin = pcall(json.decode, row.skin)
            if ok and type(skin) == 'table' then
                batch[#batch + 1] = { citizenid = row.citizenid, model = row.model, skin = skin }
            else
                failed += 1
            end
        end

        if #batch > 0 then
            local results = lib.callback.await('qbx_appearance:client:convertBatch', source, format, batch)
            if not results then
                exports.qbx_core:Notify(source, locale('error.convert_aborted'), 'error')
                return
            end
            for i = 1, #batch do
                local appearance = results[i]
                if appearance then
                    db.saveAppearance(batch[i].citizenid, appearance)
                    converted += 1
                else
                    failed += 1
                end
            end
        end
    end

    exports.qbx_core:Notify(source, locale('info.convert_done', converted, failed), 'success')
    lib.print.info(('appearance conversion (%s): %d converted, %d failed'):format(format, converted, failed))
end

lib.addCommand('convertappearance', {
    help = 'Convert legacy skins to qbx_appearance (illenium | qb-clothing)',
    restricted = config.studioGroup,
    params = {
        { name = 'format', type = 'string', help = 'illenium or qb-clothing' },
    },
}, function(source, args)
    local format = args.format
    if format ~= 'illenium' and format ~= 'qb-clothing' then
        exports.qbx_core:Notify(source, locale('error.convert_format'), 'error')
        return
    end
    CreateThread(function()
        runConversion(source, format)
    end)
end)
