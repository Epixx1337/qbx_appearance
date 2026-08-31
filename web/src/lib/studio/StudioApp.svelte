<script>
    import { fetchNui } from '../nui.js'
    import { studio } from '../store.svelte.js'

    const BACKGROUNDS = { green: '#00ff00', blue: '#003cff', magenta: '#ff00ff', orange: '#ff8000' }
    const PARTNERS = { green: 'magenta', magenta: 'green', blue: 'orange', orange: 'blue' }

    function control(action, data = {}) {
        if (action === 'pause') studio.paused = true
        if (action === 'resume') studio.paused = false
        fetchNui('studio:control', { action, ...data })
    }

    function setBackground(color) {
        studio.background = color
        control('background', { color })
    }

    function toggleSpeed() {
        studio.speed = studio.speed === 2 ? 1 : 2
        control('speed', { value: studio.speed })
    }

    let showCdnModal = $state(false)

    const shootCategoryKey = $derived.by(() => {
        if (jumpSection) return jumpSection
        const index = Math.max(1, studio.index)
        const section = studio.sections.find((s) => index >= s.start && index < s.start + s.count)
        return section?.key ?? ''
    })

    let dlcName = $state('')
    const allCollections = $derived([...new Set(studio.sections.flatMap((s) => s.collections ?? []))])

    function cdnSync(mode) {
        showCdnModal = false
        control('cdnSync', { mode })
    }

    function setHairColor(index) {
        studio.hairColor = index
        control('hairColor', { index })
    }

    let jumpValue = $state('')
    let jumpSection = $state('')

    function selectSection(key) {
        jumpSection = key
        const section = studio.sections.find((s) => s.key === key)
        if (section) control('jump', { index: section.start })
    }

    function jump() {
        const value = parseInt(jumpValue, 10)
        if (Number.isNaN(value)) return
        const section = studio.sections.find((s) => s.key === jumpSection)
        if (section) {
            const offset = Math.max(1, Math.min(section.count, value))
            control('jump', { index: section.start + offset - 1 })
        } else {
            control('jump', { index: value })
        }
    }

    const nudge = $state({ x: 0, y: 0, z: 0, dist: 0, fov: 0 })

    let frameSection = $state('')
    let frameScope = $state('')
    const frameSectionData = $derived(studio.sections.find((s) => s.key === frameSection))
    const frameKey = $derived(
        frameSectionData ? (frameScope ? `${frameSectionData.slot}|${frameScope}` : frameSectionData.slot) : ''
    )
    const frameKeySaved = $derived(frameKey !== '' && !!studio.tuning[frameKey])
    const tune = $state({ x: 0, y: 0, z: 0, dist: 0, fov: 0 })

    $effect(() => {
        const saved = frameKey ? studio.tuning[frameKey] : null
        tune.x = saved?.x ?? 0
        tune.y = saved?.y ?? 0
        tune.z = saved?.z ?? 0
        tune.dist = saved?.dist ?? 0
        tune.fov = saved?.fov ?? 0
    })

    function savePreset() {
        if (!frameKey) return
        control('setTuning', { key: frameKey, values: { ...tune } })
    }

    function clearPreset() {
        if (!frameKeySaved) return
        control('setTuning', { key: frameKey })
    }

    function applyNudge(key, delta) {
        nudge[key] = Number((nudge[key] + delta).toFixed(2))
        control('nudge', { [key]: nudge[key] })
    }

    const progress = $derived(studio.total > 0 ? (studio.index / studio.total) * 100 : 0)

    let dragging = $state(false)
    let lastX = 0
    let lastY = 0
    let pendingDx = 0
    let pendingDy = 0
    let rafQueued = false

    function flushAdjust() {
        rafQueued = false
        if (pendingDx !== 0 || pendingDy !== 0) {
            fetchNui('studio:control', { action: 'adjust', dx: pendingDx, dy: pendingDy })
            pendingDx = 0
            pendingDy = 0
        }
    }

    function onPointerDown(event) {
        dragging = true
        lastX = event.clientX
        lastY = event.clientY
        event.currentTarget.setPointerCapture(event.pointerId)
    }

    function onPointerMove(event) {
        if (!dragging) return
        pendingDx += event.clientX - lastX
        pendingDy += event.clientY - lastY
        lastX = event.clientX
        lastY = event.clientY
        if (!rafQueued) {
            rafQueued = true
            requestAnimationFrame(flushAdjust)
        }
    }

    let wheelBusy = false
    function onWheel(event) {
        if (wheelBusy) return
        wheelBusy = true
        requestAnimationFrame(() => (wheelBusy = false))
        fetchNui('studio:control', { action: 'zoom', dir: event.deltaY > 0 ? -1 : 1 })
    }
