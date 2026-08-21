# Known resource conflicts

## qbx_radialmenu — clothing chat commands

qbx_appearance registers chat commands for its physical clothing items
(`config/shared.lua → physicalItems.slots`): `/hat`, `/glasses`, `/earring`,
`/watch`, `/bracelet`, `/mask`, `/shirt`, `/pants`, `/shoes`, `/bag`.

qbx_radialmenu's clothing module registers **client-side** commands with the same
names (its animated take-off/put-on toggles). A client command intercepts the chat
command locally, so qbx_appearance's server command never runs — `/pants` will
play the radialmenu toggle instead of stripping the pants into an inventory item.

### Fix

Comment out the command-registration loop in
`qbx_radialmenu/client/clothing.lua` (around line 912):

```lua
-- for k,v in pairs(config.clothingCommands) do
-- 	RegisterCommand(k, v.Func, false)
-- 	--log("Created /"..k.." ("..v.Desc..")") -- Useful for translation checking.
-- 	TriggerEvent("chat:addSuggestion", "/"..k, v.Desc)
-- end
```

Only the chat commands are removed. The radial menu's clothing buttons keep
working — they call the toggle functions directly, not the commands.

Alternatively, keep radialmenu's commands and rename qbx_appearance's in
`config/shared.lua → physicalItems.slots[*].command`.

## illenium-appearance / qb-clothing

Remove (do not just stop) these resources. qbx_appearance ships a compat layer
that re-registers their client events and exports, so resources depending on
them keep working — but if the originals are still started they will fight over
the same events, commands (`/reloadskin`) and the `playerskins` table.
