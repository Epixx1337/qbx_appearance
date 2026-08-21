<script>
    import { fetchNui, thumbUrl, thumbFallback, CLOTHING_PLACEHOLDER } from '../nui.js'
    import { editor } from '../store.svelte.js'

    let { slotId, isProp = false, collections = [], current = null, clearable = false, onselect } = $props()

    const ALL = '__all__'
    let search = $state('')
    let selected = $state(null)
    let textureCount = $state(0)
    let texture = $state(0)

    $effect.pre(() => {
        if (current && current.drawable >= 0) {
            const collection = current.collection ?? ''
            const drawable = current.drawable
            selected = { collection, drawable }
            texture = current.texture ?? 0
            loadTextures(collection, drawable, false)
        } else {
            selected = null
        }
    })

    const model = $derived(editor.catalog?.model ?? 'mp_m_freemode_01')
    const totalCount = $derived(collections.reduce((sum, group) => sum + group.count, 0))

    const entries = $derived.by(() => {
        const q = search.trim().toLowerCase()
        const out = []
        for (const group of collections) {
            if (editor.collectionFilter !== ALL && group.collection !== editor.collectionFilter) continue
            const name = group.collection || 'base'
            const nameMatches = !q || name.toLowerCase().includes(q)
            const numeric = /^\d+$/.test(q)
            if (q && !nameMatches && !numeric) continue
            for (let i = 0; i < group.count; i++) {
                if (q && numeric && !String(i).includes(q) && !nameMatches) continue
                out.push({ collection: group.collection, drawable: i, key: `${group.collection}:${i}` })
            }
        }
        return out
    })

    const COLS = 4
    const GAP = 6
    const BUFFER_ROWS = 2

    let viewport = $state(null)
    let viewportW = $state(0)
    let viewportH = $state(0)
    let scrollTop = $state(0)

    const tileSize = $derived(viewportW > 0 ? (viewportW - GAP * (COLS - 1)) / COLS : 90)
    const rowHeight = $derived(tileSize + GAP)
    const totalRows = $derived(Math.ceil(entries.length / COLS))
    const startRow = $derived(Math.max(0, Math.floor(scrollTop / rowHeight) - BUFFER_ROWS))
    const endRow = $derived(Math.min(totalRows, Math.ceil((scrollTop + viewportH) / rowHeight) + BUFFER_ROWS))
    const visible = $derived(entries.slice(startRow * COLS, endRow * COLS))

    let scrollRaf = false
    function onScroll(event) {
        if (scrollRaf) return
        scrollRaf = true
        const el = event.currentTarget
        requestAnimationFrame(() => {
            scrollRaf = false
            scrollTop = el.scrollTop
        })
    }

    function resetScroll() {
        if (viewport) viewport.scrollTop = 0
        scrollTop = 0
    }

    async function loadTextures(collection, drawable, resetTexture = true) {
        const result = await fetchNui('editor:getTextures', { id: slotId, isProp, collection, drawable })
        textureCount = result?.count ?? 0
        if (resetTexture) texture = 0
    }

    async function select(entry) {
        selected = { collection: entry.collection, drawable: entry.drawable }
        texture = 0
        onselect?.(entry.collection, entry.drawable, 0)
        await loadTextures(entry.collection, entry.drawable)
    }

    function selectTexture(index) {
        texture = index
        if (selected) onselect?.(selected.collection, selected.drawable, index)
    }

    function clear() {
        selected = null
        textureCount = 0
        onselect?.(null, null, null)
    }

    const onThumbError = thumbFallback(CLOTHING_PLACEHOLDER)

    function onTileContextMenu(event, entry) {
        event.preventDefault()
        if (!editor.catalog?.canStudio) return
        fetchNui('studio:editItem', {
            id: slotId, isProp, collection: entry.collection, drawable: entry.drawable,
        })
    }
</script>

