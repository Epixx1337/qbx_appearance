local db = {}

local convert = require 'shared.convert'
local legacyMirror = require 'config.server'.legacyMirror

---@param citizenid string
---@return table? appearance
function db.getAppearance(citizenid)
    local row = MySQL.single.await('SELECT `appearance` FROM `qbx_appearance` WHERE `citizenid` = ?', { citizenid })
    if not row then return nil end
    return json.decode(row.appearance)
end

---@param citizenid string
---@param appearance table
function db.saveAppearance(citizenid, appearance)
    local model = tostring(appearance.model or 'mp_m_freemode_01')
    MySQL.insert.await([[
        INSERT INTO `qbx_appearance` (`citizenid`, `appearance`, `model`)
        VALUES (?, ?, ?)
        ON DUPLICATE KEY UPDATE `appearance` = VALUES(`appearance`), `model` = VALUES(`model`)
    ]], { citizenid, json.encode(appearance), model })

    if legacyMirror then
        local ok, err = pcall(function()
            local skin = json.encode(convert.toIllenium(appearance))
            MySQL.update.await('UPDATE playerskins SET active = 0 WHERE citizenid = ?', { citizenid })
            MySQL.query.await('DELETE FROM playerskins WHERE citizenid = ? AND model = ?', { citizenid, model })
            MySQL.insert.await(
                'INSERT INTO playerskins (citizenid, model, skin, active) VALUES (?, ?, ?, 1)',
                { citizenid, model, skin })
        end)
        if not ok then
            lib.print.warn('playerskins mirror failed (does the table exist?):', err)
        end
    end
end

---@param citizenid string
function db.deleteAppearance(citizenid)
    MySQL.query.await('DELETE FROM `qbx_appearance` WHERE `citizenid` = ?', { citizenid })
end

---@param citizenid string
---@return { id: number, label: string, kind: string, model: string, thumb: string? }[]
function db.getOutfits(citizenid)
    return MySQL.query.await([[
        SELECT `id`, `label`, `kind`, `model`, `thumb` FROM `qbx_appearance_outfits`
        WHERE `citizenid` = ? ORDER BY `created_at` ASC
    ]], { citizenid }) or {}
end

---@param citizenid string
---@param id number
---@return table? outfit
function db.getOutfit(citizenid, id)
    local row = MySQL.single.await([[
        SELECT `label`, `outfit`, `kind`, `model` FROM `qbx_appearance_outfits` WHERE `id` = ? AND `citizenid` = ?
    ]], { id, citizenid })
    if not row then return nil end
    return { label = row.label, outfit = json.decode(row.outfit), kind = row.kind, model = row.model }
end

---@param citizenid string
---@return number
function db.countOutfits(citizenid)
    return MySQL.scalar.await('SELECT COUNT(*) FROM `qbx_appearance_outfits` WHERE `citizenid` = ?', { citizenid }) or 0
end

---@param citizenid string
---@param label string
---@param kind 'full'|'clothing'|'style'
---@param model string
---@param outfit table
---@return number id
function db.saveOutfit(citizenid, label, kind, model, outfit)
    return MySQL.insert.await([[
        INSERT INTO `qbx_appearance_outfits` (`citizenid`, `label`, `kind`, `model`, `outfit`)
        VALUES (?, ?, ?, ?, ?)
    ]], { citizenid, label, kind, model, json.encode(outfit) })
end

---@param citizenid string
---@param id number
---@param outfit table
---@return boolean
function db.overwriteOutfit(citizenid, id, outfit)
    local affected = MySQL.update.await([[
        UPDATE `qbx_appearance_outfits` SET `outfit` = ? WHERE `id` = ? AND `citizenid` = ?
    ]], { json.encode(outfit), id, citizenid })
    return affected > 0
end

---@param citizenid string
---@param id number
---@param label string
---@return boolean
function db.renameOutfit(citizenid, id, label)
    local affected = MySQL.update.await([[
        UPDATE `qbx_appearance_outfits` SET `label` = ? WHERE `id` = ? AND `citizenid` = ?
    ]], { label, id, citizenid })
    return affected > 0
end

