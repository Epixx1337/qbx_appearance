<script>
    import { fetchNui, faceThumbUrl, pedThumbUrl, thumbFallback, FACE_PLACEHOLDER } from '../nui.js'
    import { editor } from '../store.svelte.js'
    import FeatureGrid from './FeatureGrid.svelte'

    const catalog = $derived(editor.catalog)
    const female = $derived(editor.catalog?.model === 'mp_f_freemode_01')

    const tab = $derived(editor.subcategory ?? 'heritage')

    const blend = $state({
        shapeFirst: 0, shapeSecond: 0, shapeThird: 0,
        skinFirst: 0, skinSecond: 0, skinThird: 0,
        shapeMix: 0.5, skinMix: 0.5, thirdMix: 0.0,
    })

    $effect.pre(() => {
        const current = editor.current?.headBlend
        if (current) Object.assign(blend, current)
    })

    function pushBlend() {
        fetchNui('editor:setHeadBlend', { ...blend })
    }

    const features = $state(Array(20).fill(0))
    $effect.pre(() => {
        const current = editor.current?.faceFeatures
        if (current) current.forEach((v, i) => (features[i] = v ?? 0))
    })

    const pads = [
        { label: 'Eyebrows', xi: 7, yi: 6, xMin: 'Back', xMax: 'Forward', yMin: 'Lower', yMax: 'Higher' },
        { label: 'Nose', xi: 0, yi: 2, xMin: 'Narrow', xMax: 'Wide', yMin: 'Short', yMax: 'Long' },
        { label: 'Nose Tip', xi: 5, yi: 1, xMin: 'Twist L', xMax: 'Twist R', yMin: 'Down', yMax: 'Up' },
        { label: 'Nose Profile', xi: 3, yi: 4, xMin: 'Bone Low', xMax: 'Bone High', yMin: 'Tip Up', yMax: 'Tip Low' },
        { label: 'Cheekbones', xi: 9, yi: 8, xMin: 'Narrow', xMax: 'Wide', yMin: 'Low', yMax: 'High' },
        { label: 'Cheeks & Eyes', xi: 10, yi: 11, xMin: 'Gaunt', xMax: 'Puffed', yMin: 'Squint', yMax: 'Open' },
        { label: 'Lips & Jaw', xi: 13, yi: 12, xMin: 'Narrow', xMax: 'Wide', yMin: 'Thin', yMax: 'Full' },
        { label: 'Jaw & Chin', xi: 14, yi: 15, xMin: 'Short', xMax: 'Long', yMin: 'Chin Up', yMax: 'Chin Low' },
        { label: 'Chin Shape', xi: 17, yi: 16, xMin: 'Narrow', xMax: 'Wide', yMin: 'Short', yMax: 'Long' },
        { label: 'Dimple & Neck', xi: 18, yi: 19, xMin: 'Smooth', xMax: 'Dimple', yMin: 'Thin', yMax: 'Thick' },
    ]

    function setFeaturePair(pad, x, y) {
        features[pad.xi] = x
        features[pad.yi] = y
        fetchNui('editor:setFaceFeature', { index: pad.xi, value: x })
        fetchNui('editor:setFaceFeature', { index: pad.yi, value: y })
    }

    let eyeColor = $state(0)
    $effect.pre(() => {
        eyeColor = editor.current?.eyeColor ?? 0
    })

    function setEyeColor(index) {
        eyeColor = index
        fetchNui('editor:setEyeColor', { index })
    }

    async function setModel(model) {
        const catalogUpdate = await fetchNui('editor:setModel', { model })
        if (catalogUpdate && catalogUpdate !== 1) {
            editor.catalog = catalogUpdate
            editor.current = null
        }
    }

    const range = (n) => Array.from({ length: n }, (_, i) => i)

    const onThumbError = thumbFallback(FACE_PLACEHOLDER)
</script>

