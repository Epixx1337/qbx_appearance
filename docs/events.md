# Events, callbacks and exports

## Client events

| Event | Purpose |
|---|---|
| `qbx_appearance:client:openClothing` | Open clothing store editor (charges on save) |
| `qbx_appearance:client:openBarber` | Open barber editor |
| `qbx_appearance:client:openTattoo` | Open tattoo editor |
| `qbx_appearance:client:openFull` | Open the full editor, free |
| `qbx_appearance:client:createCharacter` | Character creation flow |
| `qbx_appearance:client:reloadSkin` | Re-apply saved appearance |
| `qbx_appearance:client:openJobOutfits` / `openGangOutfits` | Group outfit menus |
| `qbx_appearance:client:openStudio` / `openStudioFaces` | Screenshot studio |

## Client exports

```lua
exports.qbx_appearance:startPlayerCustomization(cb, opts) -- cb(appearance|nil)
exports.qbx_appearance:getPedAppearance()                 -- current appearance blob
exports.qbx_appearance:setPedAppearance(blob)             -- apply partial/full blob
exports.qbx_appearance:setPlayerAppearance(blob)          -- apply incl. model swap
exports.qbx_appearance:applyOutfit(outfit, kind, model)   -- merge outfit + persist
exports.qbx_appearance:setPedSkin(ped, skin)              -- apply illenium-shaped skin (multichar preview)
```

## Server exports

```lua
exports.qbx_appearance:GetSkin(citizenid) -- saved skin in illenium shape + model name
```

## Server callbacks

All prefixed `qbx_appearance:server:` —

- appearance: `getAppearance`, `saveAppearance`, `chargeShop`, `getPedAccess`
- outfits: `getOutfits`, `getOutfit`, `saveOutfit`, `overwriteOutfit`,
  `renameOutfit`, `deleteOutfit`, `getGroupOutfits`, `saveGroupOutfit`,
  `deleteGroupOutfit`
- sharing: `shareOutfitItem`, `shareOutfitTo`, `getNearbyNames`,
  `consumeOutfitBag`
- items: `bagEquip`, `giveClothingItem`, `consumeClothingItem`
- studio: `canStudio`, `studioWrite`, `studioExisting`, `studioTuning`,
  `studioSaveTuning`, `studioEnd`, `cdnInfo`, `cdnMap`, `cdnSync`
- zones: `getZones`, `addZone`, `updateZone`, `deleteZone`

## Commands

- `/reloadskin`
- `/pedmenu [scope] [id]` (admin) — scope: full | clothing | outfits | barber | tattoo | surgeon, optional target player
- `/hat /glasses /earring /watch /bracelet /mask /shirt /pants /shoes /bag` — strip slot into an item
- `/screenshotclothing [male|female|both|current] [overwrite]`, `/screenshotmissing [target]`, `/screenshotfaces`, `/screenshotpeds [overwrite]`, `/screenshotstudio`, `/screenshotfailed` (admin; removed entirely with `studioCommands = false`)
- `/appearancezone` (admin) — create (laser polygon or box) / delete shop & locker zones, live
- `/convertappearance illenium|qb-clothing` (admin)

## Compatibility surface (drop-in for illenium-appearance)

Client events handled: `illenium-appearance:client:changeOutfit`, `loadJobOutfit`,
`openClothingShop(Menu)`, `openOutfitMenu`, `openJobOutfitsMenu`, `OpenBarberShop`,
`OpenTattooShop`, `OpenSurgeonShop`, `reloadSkin`, `ClearStuckProps`, and the
historical typo `illenium-apearance:client:outfitsCommand`.

qb events handled: `qb-clothes:client:CreateFirstCharacter`,
`qb-clothing:client:openMenu`, `openOutfitMenu`, `loadOutfit`.

Server events/callbacks handled: `illenium-appearance:server:saveAppearance`,
`getAppearance`, `getOutfits`, `saveOutfit`, `updateOutfit`, `deleteOutfit`,
`getManagementOutfits`, `saveManagementOutfit`, `deleteManagementOutfit`
(+ no-op shims for `resetOutfitCache`, `syncUniform`, `endPaidSession`).

Client exports re-registered under the `illenium-appearance` name:
`getPedAppearance`, `getPedModel`, `setPlayerAppearance`, `setPedAppearance`,
`setPedTattoos`, `setPedComponent(s)`, `setPedProp(s)`, `startPlayerCustomization`.
The real illenium-appearance resource must NOT be running at the same time.
