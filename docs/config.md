# Configuration

Four files under `config/`. `shared.lua` loads on both sides, `client.lua` and
`peds.lua` on the client, `server.lua` only on the server (identifiers and API
keys never reach clients). The bare-body drawables live in
`shared/defaults.lua` — see the last section.

## config/shared.lua

### tattoos

| option | meaning |
| --- | --- |
| `maxOpacityLayers` | Tattoo opacity is produced by stacking the same decoration; this is the stack size at 100% opacity. Higher = finer opacity steps, more decoration slots used. |
| `maxPerPlayer` | Maximum tattoos worn at once (the game's decoration budget is finite). |

### clothingBag

| option | meaning |
| --- | --- |
| `item` | ox_inventory item name (see `docs/items.md`). |
| `cooldown` | Seconds between outfit switches via the bag. |
| `uses` | Uses per bag, `0` = unlimited. The bag is removed on its last use. |
| `menu` | `'nui'` for the outfit picker overlay, `'oxmenu'` for an ox_lib context menu. |

Using the bag plays a synchronized kneel scene with an animated duffel prop and
keeps the player kneeling until an outfit is picked or the menu is closed.

### imageSource

`'local'` serves thumbnails through `nui://` from the `screenshots/` folder
(every client downloads them with the resource). `'cdn'` loads them from
uploaded URLs instead — see `docs/cdn.md`.

### physicalItems

| option | meaning |
| --- | --- |
| `enabled` | Master toggle for physical clothing items and the item-based outfit sharing mode. |
| `item` | The ONE generic ox_inventory item used for every slot; metadata carries the slot, collection pair, label and thumbnail. |
| `slots` | Per-slot definition: chat `command`, display `label`, the `component` or `prop` id, and the equip animation (`anim`, optional `animOff` for a different take-off animation). Optional `resetWith`: component ids that go back to their bare defaults when the slot is stripped and are restored when the item is put back on (the shipped shirt slot resets arms, undershirt and decals). |

Running a slot's command (`/pants`, `/hat`, ...) plays the undress animation,
swaps the slot to its naked default (`shared/defaults.lua`, see below) and puts
the piece in the inventory. Using the item plays the dress animation and
re-equips it. Items refuse to equip on the other body type (drawable indexes differ per model).

### outfits

| option | meaning |
| --- | --- |
| `maxSaved` | Saved outfits per player, `0` = unlimited. |
| `maxGroupOutfits` | Presets per job/gang. |

### studio

| option | meaning |
| --- | --- |
| `recolorHair` | Recolor hair thumbnails to `hairColor` during processing. Freemode hair captures untinted (the engine can't tint it on a headless mannequin), so the processor remaps it to the target color; `false` saves the raw untinted capture instead and hides the studio's hair color swatches. |
| `hairColor` / `hairHighlight` | Hair color the thumbnails are recolored to — a neutral brown reads best on dark UI tiles. |
| `heroAngle` | Degrees off the frontal axis for the 3/4 "hero" framing; `0` = dead-on frontal. |
| `cameraHeight` | Camera elevation as a fraction of camera distance. |
| `propPoses` | Pose played while shooting a prop slot (watches/bracelets raise the wrist toward the camera). Posed items are captured with a single chroma-keyed shot instead of the two-capture matte, because a playing animation would differ between the two captures. |
| `decalBase` | Decals (component 10) are overlays on the body surface and cannot render without a base outfit worn; configured per model. |

### creation

| option | meaning |
| --- | --- |
| `freemodeOnly` | Character creation hides the ped tab and derives the model from multichar's `charinfo.gender`. |
| `defaultMale` / `defaultFemale` | Models used per gender. |

## config/client.lua

| option | meaning |
| --- | --- |
| `reloadSkinCooldown` | Milliseconds between `/reloadskin` uses. |
| `stores` | Shop zones (`clothing \| barber \| tattoo \| surgeon`), `coords.w` is the zone heading. |
| `lockers` | Predefined job/gang locker locations, see below. |
| `blips` | Map blips per store and locker type. |
| `shopSections` | Which editor sections each shop type unlocks (the surgeon sells face work, the barber hair, etc.). |

Lockers open the group outfit view for members of the group at or above the
minimum grade. Their blip is only created for members of that group (and
appears/disappears live on job or gang changes):

```lua
lockers = {
    {
        type = 'job_locker',            -- or 'gang_locker'
        group = 'police',
        minGrade = 0,
        label = 'LSPD Locker Room',     -- blip name, optional
        coords = vec4(452.05, -992.94, 30.69, 0.0),
        size = vec3(4, 4, 4),
        blip = true,
    },
},
```

Zones can also be created in-game with `/appearancezone` — those live in the
database and broadcast to every player instantly.

## config/server.lua

| option | meaning |
| --- | --- |
| `legacyMirror` | Mirror every save into the legacy `playerskins` table in illenium format, for resources that still read it. Turn off after migrating — see `docs/migration.md`. |
| `studioGroup` | ox_lib principal allowed to run studio/convert commands. |
| `studioAce` | Ace gating the capture callbacks: `add_ace group.admin qbx_appearance.studio allow`. |
| `studioCommands` | `false` removes every `/screenshot*` command entirely. |
| `convert.batchSize` | Legacy rows converted per client round-trip by `/convertappearance`. |
| `imageUpload` | CDN provider, API key and auto-upload toggle — see `docs/cdn.md`. |
| `pedAccess` | Per-player ped grants by any identifier (`citizenid:`, `license:`, `license2:`, `steam:`, `discord:`, `fivem:`). Grants extra models beyond the global policy; bypasses `freemodeOnly` and the category toggles, never the blacklist. Server-side only. |
| `clothingAccess` | Restrict clothing per job, gang, identifier or Discord role — see below. |
| `prices` | Charge per shop visit; `0` disables charging for that type. |

### clothingAccess

Hide specific drawables or whole DLC collections from the editor based on who
the player is. Rules are resolved server-side per player when the editor opens
— identifiers and role checks never reach the client, only the resulting list
of what to hide.

Each rule names the clothing it covers (`collections` for whole packs,
`items` for single drawables) and who it applies to:

- `mode = 'whitelist'` (default) — the clothing is hidden from everyone
  **except** matching players
- `mode = 'blacklist'` — the clothing is hidden **from** matching players

A player matches through any of: `jobs`/`gangs` (name → minimum grade),
`identifiers` (same formats as `pedAccess`), or `roles` (see below).

```lua
clothingAccess = {
    roleProvider = nil,
    rules = {
        -- police uniforms: only officers see the pack
        {
            mode = 'whitelist',
            collections = { 'mp_m_police_pack', 'mp_f_police_pack' },
            jobs = { police = 0, sheriff = 0 },
        },
        -- one specific mask for a VIP player and a Discord booster role
        {
            mode = 'whitelist',
            items = {
                { component = 1, collection = 'mp_m_2024_01', drawable = 12 },
            },
            identifiers = { 'citizenid:ABC12345' },
            roles = { '1146792312345678901' },
        },
        -- keep a bugged pack away from everyone except staff
        {
            mode = 'blacklist',
            collections = { 'broken_pack' },
            identifiers = {},
        },
    },
},
```

Collection names are per gender — list both the `mp_m_` and `mp_f_` variants
to cover both models.

`roles` requires a Discord integration, since FiveM cannot read guild roles by
itself. Point `roleProvider` at whatever your server uses; it receives a
player source and returns a list of role ids:

```lua
roleProvider = function(source)
    return exports.your_discord_resource:GetRoles(source)
end,
```

This gating is a UI filter (like illenium's DLC whitelist): hidden items don't
appear in the browser. It does not strip already-saved outfits when someone
loses access.

## config/peds.lua

Ped model policy, evaluated in order:

1. `blacklist` always wins
2. `freemodeOnly` limits everything to the freemode models
3. `whitelist` (when non-empty) limits selection to listed models
4. category toggles (`allowHumanPeds` / `allowAnimalPeds`) filter the rest

| option | meaning |
| --- | --- |
| `whitelist` | Models players may always pick (bypasses category toggles, not the blacklist). |
| `models` | Additional human peds offered when `allowHumanPeds` is true. |
| `blacklist` | Models nobody may use. |
| `animalModels` | The pool behind the `allowAnimalPeds` toggle. |

## config/tattoos.lua

The full base-game tattoo catalogue (840 entries, generated) plus hair fades.
Append custom tattoo DLCs to `list` — the UI picks them up automatically:

```lua
{ collection = 'my_custom_tattoos', overlay = { male = 'M_Custom_000', female = 'F_Custom_000' }, zone = 'ZONE_TORSO', label = 'Custom Piece' },
```

- `collection` — decoration collection name
- `overlay` — overlay preset per gender; set one gender to `''` when the pack has no variant for it (it is hidden for that gender)
- `zone` — `ZONE_TORSO`, `ZONE_HEAD`, `ZONE_LEFT_ARM`, `ZONE_RIGHT_ARM`, `ZONE_LEFT_LEG`, `ZONE_RIGHT_LEG`
- `label` — display name

`hairFades` are decorations layered under the hair component, offered in the
Hair panel.

## shared/defaults.lua

What a freemode ped wears when a slot is "empty": bare arms, no undershirt, the
no-top torso, underwear, bare feet. The file is keyed by model, then by
component id:

```lua
return {
    ['mp_m_freemode_01'] = {
        components = {
            ['3'] = { global = true, drawable = 15, texture = 0 },   -- arms
            ['4'] = { global = true, drawable = 61, texture = 0 },   -- legs
            ['6'] = { global = true, drawable = 34, texture = 0 },   -- shoes
            ['8'] = { global = true, drawable = 15, texture = 0 },   -- undershirt
            ['11'] = { global = true, drawable = 252, texture = 0 }, -- top
        },
    },
    ['mp_f_freemode_01'] = {
        components = {
            ['3'] = { global = true, drawable = 15, texture = 0 },
            ['4'] = { global = true, drawable = 14, texture = 0 },
            ['6'] = { global = true, drawable = 35, texture = 0 },
            ['8'] = { global = true, drawable = 14, texture = 0 },
            ['11'] = { global = true, drawable = 74, texture = 0 },
        },
    },
}
```

These are used in four places:

- taking a piece off with a physical-item command (`/shirt`, `/pants`, `/shoes`)
  swaps that slot to its default and hands the piece over;
- a new character starts wearing exactly these;
- switching model in the editor dresses the new body with them;
- the editor's undress toggles and the studio's body mode use them as the base.

Slots without an entry (mask, bag, ...) fall back to drawable 0 of the base
collection, which is "nothing" for those.

### Two ways to write an entry

`global = true` means the drawable is a global index — the plain number every
clothing list, the radial menu and the classic screenshot tools use, counted
across all installed packs. That's the form the file ships with, because the
well-known bare-body numbers are global ones. They are resolved to the right
pack on the player's ped at runtime, so they keep working as packs are added.

An entry can also point at a specific pack with a collection pair, the same
form the editor and the database use:

```lua
['11'] = { collection = 'mp_m_2023_01', drawable = 5, texture = 0 },
```

Use whichever you have at hand. The editor shows the collection and local
index of the worn item in the item grid (`mp_m_2023_01` · `5`), so copying an
item from there is a collection pair; a number from a clothing list is a
global index and needs `global = true`.

### Example: a different bare top

If your server prefers a plain white tee over the bare torso when a shirt comes
off, change the top entry for that model:

```lua
['mp_m_freemode_01'] = {
    components = {
        ['3'] = { global = true, drawable = 0, texture = 0 },    -- arms that match a tee
        ['4'] = { global = true, drawable = 61, texture = 0 },
        ['6'] = { global = true, drawable = 34, texture = 0 },
        ['8'] = { global = true, drawable = 15, texture = 0 },
        ['11'] = { global = true, drawable = 15, texture = 0 },  -- white t-shirt
    },
},
```

Restart the resource; there is no migration, the values are read live.

### Taking a shirt off: `resetWith`

Most newer packs build the arms into the top itself and pair the top with an
"invisible" arms drawable (component 3), so the sleeves don't clip. If taking
the top off only swapped component 11, the invisible arms would stay and the
player would look like a torso with no arms. The shirt slot therefore carries
`resetWith`:

```lua
shirt = { command = 'shirt', label = 'Shirt', component = 11,
    resetWith = { 3, 8, 10 },   -- arms, undershirt, decals
    anim = { dict = 'clothingtie', clip = 'try_tie_negative_a', dur = 1200 } },
```

When the shirt comes off, every listed component goes back to its entry in
`shared/defaults.lua` (or drawable 0 when there is none, as for decals). The
values they had ride along in the shirt item's metadata, so putting the shirt
back on restores the exact arms, gloves, undershirt and decal that were worn
with it — nothing is lost, and a player who wants gloves on a bare torso just
picks them again. The list is yours to change: drop `10` to keep decals showing
on bare skin, or add `resetWith` to other slots whose packs have similar
pairings.