</script>

<div
    class="camera-surface"
    class:dragging
    role="application"
    onpointerdown={onPointerDown}
    onpointermove={onPointerMove}
    onpointerup={() => (dragging = false)}
    onwheel={onWheel}
></div>

<div class="photo-frame"></div>

<div class="studio panel">
    <div class="header">
        <span class="title">Clothing Screenshot Studio</span>
        <button class="btn small danger" onclick={() => control('stop')}>Stop & Exit</button>
    </div>

    {#if !studio.headHide}
        <div class="convar-warning">
            <div class="warn-title">⚠ Face hiding is OFF</div>
            <div class="warn-body">
                Clothing shots will include the head. Before shooting, set the
                <b>client</b> convar: open the F8 console and run
                <code>allowEmptyHeadDrawable true</code>, then reopen the studio.
                To make it permanent, add <code>+set allowEmptyHeadDrawable true</code>
                to <code>%localappdata%\FiveM\FiveM.app\commandline.txt</code>.
                (<code>setr</code> in server.cfg does <b>not</b> work — it's per-client.)
            </div>
        </div>
    {/if}

    <div class="progress-row">
        <div class="bar">
            <div class="fill" style="width: {progress}%"></div>
        </div>
        <span class="counter">{studio.index} / {studio.total}</span>
    </div>

    {#if studio.item}
        <div class="item">
            {studio.item.isProp ? 'Prop' : 'Component'} {studio.item.id} ·
            {studio.item.collection || 'base'} #{studio.item.drawable}
            {#if studio.failures > 0}
                <span class="failures">{studio.failures} failed</span>
            {/if}
            {#if studio.empty > 0}
                <span class="empty-count" title="Placeholder 'none' drawables that render nothing — expected, not failures">{studio.empty} empty</span>
            {/if}
        </div>
    {/if}

    <div class="controls">
        {#if studio.paused}
            <button class="btn primary" onclick={() => control('resume')}>Resume</button>
        {:else}
            <button class="btn" onclick={() => control('pause')}>Pause</button>
        {/if}
        <button class="btn" onclick={() => control('back')}>◀ Back</button>
        <button class="btn" onclick={() => control('next')}>Next ▶</button>
        <button class="btn" class:speed-active={studio.speed === 2} onclick={toggleSpeed}
            title="Halve the settle waits between shots — slightly higher risk of soft/late frames">
            ×2
        </button>
        <button class="btn primary" onclick={() => control('shoot')}>Shoot</button>
        <button class="btn" title="Save the current framing adjustments for this slot — applied to every item of the slot, this run and future runs" onclick={() => control('saveTuning')}>
            Save framing
        </button>
        <button class="btn" title="Save the current framing for this item's collection only — overrides the category preset for that pack, here and in auto runs" onclick={() => control('saveTuning', { scope: 'collection' })}>
            Save for pack
        </button>
        {#if studio.cdn.configured && !studio.cdn.auto}
            <button class="btn" onclick={() => (showCdnModal = true)}>
                Upload to CDN
            </button>
        {/if}
    </div>

    {#if showCdnModal}
        <div class="cdn-modal">
            <div class="cdn-title">Upload screenshots to the CDN</div>
            <button class="btn primary" onclick={() => cdnSync('missing')}>
                Upload missing only
            </button>
            <div class="cdn-hint">Uploads files that have no CDN copy yet. Fast, never touches existing uploads.</div>
            <button class="btn" onclick={() => cdnSync('all')}>
                Replace all with local
            </button>
            <div class="cdn-hint">Re-uploads every local file, replacing the CDN copies — use after re-shooting.</div>
            <button class="btn danger" onclick={() => (showCdnModal = false)}>Cancel</button>
        </div>
    {/if}

    {#if studio.manual}
        <div class="model-row">
            <button class="btn small" class:speed-active={studio.model === 'mp_m_freemode_01'}
                onclick={() => control('model', { model: 'mp_m_freemode_01' })}>Male</button>
            <button class="btn small" class:speed-active={studio.model === 'mp_f_freemode_01'}
                onclick={() => control('model', { model: 'mp_f_freemode_01' })}>Female</button>
            <button class="btn small primary" disabled={!shootCategoryKey}
                title="Auto-shoot this category for both models. With a DLC selected below, only that pack's items in the category are shot."
                onclick={() => control('shootCategory', { key: shootCategoryKey, collection: dlcName || undefined })}>
                Shoot {shootCategoryKey || 'category'}{dlcName ? ` · ${dlcName}` : ''}
            </button>
        </div>
        <div class="model-row">
            <select class="input section-select" bind:value={dlcName}
                title="A clothing pack/DLC — shoots its items in every category, both models (the name is gender-mapped automatically)">
                <option value="" disabled>Shoot a DLC…</option>
                {#each allCollections as collection (collection)}
                    <option value={collection}>{collection}</option>
                {/each}
            </select>
            <button class="btn small primary" disabled={!dlcName}
                onclick={() => control('shootCollection', { name: dlcName })}>
                Shoot DLC
            </button>
        </div>
    {/if}

    {#if studio.sections.length > 0}
        <div class="jump-row">
            <select
                class="input section-select"
                value={jumpSection}
                onchange={(e) => selectSection(e.currentTarget.value)}
                title="Jump to a category — pauses on its first item, applied and framed"
            >
                <option value="" disabled>Jump to category…</option>
                {#each studio.sections as section (section.key)}
                    <option value={section.key}>{section.key} ({section.count})</option>
                {/each}
            </select>
            <input class="input jump" type="text" placeholder="#" bind:value={jumpValue} onchange={jump}
                title="Offset within the selected category (or global index if none selected)" />
        </div>
    {:else}
        <input class="input jump" type="text" placeholder="#" bind:value={jumpValue} onchange={jump} />
    {/if}

    {#if studio.manual && studio.hairColors.length > 0}
        <div class="section-title">Hair Color — {studio.hairColor}</div>
        <div class="hair-swatches">
            {#each studio.hairColors as rgb, i (i)}
                <button
                    class="hair-swatch"
                    class:active={studio.hairColor === i}
                    style="background: rgb({rgb[0]}, {rgb[1]}, {rgb[2]})"
                    title={String(i)}
                    onclick={() => setHairColor(i)}
                ></button>
            {/each}
        </div>
    {/if}

    <div class="section-title">Backdrop</div>
    <div class="backgrounds">
        {#each Object.entries(BACKGROUNDS) as [name, hex] (name)}
            <button
                class="bg"
                class:active={studio.background === name}
                style="background: {hex}"
                title="{name} (matte partner: {PARTNERS[name]})"
                onclick={() => setBackground(name)}
            ></button>
        {/each}
    </div>

    <div class="section-title">Camera Nudge</div>
    <div class="nudges">
        {#each [
            { key: 'x', label: 'X' },
            { key: 'y', label: 'Y' },
            { key: 'z', label: 'Z' },
            { key: 'dist', label: 'Dist' },
            { key: 'fov', label: 'FOV' },
        ] as axis (axis.key)}
            <div class="nudge-row">
                <span class="axis">{axis.label}</span>
                <button class="btn small" onclick={() => applyNudge(axis.key, axis.key === 'fov' ? -2 : -0.05)}>−</button>
                <span class="value">{nudge[axis.key]}</span>
                <button class="btn small" onclick={() => applyNudge(axis.key, axis.key === 'fov' ? 2 : 0.05)}>+</button>
            </div>
        {/each}
    </div>
    <div class="section-title">Framing presets</div>
    <div class="framing">
        <div class="frame-selects">
            <select class="input" bind:value={frameSection} title="Category to edit">
                <option value="" disabled>Category…</option>
                {#each studio.sections as section (section.key)}
                    <option value={section.key}>{section.key}{studio.tuning[section.slot] ? ' ●' : ''}</option>
                {/each}
            </select>
            <select class="input" bind:value={frameScope} disabled={!frameSectionData}
                title="Whole category, or override a single collection/pack">
                <option value="">Whole category</option>
                {#each frameSectionData?.collections ?? [] as collection (collection)}
                    <option value={collection}>{collection}{studio.tuning[`${frameSectionData.slot}|${collection}`] ? ' ●' : ''}</option>
                {/each}
            </select>
        </div>
        <div class="tune-grid">
            {#each [['x', 'X'], ['y', 'Y'], ['z', 'Z'], ['dist', 'Dist'], ['fov', 'FOV']] as [key, label] (key)}
                <label class="tune-field">
                    <span>{label}</span>
                    <input class="input" type="number" step={key === 'fov' ? 1 : 0.05} bind:value={tune[key]} disabled={!frameKey} />
                </label>
            {/each}
        </div>
        <div class="tune-actions">
            <button class="btn small primary" disabled={!frameKey} onclick={savePreset}>Save preset</button>
            <button class="btn small" disabled={!frameKeySaved} onclick={clearPreset}>Clear</button>
            {#if frameKeySaved}<span class="preset-tag">saved — used by auto runs</span>{/if}
        </div>
    </div>

    <div class="hint">
        Drag ←→ rotate · drag ↑↓ move in frame · scroll zoom. Each shot captures
        against two backdrops and difference-mattes them — transparent hair and
        backdrop-colored garments come out with their true colors.
    </div>
</div>

<style>
    .camera-surface {
        position: absolute;
        inset: 0;
        cursor: grab;
    }

    .camera-surface.dragging {
        cursor: grabbing;
    }

    .photo-frame {
        position: absolute;
        top: 50%;
        left: 50%;
        width: 92vh;
        height: 92vh;
        transform: translate(-50%, -50%);
        border: 2px dashed var(--accent);
        border-radius: 4px;
        pointer-events: none;
        box-shadow: 0 0 0 200vmax rgba(0, 0, 0, 0.45);
    }

    .studio {
        position: absolute;
        top: 20px;
        right: 20px;
        width: 320px;
        padding: 16px;
        display: flex;
        flex-direction: column;
        gap: 10px;
    }

    .header {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .convar-warning {
        background: rgba(250, 176, 5, 0.12);
        border: 1px solid rgba(250, 176, 5, 0.55);
        border-radius: var(--radius-sm);
        padding: 10px 12px;
    }

    .warn-title {
        font-size: 12px;
        font-weight: 700;
        color: #fab005;
        margin-bottom: 4px;
    }

    .warn-body {
        font-size: 11px;
        line-height: 1.5;
        color: var(--dark-1);
        user-select: text;
    }

    .warn-body code {
        background: var(--dark-8);
        border: 1px solid var(--border);
        border-radius: 4px;
        padding: 0 4px;
        font-size: 10px;
        color: #fab005;
    }

    .warn-body b {
        color: var(--dark-0);
    }

    .title {
        font-size: 14px;
        font-weight: 700;
    }

    .progress-row {
        display: flex;
        align-items: center;
        gap: 10px;
    }

    .bar {
        flex: 1;
        height: 6px;
        background: var(--dark-6);
        border-radius: 3px;
        overflow: hidden;
    }

    .fill {
        height: 100%;
        background: var(--accent);
        transition: width 0.2s var(--ease);
    }

    .counter {
        font-size: 12px;
        color: var(--dark-1);
        min-width: 70px;
        text-align: right;
    }

    .item {
        font-size: 12px;
        color: var(--dark-1);
        background: var(--dark-7);
        border: 1px solid var(--border);
        border-radius: var(--radius-sm);
        padding: 6px 10px;
    }

    .failures {
        color: #ff6b6b;
        margin-left: 8px;
    }

    .empty-count {
        color: var(--dark-2);
        margin-left: 8px;
    }

    .speed-active {
        background: var(--accent-25);
        border-color: var(--accent);
        color: var(--accent-light);
    }

    .controls {
        display: flex;
        gap: 6px;
        flex-wrap: wrap;
    }

    .jump {
        width: 60px;
    }

    .jump-row {
        display: flex;
        gap: 6px;
    }

    .model-row {
        display: flex;
        gap: 6px;
    }

    .hair-swatches {
        display: flex;
        flex-wrap: wrap;
        gap: 3px;
    }

    .hair-swatch {
        width: 16px;
        height: 16px;
        border: 1px solid var(--border);
        border-radius: 4px;
        cursor: pointer;
        padding: 0;
    }

    .hair-swatch.active {
        border-color: #fff;
        box-shadow: 0 0 6px var(--accent-40);
    }

    .model-row .btn {
        flex: 1;
    }

    .section-select {
        flex: 1;
        cursor: pointer;
        background: var(--dark-7);
    }

    .section-select option {
        background: var(--dark-7);
        color: var(--dark-0);
    }

    .backgrounds {
        display: flex;
        gap: 6px;
    }

    .bg {
        width: 40px;
        height: 26px;
        border: 2px solid var(--border);
        border-radius: var(--radius-sm);
        cursor: pointer;
    }

    .bg.active {
        border-color: #fff;
        box-shadow: 0 0 8px var(--accent-40);
    }

    .nudges {
        display: flex;
        flex-direction: column;
        gap: 4px;
    }

    .nudge-row {
        display: grid;
        grid-template-columns: 40px auto 1fr auto;
        align-items: center;
        gap: 6px;
    }

    .axis {
        font-size: 11px;
        font-weight: 600;
        color: var(--dark-2);
    }

    .value {
        text-align: center;
        font-size: 12px;
        color: var(--accent-light);
    }

    .hint {
        font-size: 11px;
        color: var(--dark-3);
    }

    .framing {
        display: flex;
        flex-direction: column;
        gap: 6px;
    }

    .frame-selects {
        display: flex;
        gap: 6px;
    }

    .frame-selects .input {
        flex: 1;
        min-width: 0;
        cursor: pointer;
        background: var(--dark-7);
    }

    .frame-selects option {
        background: var(--dark-7);
        color: var(--dark-0);
    }

    .tune-grid {
        display: grid;
        grid-template-columns: repeat(5, 1fr);
        gap: 4px;
    }

    .tune-field {
        display: flex;
        flex-direction: column;
        gap: 2px;
    }

    .tune-field span {
        font-size: 10px;
        color: var(--dark-3);
    }

    .tune-field .input {
        width: 100%;
        padding: 3px 4px;
        font-size: 11px;
    }

    .tune-actions {
        display: flex;
        align-items: center;
        gap: 6px;
    }

    .preset-tag {
        font-size: 10px;
        color: var(--accent-light);
    }

    .cdn-modal {
        display: flex;
        flex-direction: column;
        gap: 6px;
        background: var(--dark-8);
        border: 1px solid var(--border);
        border-radius: var(--radius-sm);
        padding: 12px;
    }

    .cdn-title {
        font-size: 12px;
        font-weight: 700;
    }

    .cdn-hint {
        font-size: 10px;
        color: var(--dark-3);
        margin-bottom: 4px;
    }
</style>