<div class="drawable-grid">
    <div class="toolbar">
        <input
            class="input"
            type="text"
            placeholder="Search number or collection..."
            bind:value={search}
            oninput={resetScroll}
        />
        <select class="input collection-select" bind:value={editor.collectionFilter} onchange={resetScroll}>
            <option value={ALL}>All collections ({totalCount})</option>
            {#each collections as group (group.collection)}
                <option value={group.collection}>{group.collection || 'base game'} ({group.count})</option>
            {/each}
        </select>
        {#if clearable}
            <button class="btn small" onclick={clear}>None</button>
        {/if}
    </div>

    {#if textureCount > 1}
        <div class="textures">
            <span class="section-title">Texture</span>
            <div class="texture-chips">
                {#each Array.from({ length: textureCount }, (_, i) => i) as i (i)}
                    <button class="chip" class:active={texture === i} onclick={() => selectTexture(i)}>{i}</button>
                {/each}
            </div>
        </div>
    {/if}

    <div
        class="viewport"
        bind:this={viewport}
        bind:clientWidth={viewportW}
        bind:clientHeight={viewportH}
        onscroll={onScroll}
    >
        <div class="spacer" style="height: {Math.max(0, totalRows * rowHeight - GAP)}px">
            <div class="window" style="transform: translateY({startRow * rowHeight}px)">
                {#each visible as entry (entry.key)}
                    <button
                        class="thumb"
                        class:selected={selected && selected.collection === entry.collection && selected.drawable === entry.drawable}
                        style="height: {tileSize}px"
                        onclick={() => select(entry)}
                        oncontextmenu={(e) => onTileContextMenu(e, entry)}
                        title={`${entry.collection || 'base'} #${entry.drawable}${editor.catalog?.canStudio ? ' — right-click: re-shoot screenshot' : ''}`}
                    >
                        <img
                            src={thumbUrl(model, isProp, slotId, entry.collection, entry.drawable)}
                            alt={String(entry.drawable)}
                            loading="lazy"
                            onerror={onThumbError}
                        />
                        <span class="num">{entry.drawable}</span>
                        {#if entry.collection && editor.collectionFilter === ALL}
                            <span class="coll">{entry.collection}</span>
                        {/if}
                    </button>
                {/each}
            </div>
        </div>
        {#if entries.length === 0}
            <div class="empty">
                {#if editor.collectionFilter !== ALL && !collections.some((g) => g.collection === editor.collectionFilter)}
                    This pack has no items for this slot
                    <button class="btn small" onclick={() => { editor.collectionFilter = ALL; resetScroll() }}>
                        Show all
                    </button>
                {:else}
                    No drawables match this filter
                {/if}
            </div>
        {/if}
    </div>
</div>

<style>
    .drawable-grid {
        display: flex;
        flex-direction: column;
        gap: 10px;
        flex: 1;
        min-height: 0;
    }

    .toolbar {
        display: flex;
        gap: 8px;
    }

    .toolbar .input {
        min-width: 0;
    }

    .collection-select {
        flex: 0 0 45%;
        cursor: pointer;
        background: var(--dark-7);
    }

    .collection-select option {
        background: var(--dark-7);
        color: var(--dark-0);
    }

    .textures {
        display: flex;
        flex-direction: column;
        gap: 4px;
        flex-shrink: 0;
    }

    .texture-chips {
        display: flex;
        flex-wrap: wrap;
        gap: 4px;
        max-height: 64px;
        overflow-y: auto;
    }

    .viewport {
        flex: 1;
        min-height: 0;
        overflow-y: auto;
        overflow-x: hidden;
    }

    .spacer {
        position: relative;
    }

    .window {
        position: absolute;
        top: 0;
        left: 0;
        right: 0;
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 6px;
        align-content: start;
    }

    .thumb {
        position: relative;
        background: var(--dark-7);
        border: 1px solid var(--border);
        border-radius: var(--radius-sm);
        cursor: pointer;
        overflow: hidden;
        padding: 0;
        transition: border-color 0.12s var(--ease);
    }

    .thumb:hover {
        border-color: var(--accent-40);
    }

    .thumb.selected {
        border-color: var(--accent);
        box-shadow: 0 0 0 1px var(--accent), 0 0 10px var(--accent-40);
    }

    .thumb img {
        width: 100%;
        height: 100%;
        object-fit: contain;
    }

    .thumb :global(img.ph) {
        object-fit: contain;
        padding: 20%;
        opacity: 0.55;
    }

    .num {
        position: absolute;
        bottom: 2px;
        right: 4px;
        font-size: 11px;
        font-weight: 600;
        color: var(--dark-0);
        text-shadow: 0 1px 2px #000;
    }

    .coll {
        position: absolute;
        top: 2px;
        left: 4px;
        right: 4px;
        font-size: 8px;
        color: var(--dark-2);
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        text-shadow: 0 1px 2px #000;
    }

    .empty {
        font-size: 12px;
        color: var(--dark-3);
        padding: 16px;
        text-align: center;
    }
</style>
