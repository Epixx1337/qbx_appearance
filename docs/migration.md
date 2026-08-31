# Migrating from illenium-appearance / qb-clothing

The migration happens in two stages so nothing breaks while you verify.

## Stage 1 — run side-by-side on legacy data

1. Remove (do not just stop) `illenium-appearance` / `qb-clothing` and
   `ensure qbx_appearance`. The compat layer re-registers their client events
   and exports, so dependent resources keep working — but if the originals are
   still started they will fight over the same events and commands.
2. Import `sql/install.sql`.
3. Migrate the skins — both paths work, use either or both:
   - **Automatic**: nothing to run. When a player logs in with no
     `qbx_appearance` row but an active `playerskins` row, their skin is
     converted on their own client right then, saved, and applied. Players
     migrate themselves as they log in.
   - **Bulk**: run `/convertappearance illenium` (or `qb-clothing`) once
     in-game as admin to convert every row up front (batched,
     `convert.batchSize` rows per round-trip). Useful if you want the whole
     database converted before dropping the legacy table.

   Either way the conversion resolves global drawable indexes into collection
   pairs through the conversion natives on a live client — that's why it
   can't happen purely server-side.
4. Keep `legacyMirror = true` in `config/server.lua`: every save is mirrored
   back into `playerskins` in illenium format, so anything still reading that
   table (an unpatched qbx_core multichar preview, third-party scripts) keeps
   working while you verify.
5. Comment out qbx_radialmenu's clothing chat commands (`docs/conflicts.md`)
   so `/pants`, `/shirt` etc. reach this resource.

## Stage 2 — cut over

qbx_core needs three small patches so the multichar preview reads from
qbx_appearance instead of `playerskins`.

**1. `qbx_core/server/storage/players.lua`** — ask qbx_appearance first, keep
the old query as a fallback:

```lua
local function fetchPlayerSkin(citizenId)
    if GetResourceState('qbx_appearance') == 'started' then
        local ok, skin, model = pcall(function()
            return exports.qbx_appearance:GetSkin(citizenId)
        end)
        if ok and skin then
            return { citizenid = citizenId, model = model, skin = json.encode(skin), active = 1 }
        end
    end
    return MySQL.single.await('SELECT * FROM playerskins WHERE citizenid = ? AND active = 1', {citizenId})
end
```

`GetSkin` returns the saved skin in the same shape `playerskins` rows used, so
nothing downstream changes.

**2. `qbx_core/client/character.lua`** — in `previewPed`, swap the export the
preview applies the skin with:

```lua
-- before
pcall(function() exports['illenium-appearance']:setPedAppearance(PlayerPedId(), json.decode(clothing)) end)

-- after
pcall(function() exports.qbx_appearance:setPedSkin(PlayerPedId(), json.decode(clothing)) end)
```

**3. `qbx_core/config/server.lua`** — let character deletion clean appearance
data too:

```lua
characterDataTables = {
    -- ...
    {'qbx_appearance', 'citizenid'},
    {'qbx_appearance_outfits', 'citizenid'},
    -- ...
},
```

Then:

4. Set `legacyMirror = false` in this resource's `config/server.lua` —
   `playerskins` stops being written.
5. Verify: multichar preview shows the right clothes, character load applies
   the saved look, `/reloadskin`, outfits and the clothing bag all behave.
6. Once nothing else queries `playerskins` (`grep -r playerskins resources/`),
   drop the table — rename it first as a backup, the converter can re-read it
   as long as it exists — and remove the `{'playerskins', 'citizenid'}` entry
   from qbx_core's `characterDataTables`:

```sql
RENAME TABLE playerskins TO playerskins_backup;
```

## Compatibility surface

The client compat layer stays active regardless of the mirror and costs
nothing: illenium-appearance and qb-clothing client events are handled, the
illenium client exports are re-registered, and `docs/events.md` lists the full
surface. Third-party resources that trigger illenium events or call its
exports keep working without edits.
