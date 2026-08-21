<script>
    import { fetchNui } from '../nui.js'
    import { editor } from '../store.svelte.js'
    import DrawableGrid from './DrawableGrid.svelte'

    const catalog = $derived(editor.catalog)

    const OVERLAYS = [
        { id: 1, label: 'Beard', colored: 'hair' },
        { id: 2, label: 'Eyebrows', colored: 'hair' },
        { id: 10, label: 'Chest Hair', colored: 'hair' },
        { id: 4, label: 'Makeup', colored: 'makeup' },
        { id: 5, label: 'Blush', colored: 'makeup' },
        { id: 8, label: 'Lipstick', colored: 'makeup' },
        { id: 0, label: 'Blemishes & Scars' },
        { id: 3, label: 'Ageing' },
        { id: 6, label: 'Complexion' },
        { id: 7, label: 'Sun Damage' },
        { id: 9, label: 'Moles & Freckles' },
        { id: 11, label: 'Body Blemishes' },
    ]

    const tab = $derived(editor.subcategory ?? 'style')

    const hair = $state({ collection: '', drawable: 0, texture: 0, color: 0, highlight: 0, fade: null })
    $effect.pre(() => {
        const current = editor.current?.hair
        if (current) Object.assign(hair, current)
    })

    function pushHair(extra = {}) {
        fetchNui('editor:setHair', {
            collection: hair.collection, drawable: hair.drawable, texture: hair.texture,
            color: hair.color, highlight: hair.highlight,
            ...extra,
        })
    }

    function setStyle(collection, drawable, texture) {
        hair.collection = collection
        hair.drawable = drawable
        hair.texture = texture ?? 0
        pushHair()
    }

    function setColor(kind, index) {
        hair[kind] = index
        pushHair()
    }

    function setFade(fade) {
        hair.fade = fade
        pushHair({ fade: fade ?? false })
    }

    const overlayState = $state({})
    $effect.pre(() => {
        const current = editor.current?.headOverlays
        if (current) {
            for (const [id, data] of Object.entries(current)) {
                overlayState[id] = { style: data.style ?? 0, opacity: data.opacity ?? 1, firstColor: data.firstColor ?? 0 }
            }
        }
    })

    function overlay(id) {
        return overlayState[id] ?? { style: -1, opacity: 1, firstColor: 0 }
    }

    function toggleOverlay(id) {
        overlayState[id] ??= { style: -1, opacity: 1, firstColor: 0 }
        openOverlay = openOverlay === id ? -1 : id
    }

    function pushOverlay(id) {
        const o = overlayState[id]
        if (!o) return
        fetchNui('editor:setHeadOverlay', {
            id,
            style: o.style < 0 ? 255 : o.style,
            opacity: o.style < 0 ? 0 : o.opacity,
            firstColor: o.firstColor,
            secondColor: o.firstColor,
        })
    }

    let openOverlay = $state(-1)

    const range = (n) => Array.from({ length: n }, (_, i) => i)
    const swatch = (rgb) => `rgb(${rgb[0]}, ${rgb[1]}, ${rgb[2]})`
</script>