---@param citizenid string
---@param id number
---@return boolean
function db.deleteOutfit(citizenid, id)
    local affected = MySQL.update.await([[
        DELETE FROM `qbx_appearance_outfits` WHERE `id` = ? AND `citizenid` = ?
    ]], { id, citizenid })
    return affected > 0
end

---@param groupType 'job'|'gang'
---@param groupName string
---@param grade number player's grade; only outfits at or below are returned
---@return table[]
function db.getGroupOutfits(groupType, groupName, grade)
    local rows = MySQL.query.await([[
        SELECT `id`, `label`, `min_grade` AS minGrade, `gender`, `model`, `outfit`
        FROM `qbx_appearance_group_outfits`
        WHERE `group_type` = ? AND `group_name` = ? AND `min_grade` <= ?
        ORDER BY `min_grade` ASC, `label` ASC
    ]], { groupType, groupName, grade }) or {}
    for i = 1, #rows do
        rows[i].outfit = json.decode(rows[i].outfit)
    end
    return rows
end

---@param groupType 'job'|'gang'
---@param groupName string
---@return number
function db.countGroupOutfits(groupType, groupName)
    return MySQL.scalar.await([[
        SELECT COUNT(*) FROM `qbx_appearance_group_outfits` WHERE `group_type` = ? AND `group_name` = ?
    ]], { groupType, groupName }) or 0
end

---@param groupType 'job'|'gang'
---@param groupName string
---@param data { label: string, minGrade: number, gender: string, model: string, outfit: table }
---@param createdBy string?
---@return number id
function db.saveGroupOutfit(groupType, groupName, data, createdBy)
    return MySQL.insert.await([[
        INSERT INTO `qbx_appearance_group_outfits`
            (`group_type`, `group_name`, `min_grade`, `label`, `gender`, `model`, `outfit`, `created_by`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        groupType, groupName, data.minGrade or 0, data.label, data.gender or 'any',
        data.model or 'mp_m_freemode_01', json.encode(data.outfit), createdBy,
    })
end

---@param groupType 'job'|'gang'
---@param groupName string
---@param id number
---@return boolean
function db.deleteGroupOutfit(groupType, groupName, id)
    local affected = MySQL.update.await([[
        DELETE FROM `qbx_appearance_group_outfits` WHERE `id` = ? AND `group_type` = ? AND `group_name` = ?
    ]], { id, groupType, groupName })
    return affected > 0
end

---@return table[]
function db.getZones()
    return MySQL.query.await('SELECT * FROM `qbx_appearance_zones`') or {}
end

---@param zone table
---@param createdBy string?
---@return number id
function db.addZone(zone, createdBy)
    return MySQL.insert.await([[
        INSERT INTO `qbx_appearance_zones`
            (`type`, `label`, `group_name`, `min_grade`, `x`, `y`, `z`, `heading`, `width`, `length`, `height`, `points`, `blip`, `created_by`)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        zone.type, zone.label, zone.group_name, zone.min_grade or 0,
        zone.x, zone.y, zone.z, zone.heading or 0,
        zone.width or 4, zone.length or 4, zone.height or 4,
        zone.points and json.encode(zone.points) or nil,
        zone.blip and 1 or 0, createdBy,
    })
end

---@param id number
---@param zone table
---@return boolean
function db.updateZone(id, zone)
    return MySQL.update.await([[
        UPDATE `qbx_appearance_zones` SET
            `type` = ?, `label` = ?, `group_name` = ?, `min_grade` = ?,
            `x` = ?, `y` = ?, `z` = ?, `heading` = ?,
            `width` = ?, `length` = ?, `height` = ?, `points` = ?, `blip` = ?
        WHERE `id` = ?
    ]], {
        zone.type, zone.label, zone.group_name, zone.min_grade or 0,
        zone.x, zone.y, zone.z, zone.heading or 0,
        zone.width or 4, zone.length or 4, zone.height or 4,
        zone.points and json.encode(zone.points) or nil,
        zone.blip and 1 or 0, id,
    }) > 0
end

---@param id number
---@return boolean
function db.deleteZone(id)
    return MySQL.update.await('DELETE FROM `qbx_appearance_zones` WHERE `id` = ?', { id }) > 0
end

return db