<div class="content">
    {#if tab === 'model' && catalog}
        <div class="section-title">Ped Model — {catalog.models.length}</div>
        <div class="model-grid">
            {#each catalog.models as model (model)}
                <button
                    class="model-tile"
                    class:selected={catalog.model === model}
                    onclick={() => setModel(model)}
                    title={model}
                >
                    <img src={pedThumbUrl(model)} alt={model} loading="lazy" onerror={onThumbError} />
                    <span class="model-name">{model}</span>
                </button>
            {/each}
        </div>
    {:else if tab === 'heritage' && catalog}
        {#each [
            { key: 'shapeFirst', title: 'Primary Face', kind: 'face', count: catalog.faceShapes },
            { key: 'shapeSecond', title: 'Secondary Face', kind: 'face', count: catalog.faceShapes },
            { key: 'skinFirst', title: 'Primary Skin Tone', kind: female ? 'f_skin' : 'm_skin', count: catalog.skinTones },
            { key: 'skinSecond', title: 'Secondary Skin Tone', kind: female ? 'f_skin' : 'm_skin', count: catalog.skinTones },
        ] as group (group.key)}
            <div class="section-title">{group.title} — {blend[group.key]} / {group.count - 1}</div>
            <div class="thumb-grid">
                {#each range(group.count) as i (i)}
                    <button
                        class="thumb"
                        class:selected={blend[group.key] === i}
                        onclick={() => { blend[group.key] = i; pushBlend() }}
                    >
                        <img src={faceThumbUrl(group.kind, i)} alt={String(i)} loading="lazy" onerror={onThumbError} />
                        <span>{i}</span>
                    </button>
                {/each}
            </div>
        {/each}

        <div class="section-title">Face Mixing</div>
        {#each [
            { key: 'shapeMix', label: 'Shape Mix' },
            { key: 'skinMix', label: 'Color Mix' },
            { key: 'thirdMix', label: 'Third Mix' },
        ] as mix (mix.key)}
            <label class="slider-row">
                <span>{mix.label}</span>
                <input
                    type="range" min="0" max="1" step="0.01"
                    value={blend[mix.key]}
                    oninput={(e) => { blend[mix.key] = Number(e.currentTarget.value); pushBlend() }}
                />
                <span class="value">{Math.round(blend[mix.key] * 100)}</span>
            </label>
        {/each}
    {:else if tab === 'features'}
        <div class="pad-grid">
            {#each pads as pad (pad.label)}
                <FeatureGrid
                    label={pad.label}
                    xMin={pad.xMin} xMax={pad.xMax} yMin={pad.yMin} yMax={pad.yMax}
                    x={features[pad.xi]} y={features[pad.yi]}
                    onchange={(x, y) => setFeaturePair(pad, x, y)}
                />
            {/each}
        </div>
    {:else if tab === 'eyes' && catalog}
        <div class="section-title">Eye Color — {eyeColor} / {catalog.eyeColors - 1}</div>
        <div class="thumb-grid">
            {#each range(catalog.eyeColors) as i (i)}
                <button class="thumb" class:selected={eyeColor === i} onclick={() => setEyeColor(i)}>
                    <img src={faceThumbUrl('eye', i)} alt={String(i)} loading="lazy" onerror={onThumbError} />
                    <span>{i}</span>
                </button>
            {/each}
        </div>
    {/if}
</div>

<style>
    .content {
        flex: 1;
        overflow-y: auto;
        padding-right: 4px;
    }

    .model-grid {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 8px;
    }

    .model-tile {
        position: relative;
        aspect-ratio: 3 / 4;
        background: var(--dark-7);
        border: 1px solid var(--border);
        border-radius: var(--radius-sm);
        cursor: pointer;
        overflow: hidden;
        padding: 0;
        transition: border-color 0.12s var(--ease);
    }

    .model-tile:hover {
        border-color: var(--accent-40);
    }

    .model-tile.selected {
        border-color: var(--accent);
        box-shadow: 0 0 0 1px var(--accent), 0 0 10px var(--accent-40);
    }

    .model-tile img {
        width: 100%;
        height: 100%;
        object-fit: cover;
    }

    .model-tile :global(img.ph) {
        object-fit: contain;
        padding: 26%;
        opacity: 0.55;
    }

    .model-name {
        position: absolute;
        left: 0;
        right: 0;
        bottom: 0;
        padding: 3px 5px;
        font-size: 9px;
        color: var(--dark-0);
        background: rgba(0, 0, 0, 0.55);
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .thumb-grid {
        display: grid;
        grid-template-columns: repeat(5, 1fr);
        gap: 6px;
        margin-bottom: 14px;
    }

    .thumb {
        position: relative;
        aspect-ratio: 1;
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
        object-fit: cover;
    }

    .thumb :global(img.ph) {
        object-fit: contain;
        padding: 22%;
        opacity: 0.55;
    }

    .thumb span {
        position: absolute;
        bottom: 2px;
        right: 4px;
        font-size: 10px;
        color: var(--dark-1);
        text-shadow: 0 1px 2px #000;
    }

    .slider-row {
        display: grid;
        grid-template-columns: 90px 1fr 34px;
        align-items: center;
        gap: 10px;
        margin-bottom: 10px;
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

    .pad-grid {
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: 14px;
    }
</style>