<div class="content">
    {#if tab === 'style' && catalog}
        {#if catalog.freemode}
            <div class="section-title">Hair Color</div>
            <div class="swatches">
                {#each catalog.hairColors as rgb, i (i)}
                    <button
                        class="swatch" class:active={hair.color === i}
                        style="background: {swatch(rgb)}"
                        onclick={() => setColor('color', i)}
                    ></button>
                {/each}
            </div>
            <div class="section-title">Highlight</div>
            <div class="swatches">
                {#each catalog.hairColors as rgb, i (i)}
                    <button
                        class="swatch" class:active={hair.highlight === i}
                        style="background: {swatch(rgb)}"
                        onclick={() => setColor('highlight', i)}
                    ></button>
                {/each}
            </div>
            {#if catalog.hairFades?.length}
                <div class="section-title">Hair Fade</div>
                <div class="fade-chips">
                    <button class="chip" class:active={!hair.fade} onclick={() => setFade(null)}>None</button>
                    {#each catalog.hairFades as fade (fade.overlay)}
                        <button
                            class="chip"
                            class:active={hair.fade?.overlay === fade.overlay}
                            onclick={() => setFade({ collection: fade.collection, overlay: fade.overlay })}
                        >
                            {fade.label}
                        </button>
                    {/each}
                </div>
            {/if}
        {/if}
        <div class="section-title">Style</div>
        <DrawableGrid
            slotId={2}
            collections={catalog.components?.['2'] ?? []}
            current={{ collection: hair.collection, drawable: hair.drawable, texture: hair.texture }}
            onselect={setStyle}
        />
    {:else if tab === 'overlays' && catalog}
        {#each OVERLAYS as def (def.id)}
            {@const count = catalog.overlays?.[String(def.id)] ?? 0}
            {#if count > 0}
                <div class="overlay-block" class:open={openOverlay === def.id}>
                    <button class="overlay-head" onclick={() => toggleOverlay(def.id)}>
                        <span>{def.label}</span>
                        <span class="state">{overlay(def.id).style < 0 ? 'Off' : overlay(def.id).style}</span>
                    </button>
                    {#if openOverlay === def.id && overlayState[def.id]}
                        {@const o = overlayState[def.id]}
                        <div class="overlay-body">
                            <div class="style-row">
                                <button class="chip" class:active={o.style < 0}
                                    onclick={() => { o.style = -1; pushOverlay(def.id) }}>None</button>
                                {#each range(count) as i (i)}
                                    <button class="chip" class:active={o.style === i}
                                        onclick={() => { o.style = i; pushOverlay(def.id) }}>{i}</button>
                                {/each}
                            </div>
                            {#if o.style >= 0}
                                <label class="slider-row">
                                    <span>Opacity</span>
                                    <input type="range" min="0.05" max="1" step="0.05" value={o.opacity}
                                        oninput={(e) => { o.opacity = Number(e.currentTarget.value); pushOverlay(def.id) }} />
                                    <span class="value">{Math.round(o.opacity * 100)}</span>
                                </label>
                                {#if def.colored}
                                    <div class="swatches">
                                        {#each (def.colored === 'hair' ? catalog.hairColors : catalog.makeupColors) as rgb, i (i)}
                                            <button class="swatch" class:active={o.firstColor === i}
                                                style="background: {swatch(rgb)}"
                                                onclick={() => { o.firstColor = i; pushOverlay(def.id) }}></button>
                                        {/each}
                                    </div>
                                {/if}
                            {/if}
                        </div>
                    {/if}
                </div>
            {/if}
        {/each}
    {/if}
</div>

<style>
    .content {
        flex: 1;
        overflow-y: auto;
        display: flex;
        flex-direction: column;
        min-height: 0;
        padding-right: 4px;
    }

    .swatches {
        display: flex;
        flex-wrap: wrap;
        gap: 4px;
        margin-bottom: 12px;
    }

    .swatch {
        width: 20px;
        height: 20px;
        border-radius: 50%;
        border: 2px solid var(--border);
        cursor: pointer;
        padding: 0;
    }

    .swatch:hover {
        border-color: var(--dark-0);
    }

    .swatch.active {
        border-color: var(--accent);
        box-shadow: 0 0 6px var(--accent-40);
    }

    .fade-chips {
        display: flex;
        flex-wrap: wrap;
        gap: 6px;
        margin-bottom: 12px;
    }

    .overlay-block {
        border: 1px solid var(--border);
        border-radius: var(--radius-sm);
        margin-bottom: 8px;
        overflow: hidden;
    }

    .overlay-head {
        width: 100%;
        display: flex;
        justify-content: space-between;
        padding: 10px 12px;
        background: var(--dark-7);
        border: none;
        color: var(--dark-0);
        font-family: inherit;
        font-size: 13px;
        font-weight: 500;
        cursor: pointer;
    }

    .overlay-block.open .overlay-head {
        background: var(--accent-15);
        color: var(--accent-light);
    }

    .overlay-head .state {
        color: var(--dark-2);
        font-size: 12px;
    }

    .overlay-body {
        padding: 10px 12px;
        display: flex;
        flex-direction: column;
        gap: 8px;
    }

    .style-row {
        display: flex;
        flex-wrap: wrap;
        gap: 4px;
        max-height: 110px;
        overflow-y: auto;
    }

    .slider-row {
        display: grid;
        grid-template-columns: 70px 1fr 34px;
        align-items: center;
        gap: 10px;
        font-size: 12px;
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
</style>
