# ox_inventory item definitions

Add these to `ox_inventory/data/items.lua`. Names must match
`config/shared.lua` (`clothingBag.item` and `physicalItems.item`).

```lua
['clothing_bag'] = {
    label = 'Clothing Bag',
    weight = 1500,
    stack = false,
    close = true,
    description = 'A duffel bag with a change of clothes',
},

-- One generic item covers every clothing slot; qbx_appearance drives it
-- entirely through metadata.
['clothing_item'] = {
    label = 'Clothing',
    weight = 250,
    stack = false,
    close = true,
    description = 'A piece of clothing',
},

-- Shared outfit pack (outfit Share button with physicalItems enabled): the whole
-- outfit lives in metadata; using it equips the outfit (same body type only).
['outfit_bag'] = {
    label = 'Outfit Bag',
    weight = 500,
    stack = false,
    close = true,
    description = 'A packed outfit, ready to wear',
},
```

The items are made usable by qbx_appearance at runtime
(`exports.qbx_core:CreateUseableItem`) — no `client`/`server` export entries
are needed in the definitions.

When a slot is stripped via its command (`/hat`, `/mask`, `/shirt`, ...) the
resource writes the metadata on the spawned `clothing_item`:

| metadata key | value |
|---|---|
| `slot` | which slot it re-equips (`hat`, `shirt`, ...) |
| `collection`, `drawable`, `texture` | the collection pair worn |
| `label` | display name, e.g. `Hat #12` (shown instead of "Clothing") |
| `imageurl` | the item's clothing screenshot (`nui://qbx_appearance/screenshots/clothing/...`), shown as the inventory tile image once the studio has generated it |
| `description` | slot description |
| `companions` | only on slots with `resetWith` (the shirt): the arms, undershirt and decal worn under it, restored when the item is used |
