# Internals & engine notes

Constraints the implementation is built around. The code carries no comments;
this page is the record of the non-obvious parts.

## Collections

Every drawable and prop is stored as a `{ collection, drawable }` pair and
applied through the collection natives
(`SetPedCollectionComponentVariation` and friends), so saved appearances
survive title updates that shift global indexes. Legacy entries carrying
`global = true` apply through the legacy natives and are normalized into
collection pairs on their next save. The base game acts as the collection with
the empty-string name.

## Appearance state

- Decorations (tattoos, hair fades) are write-only in the engine — the worn
  set is tracked client-side and always re-applied in full after any change.
- Tattoo opacity is produced by stacking the same decoration up to
  `maxOpacityLayers` times; layering order is preserved per zone.
- `PlayerPedId()` is preferred over `cache.ped` in state code: the cache is
  stale immediately after `SetPlayerModel`.
- The tracked model name self-heals from the real ped on snapshot, so a
  resource restart mid-session cannot corrupt saves.

## Studio capture pipeline

- The client captures the screen, the NUI canvas does all image processing,
  and the server only writes finished webp files. Nothing heavier than a
  ~55 KB webp ever crosses the network — oversized event payloads fail
  serialization silently, so the encoder works within a byte budget.
- The difference matte takes two captures of the identical frozen frame
  against two backdrop colors and solves per-pixel alpha and unblended color:
  `a = 1 − (P1−P2)/(B1−B2)`, `C = (P1 − (1−a)·B1) / a`. This requires the two
  frames to be pixel-identical, which is why the studio freezes the clock,
  weather and wind and statue-freezes the mannequin (ambient anims, base idle
  breathing and blink clips all disabled).
- Scripted pose animations cannot be frozen — the anim-speed natives only
  affect entity anims, not task anims — so posed items (wrist props) are shot
  with a single chroma-keyed capture instead of the matte pair.
- Close-ups whose frame contains no backdrop at all (eye colors) cannot be
  matted or keyed; they are saved opaque exactly as framed.
- A ped with every component empty is culled by the engine and its props
  vanish. Prop shots keep "none" meshes (drawable 0) on a few slots to stay
  renderable; component shots don't need it since the item itself keeps the
  ped alive. One of the "none" meshes renders a small placeholder box — the
  processor removes it as a stray blob (tiny relative to the subject and far
  from it).
- The head is hidden through the client-side `allowEmptyHeadDrawable` convar
  (a user preference — `setr` cannot set it, scripts cannot either). Slot 0 is
  re-hidden immediately before each capture because the engine re-validates it
  after other variation calls.
- `GetPedBoneCoords` offsets are bone-local; all framing height offsets are
  applied in world space after reading the bone position.
- The framing camera axis is captured once per session. Deriving it from the
  ped's live forward vector would make every re-frame chase a manual rotation
  back to frontal.
- Changing a head blend morphs over up to a second — face shots wait for
  `HasPedHeadBlendFinished` and re-frame after, or mid-morph heads misframe
  and ghost.

## Editor

- Undress badges snapshot exactly what was worn and re-equip it on toggle or
  on save; the stripped state is preview-only and can never persist.
- Zoom-to-cursor projects a ladder of bones to screen space and focuses the
  pair bracketing the cursor, so scrolling zooms toward what is pointed at.
- Male-only tattoos mark the female overlay as the empty string and are hidden
  for female characters (and vice versa).

## Persistence & multichar

- Appearance lives in `qbx_appearance` (JSON blob keyed by citizenid); the
  schema is in `docs/schema.md`.
- qbx_core's multichar preview fetches through the `GetSkin` server export,
  which converts to the illenium shape it historically consumed. The optional
  `legacyMirror` writes the same shape into `playerskins` for third-party
  readers during migration.
- The `pedAccess` grants are matched against player identifiers server-side
  and only the resulting model list is sent to the client.

## NUI

- Thumbnails resolve `screenshots/<bucket>/<file>.webp` through `nui://` — the
  file set is declared in `fxmanifest.lua` and resolved at resource start, so
  freshly generated images need a resource restart to serve. CDN mode
  (`imageSource = 'cdn'`) resolves the same paths through uploaded URLs with a
  local fallback per file.
- The slot→folder mapping exists in `client/modules/studio.lua` and
  `web/src/lib/nui.js` and must stay in sync.
- The processor's frame-crop fraction must match the dashed photo frame's size
  in the studio UI (`FRAME_HEIGHT_FRAC` ↔ `.photo-frame`).
