# Appearance data schema

The canonical appearance blob stored in `players.appearance` (JSON). All drawable and
prop indexes are **collection-local**: a `{ collection, drawable }` pair, never a global
index. The base game collection is the empty string `''`, matching the natives.

```jsonc
{
  "model": "mp_m_freemode_01",          // ped model name

  "headBlend": {                        // SetPedHeadBlendData
    "shapeFirst": 0, "shapeSecond": 0, "shapeThird": 0,
    "skinFirst": 0, "skinSecond": 0, "skinThird": 0,
    "shapeMix": 0.5, "skinMix": 0.5, "thirdMix": 0.0
  },

  "faceFeatures": [                     // SetPedFaceFeature, indexes 0-19, -1.0..1.0
    0.0, 0.0, /* ... 20 entries ... */ 0.0
  ],

  "headOverlays": {                     // SetPedHeadOverlay(+Color), keyed by overlay id 0-12
    "0": { "style": 0, "opacity": 1.0, "colorType": 0, "firstColor": 0, "secondColor": 0 }
  },

  "eyeColor": 3,                        // SetHeadBlendEyeColor

  "hair": {
    "collection": "",                   // hair is component 2, stored like any component
    "drawable": 14,
    "texture": 0,
    "color": 29,                        // SetPedHairTint
    "highlight": 29,
    "fade": { "collection": "mpbeach_overlays", "overlay": "FM_Hair_Fuzz" }  // optional hair decoration
  },

  "components": {                       // SetPedCollectionComponentVariation, keyed by component id 0-11
    "3":  { "collection": "", "drawable": 15, "texture": 0 },
    "4":  { "collection": "female_heist", "drawable": 9, "texture": 3 },
    "11": { "collection": "custom_pack_1", "drawable": 2, "texture": 1 }
  },

  "props": {                            // SetPedCollectionPropIndex, keyed by anchor id 0-13; absent = cleared
    "0": { "collection": "mp_f_bikerdlc_01", "drawable": 0, "texture": 0 }
  },

  "tattoos": [                          // ordered; re-applied top to bottom
    {
      "overlay": "MP_Bea_M_Back_000",   // overlay name (hashed at apply time)
      "collection": "mpbeach_overlays", // decoration collection name
      "zone": "ZONE_TORSO",             // informational, for UI grouping
      "opacity": 0.65,                  // 0.05..1.0 — faked by layered re-application
      "label": "Love the Game"          // display name (from tattoo config or import)
    }
  ]
}
```

## Rules

- Missing `components` keys fall back to the model's defaults (drawable 0 texture 0).
- Missing `props` keys mean *cleared* (`ClearPedProp`).
- `headBlend`, `faceFeatures`, `headOverlays`, `eyeColor`, `hair.color/highlight/fade`
  only apply to freemode models; ignored for other peds.
- Tattoo `opacity` maps to N stacked `AddPedDecorationFromHashes` calls:
  `layers = math.max(1, math.ceil(opacity * Config.tattoos.maxOpacityLayers))`.
- On load, if a saved `{collection, drawable}` no longer exists
  (`GetPedDrawableGlobalIndexFromCollection` returns -1), the component falls back to
  the default and the mismatch is logged — clothing packs were changed, indexes weren't.

## Outfit rows

`qbx_appearance_outfits.outfit` stores the same shape, but partial: an outfit saved as
"clothing only" contains only `components` + `props`; a "hair & tattoos" save contains
only `hair` + `tattoos` + `headOverlays` (beard/eyebrow overlays). The `kind` column
records which ('full' | 'clothing' | 'style'). Applying an outfit merges it over the
player's current appearance and persists the merged result.

## Database tables

| Table | Purpose |
|---|---|
| `qbx_appearance` | One row per citizenid: the canonical appearance blob (this schema), `model`, `updated_at`. |
| `qbx_appearance_outfits` | Player-saved outfits. `kind` = `full` \| `clothing` \| `style`. |
| `qbx_appearance_group_outfits` | Job/gang presets made by bosses in-UI (`group_type`, `group_name`, `min_grade`, `gender`). |
| `qbx_appearance_zones` | Shops/lockers created with `/appearancezone` (box or laser-drawn polygon, live-broadcast). |
| `playerskins` | **Legacy, kept for compatibility** — see the mirror below. |

### The `playerskins` mirror (`legacyMirror`)

Every save writes two places: the canonical blob into `qbx_appearance`, and an
**illenium-format copy into `playerskins`** (deactivate-all → delete row for
that model → insert active row, exactly like illenium did). This is controlled
by `config/server.lua → legacyMirror` (default `true`).

Why: some resources read `playerskins` **directly from the database** instead
of going through events/exports. The big one is qbx_core's multichar ped
preview:

```lua
-- qbx_core/server/storage/players.lua
function FetchPlayerSkin(citizenId)
    return MySQL.single.await('SELECT * FROM playerskins WHERE citizenid = ? AND active = 1', {citizenId})
end
```

That row's `skin` JSON is handed to
`exports['illenium-appearance']:setPedAppearance(ped, json.decode(skin))` in
`qbx_core/client/character.lua` — which qbx_appearance answers via its export
shim (it converts the illenium shape internally). **With the mirror on, the
character-select preview works with zero qbx_core changes.** Leave it on.

### Turning the mirror off

Only do this if nothing on the server reads `playerskins` anymore. To keep the
multichar preview working without the mirror, patch qbx_core to read the new
table and hand the blob to qbx_appearance's own export:

```lua
-- qbx_core/server/storage/players.lua — replace FetchPlayerSkin with:
function FetchPlayerSkin(citizenId)
    local row = MySQL.single.await(
        'SELECT citizenid, model, appearance AS skin, 1 AS active FROM qbx_appearance WHERE citizenid = ?',
        {citizenId})
    return row
end
```

```lua
-- qbx_core/client/character.lua — replace the illenium export call with:
pcall(function() exports.qbx_appearance:setPedAppearance(json.decode(clothing)) end)
```

(`qbx_appearance:setPedAppearance` takes the canonical blob from this schema
directly — no conversion needed. The illenium-named export expects the OLD
shape, so don't mix the two.)

### `qbx_appearance_zones`

Rows are loaded once on resource start and pushed to every client on
create/delete — no restart. `points` is NULL for box zones
(`x/y/z/heading/width/length/height`) or a JSON `[[x,y,z], ...]` polygon drawn
with the laser tool, with `height` as the zone thickness. `job_locker` /
`gang_locker` rows use `group_name` + `min_grade` to gate who sees the prompt.

## Legacy formats accepted by the converters

- **illenium-appearance**: `playerskins.skin` JSON with global `component`/`prop`
  `drawable` indexes, `headBlend`, `faceFeatures` (named keys), `headOverlays` (named
  keys), `tattoos` (with per-tattoo `opacity` already present in recent versions).
  Global indexes are converted with `GetPedCollectionNameFromDrawable` /
  `GetPedCollectionLocalIndexFromDrawable` on a live client (conversion natives are
  client-only), driven by the server convert command.
- **qb-clothing**: `playerskins.skin` in qb "model/skin" format
  (`{ "face": {"item": n, "texture": n}, ... }`) using global indexes; same runtime
  conversion path.
