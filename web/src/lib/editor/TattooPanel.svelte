<script>
    import { untrack } from 'svelte'
    import { fetchNui } from '../nui.js'
    import { editor } from '../store.svelte.js'

    const catalog = $derived(editor.catalog)

    const zone = $derived(editor.subcategory ?? 'ZONE_TORSO')

    const worn = $state([])
    $effect.pre(() => {
        const copy = editor.current?.tattoos?.map((t) => ({ ...t }))
        if (copy) {
            untrack(() => {
                worn.length = 0
                worn.push(...copy)
            })
        }
    })

    const zoneCatalog = $derived.by(() =>
        (catalog?.tattoos ?? []).filter((t) => t.zone === zone || (zone === 'ZONE_BACK' && t.zone === 'ZONE_TORSO'))
    )

    function push() {
        fetchNui('editor:setTattoos', { tattoos: worn.map((t) => ({ ...t })) })
    }

    function add(entry) {
        const existing = worn.findIndex((t) => t.overlay === entry.overlay && t.collection === entry.collection)
        if (existing >= 0) {
            worn.splice(existing, 1)
            push()
            return
        }
        if (catalog?.maxTattoos && worn.length >= catalog.maxTattoos) return
        worn.push({
            overlay: entry.overlay,
            collection: entry.collection,
            zone: entry.zone,
            opacity: 1.0,
            label: entry.label,
        })
        push()
    }

    function preview(entry) {
        fetchNui('editor:previewTattoo', {
            overlay: entry.overlay, collection: entry.collection,
            zone: entry.zone, opacity: 1.0, label: entry.label,
        })
    }

    function endPreview() {
        push()
    }

    function remove(index) {
        worn.splice(index, 1)
        push()
    }

    function move(index, dir) {
        const zoneKey = worn[index].zone
        let target = index + dir
        while (target >= 0 && target < worn.length && worn[target].zone !== zoneKey) target += dir
        if (target < 0 || target >= worn.length) return
        const item = worn[index]
        worn[index] = worn[target]
        worn[target] = item
        push()
    }

    const ZONE_LABELS = {
        ZONE_HEAD: 'Head', ZONE_TORSO: 'Torso',
        ZONE_LEFT_ARM: 'Left Arm', ZONE_RIGHT_ARM: 'Right Arm',
        ZONE_LEFT_LEG: 'Left Leg', ZONE_RIGHT_LEG: 'Right Leg',
        ZONE_HAIR: 'Hair',
    }

    const wornGroups = $derived.by(() => {
        const groups = []
        const byZone = new Map()
        worn.forEach((tattoo, index) => {
            const key = tattoo.zone ?? 'ZONE_TORSO'
            if (!byZone.has(key)) {
                const group = { zone: key, label: ZONE_LABELS[key] ?? key, items: [] }
                byZone.set(key, group)
                groups.push(group)
            }
            byZone.get(key).items.push({ tattoo, index })
        })
        return groups
    })

    function jumpZone(zoneKey) {
        editor.subcategory = zoneKey
        fetchNui('camera:tattooZone', { zone: zoneKey })
    }

    function setOpacity(index, value) {
        worn[index].opacity = value
        push()
    }

    const isWorn = (entry) => worn.some((t) => t.overlay === entry.overlay && t.collection === entry.collection)
</script>

<div class="content">
    <div class="section-title">Available — {zoneCatalog.length}</div>
    <div class="catalog">
        {#each zoneCatalog as entry (entry.collection + entry.overlay)}
            <button
                class="tattoo-entry"
                class:worn={isWorn(entry)}
                onclick={() => add(entry)}
                onmouseenter={() => preview(entry)}
                onmouseleave={endPreview}
            >
                <span class="label">{entry.label}</span>
                <span class="coll">{entry.collection}</span>
            </button>
        {/each}
        {#if zoneCatalog.length === 0}
            <div class="empty">No tattoos configured for this zone</div>
        {/if}
    </div>

    <div class="section-title">
        Selected — {worn.length}{catalog?.maxTattoos ? ` / ${catalog.maxTattoos}` : ''}
    </div>
    <div class="selected">
        {#each wornGroups as group (group.zone)}
            <button class="zone-head" class:current={zone === group.zone}
                title="Jump the camera to this zone" onclick={() => jumpZone(group.zone)}>
                {group.label} — {group.items.length}
            </button>
            {#each group.items as { tattoo, index } (index)}
                <div class="worn-row">
                    <div class="worn-head">
                        <button class="icon" onclick={() => remove(index)} title="Remove">✕</button>
                        <span class="label">{tattoo.label ?? tattoo.overlay}</span>
                        <div class="order">
                            <button class="icon" onclick={() => move(index, -1)} title="Layer up">▲</button>
                            <button class="icon" onclick={() => move(index, 1)} title="Layer down">▼</button>
                        </div>
                    </div>
                    <label class="slider-row">
                        <span>Opacity</span>
                        <input
                            type="range" min="0.05" max="1" step="0.05"
                            value={tattoo.opacity}
                            oninput={(e) => setOpacity(index, Number(e.currentTarget.value))}
                        />
                        <span class="value">{Math.round(tattoo.opacity * 100)}</span>
                    </label>
                </div>
            {/each}
        {/each}
        {#if worn.length === 0}
            <div class="empty">No tattoos applied. Stack several with different opacity for a sleeve effect.</div>
        {/if}
    </div>
</div>

<style>
    .content {
        flex: 1;
        display: flex;
        flex-direction: column;
        min-height: 0;
    }

    .catalog {
        flex: 1;
        min-height: 100px;
        overflow-y: auto;
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: 6px;
        align-content: start;
        margin-bottom: 12px;
        padding-right: 4px;
    }

    .tattoo-entry {
        display: flex;
        flex-direction: column;
        align-items: flex-start;
        gap: 2px;
        padding: 8px 10px;
        background: var(--dark-7);
        border: 1px solid var(--border);
        border-radius: var(--radius-sm);
        cursor: pointer;
        font-family: inherit;
        transition: border-color 0.12s var(--ease);
    }

    .tattoo-entry:hover {
        border-color: var(--accent-40);
    }

    .tattoo-entry.worn {
        border-color: var(--accent);
        background: var(--accent-8);
    }

    .tattoo-entry .label {
        font-size: 12px;
        font-weight: 500;
        color: var(--dark-0);
    }

    .tattoo-entry .coll {
        font-size: 10px;
        color: var(--dark-3);
    }

    .selected {
        flex: 1;
        min-height: 100px;
        overflow-y: auto;
        display: flex;
        flex-direction: column;
        gap: 6px;
        padding-right: 4px;
    }

    .zone-head {
        display: flex;
        align-items: center;
        margin-top: 4px;
        padding: 4px 8px;
        background: transparent;
        border: none;
        font-size: 10px;
        font-weight: 700;
        letter-spacing: 0.08em;
        text-transform: uppercase;
        color: var(--dark-2);
        cursor: pointer;
        font-family: inherit;
    }

    .zone-head:hover {
        color: var(--accent-light);
    }

    .zone-head.current {
        color: var(--accent-light);
    }

    .worn-row {
        padding: 8px 10px;
        background: var(--dark-7);
        border: 1px solid var(--border);
        border-radius: var(--radius-sm);
    }

    .worn-head {
        display: flex;
        align-items: center;
        gap: 8px;
        margin-bottom: 6px;
    }

    .worn-head .label {
        flex: 1;
        font-size: 12px;
        font-weight: 500;
    }

    .order {
        display: flex;
        gap: 2px;
    }

    .icon {
        width: 20px;
        height: 20px;
        display: flex;
        align-items: center;
        justify-content: center;
        background: var(--dark-6);
        color: var(--dark-2);
        border: 1px solid var(--border);
        border-radius: 4px;
        font-size: 9px;
        cursor: pointer;
    }

    .icon:hover {
        color: var(--dark-0);
        border-color: var(--accent-40);
    }

    .slider-row {
        display: grid;
        grid-template-columns: 50px 1fr 34px;
        align-items: center;
        gap: 8px;
        font-size: 11px;
        color: var(--dark-1);
    }

    .slider-row .value {
        text-align: right;
        color: var(--accent-light);
        font-weight: 600;
    }

    input[type='range'] {
        appearance: none;
        height: 4px;
        background: var(--dark-5);
        border-radius: 2px;
        outline: none;
    }

    input[type='range']::-webkit-slider-thumb {
        appearance: none;
        width: 12px;
        height: 12px;
        background: var(--accent);
        border-radius: 50%;
        cursor: pointer;
    }

    .empty {
        font-size: 12px;
        color: var(--dark-3);
        padding: 12px;
        text-align: center;
        grid-column: 1 / -1;
    }
</style>
