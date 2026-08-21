<script>
    import { fetchNui } from '../nui.js'
    import { editor } from '../store.svelte.js'
    import { subcategoriesFor, slotsForGroup } from './categories.js'
    import Icon from './Icon.svelte'
    import DnaPanel from './DnaPanel.svelte'
    import HairPanel from './HairPanel.svelte'
    import ClothingPanel from './ClothingPanel.svelte'
    import TattooPanel from './TattooPanel.svelte'
    import OutfitsPanel from './OutfitsPanel.svelte'

    const mountedAt = Date.now()
    const cameraLive = () => Date.now() - mountedAt > 800

    const categories = $derived.by(() => {
        const list = []
        const s = editor.sections
        if (s.headBlend || s.faceFeatures || s.eyeColor || s.model) list.push({ key: 'dna', label: 'DNA', icon: 'dna' })
        if (s.hair || s.headOverlays) list.push({ key: 'hair', label: 'Hair & Face', icon: 'hair' })
        if (s.components || s.props) list.push({ key: 'clothing', label: 'Clothing', icon: 'shirt' })
        if (s.tattoos) list.push({ key: 'tattoos', label: 'Tattoos', icon: 'tattoo' })
        if (!editor.charCreation) list.push({ key: 'outfits', label: 'Outfits', icon: 'hanger' })
        return list
    })

    $effect(() => {
        if (categories.length && !categories.find((c) => c.key === editor.category)) {
            selectCategory(categories[0].key)
        }
    })

    const subcategories = $derived(
        subcategoriesFor(editor.category, editor.catalog, editor.sections, editor.charCreation)
    )

    $effect(() => {
        if (subcategories.length) {
            if (!subcategories.find((s) => s.key === editor.subcategory)) {
                selectSubcategory(subcategories[0])
            }
        } else if (editor.subcategory !== null) {
            editor.subcategory = null
        }
    })

    const groupSlots = $derived(
        editor.category === 'clothing'
            ? slotsForGroup(editor.subcategory, editor.catalog, editor.sections)
            : []
    )

    $effect(() => {
        if (editor.category !== 'clothing') {
            if (editor.slot !== null) editor.slot = null
            return
        }
        if (groupSlots.length && !groupSlots.find((s) => s.key === editor.slot)) {
            selectSlot(groupSlots[0])
        }
    })

    function selectSubcategory(sub) {
        editor.subcategory = sub.key
        if (!cameraLive()) return
        if (sub.zone) {
            fetchNui('camera:tattooZone', { zone: sub.zone, back: sub.back ?? false })
        } else if (sub.camera) {
            fetchNui('camera:preset', { name: sub.camera })
        }
    }

    function selectSlot(slot) {
        editor.slot = slot.key
        if (cameraLive()) fetchNui('camera:preset', { name: slot.camera })
    }

    const undressActions = [
        { key: 'torso', label: 'Undress Torso', icon: 'shirt' },
        { key: 'pants', label: 'Undress Pants', icon: 'pants' },
        { key: 'shoes', label: 'Remove Shoes', icon: 'shoe' },
        { key: 'accessories', label: 'Remove Accessories', icon: 'watch' },
    ]

    const CENTER_X = 42
    const arc = (items, radius, spreadDeg) =>
        items.map((item, i) => {
            const t = items.length === 1 ? 0.5 : i / (items.length - 1)
            const angle = ((-spreadDeg / 2 + spreadDeg * t) * Math.PI) / 180
            return {
                ...item,
                x: `calc(${CENTER_X}% - ${Math.round(Math.cos(angle) * radius)}px)`,
                y: `calc(50% + ${Math.round(Math.sin(angle) * radius)}px)`,
            }
        })

    const mirror = (badges) => badges.map((b) => ({ ...b, x: b.x.replace('% - ', '% + ') }))

    const categoryBadges = $derived(arc(categories, 400, 95))
    const undressBadges = $derived(arc(undressActions, 520, 70))
    const subcategoryBadges = $derived(
        mirror(arc(subcategories, 400, Math.min(115, 22 + subcategories.length * 14)))
    )
    const slotBadges = $derived(
        mirror(arc(groupSlots, 520, Math.min(95, 18 + groupSlots.length * 13)))
    )

    function selectCategory(key) {
        editor.category = key
        if (!cameraLive()) return
        const presets = { dna: 'face', hair: 'hair', clothing: 'full', tattoos: 'full', outfits: 'full' }
        fetchNui('camera:preset', { name: presets[key] ?? 'full' })
    }

    let undressActive = $state({})

    async function undress(what) {
        const result = await fetchNui('editor:undress', { what })
        undressActive[what] = result?.active === true
    }

    let spotlight = $state(false)
    let poseIndex = $state(0)
    let showHelp = $state(false)
    const poses = $derived(editor.catalog?.poses ?? ['Idle'])

    function toggleSpotlight() {
        spotlight = !spotlight
        fetchNui('editor:spotlight', { on: spotlight })
    }

    function cyclePose() {
        poseIndex = (poseIndex + 1) % poses.length
        fetchNui('editor:pose', { index: poseIndex + 1 })
    }

    let dragging = $state(false)
    let dragButton = 0
    let lastX = 0
    let lastY = 0
    let pendingDx = 0
    let pendingDy = 0
    let rafQueued = false

    function flushRotate() {
        rafQueued = false
        if (pendingDx !== 0 || pendingDy !== 0) {
            fetchNui('camera:rotate', { dx: pendingDx, dy: pendingDy })
            pendingDx = 0
            pendingDy = 0
        }
    }

    function onPointerDown(event) {
        dragging = true
        dragButton = event.button
        lastX = event.clientX
        lastY = event.clientY
        event.currentTarget.setPointerCapture(event.pointerId)
    }

    function onPointerMove(event) {
        if (!dragging) return
        if (dragButton === 2) {
            pendingDx += event.clientX - lastX
        } else {
            pendingDy += event.clientY - lastY
        }
        lastX = event.clientX
        lastY = event.clientY
        if (!rafQueued) {
            rafQueued = true
            requestAnimationFrame(flushRotate)
        }
    }

    function onPointerUp() {
        dragging = false
    }

    function onWheel(event) {
        fetchNui('camera:zoom', {
            dir: event.deltaY > 0 ? -1 : 1,
            y: event.clientY / window.innerHeight,
        })
    }
</script>

<div class="editor">
    <div
        class="camera-surface"
        class:dragging
        role="application"
        onpointerdown={onPointerDown}
        onpointermove={onPointerMove}
        onpointerup={onPointerUp}
        onwheel={onWheel}
    ></div>

    <div class="badges">
        {#each undressBadges as badge (badge.key)}
            <button
                class="badge small"
                class:active={undressActive[badge.key]}
                style="left: {badge.x}; top: {badge.y}"
                onclick={() => undress(badge.key)}
            >
                <span class="inner strike"><Icon name={badge.icon} size={17} /></span>
                <span class="tip">{undressActive[badge.key] ? badge.label.replace('Undress', 'Re-dress') : badge.label}</span>
            </button>
        {/each}
        {#each categoryBadges as badge (badge.key)}
            <button
                class="badge"
                class:active={editor.category === badge.key}
                style="left: {badge.x}; top: {badge.y}"
                onclick={() => selectCategory(badge.key)}
            >
                <span class="inner"><Icon name={badge.icon} /></span>
                <span class="tip">{badge.label}</span>
            </button>
        {/each}
        {#each subcategoryBadges as badge (editor.category + badge.key)}
            <button
                class="badge flip"
                class:active={editor.subcategory === badge.key}
                style="left: {badge.x}; top: {badge.y}"
                onclick={() => selectSubcategory(badge)}
            >
                <span class="inner"><Icon name={badge.icon} size={19} /></span>
                <span class="tip">{badge.label}</span>
            </button>
        {/each}
        {#each slotBadges as badge (editor.subcategory + badge.key)}
            <button
                class="badge small flip"
                class:active={editor.slot === badge.key}
                style="left: {badge.x}; top: {badge.y}"
                onclick={() => selectSlot(badge)}
            >
                <span class="inner"><Icon name={badge.icon} size={16} /></span>
                <span class="tip">{badge.label}</span>
            </button>
        {/each}
    </div>

    <div class="tools panel">
        <button class="tool" class:lit={spotlight} onclick={toggleSpotlight}>
            <Icon name="spotlight" size={17} />
            <span class="tip">Spotlight</span>
        </button>
        <button class="tool" onclick={cyclePose}>
            <Icon name="pose" size={17} />
            <span class="tip">Pose: {poses[poseIndex] ?? 'Idle'}</span>
        </button>
        <button class="tool" onclick={() => fetchNui('camera:flip')}>
            <Icon name="flip" size={17} />
            <span class="tip">Flip side</span>
        </button>
        <button class="tool" class:lit={showHelp} onclick={() => (showHelp = !showHelp)}>
            <span class="qmark">?</span>
            <span class="tip">Help</span>
        </button>
    </div>

    {#if showHelp}
        <div class="help-overlay" onclick={() => (showHelp = false)} role="presentation">
            <div class="help panel" onclick={(e) => e.stopPropagation()} role="dialog">
                <div class="help-head">
                    <span>Controls</span>
                    <button class="btn small" onclick={() => (showHelp = false)}>✕</button>
                </div>
                <div class="help-body">
                    <div><b>Right-drag</b> — orbit around the character</div>
                    <div><b>Left-drag up/down</b> — move the view along the body</div>
                    <div><b>Scroll</b> — zoom toward whatever the cursor is over</div>
                    <div><b><Icon name="spotlight" size={13} /> Spotlight</b> — light the character</div>
                    <div><b><Icon name="pose" size={13} /> Pose</b> — cycle preview poses to check clipping</div>
                    <div><b><Icon name="flip" size={13} /> Flip</b> — jump to the opposite side (ears, back)</div>
                    <div><b>Diamonds left</b> — categories & undress shortcuts</div>
                    <div><b>Diamonds right</b> — subcategories of the selection</div>
                    <div><b>ESC</b> — cancel without saving</div>
                </div>
            </div>
        </div>
    {/if}

    <div class="right-side">
        <div class="right-panel panel">
            {#if editor.category === 'dna'}
                <DnaPanel />
            {:else if editor.category === 'hair'}
                <HairPanel />
            {:else if editor.category === 'clothing'}
                <ClothingPanel />
            {:else if editor.category === 'tattoos'}
                <TattooPanel />
            {:else if editor.category === 'outfits'}
                <OutfitsPanel />
            {/if}
        </div>
        <div class="actions panel">
            <button class="btn danger" onclick={() => fetchNui('editor:cancel')}>
                <Icon name="close" size={15} /> Cancel
            </button>
            <button class="btn primary grow" onclick={() => fetchNui('editor:save')}>
                <Icon name="save" size={15} /> {editor.charCreation ? 'Create Character' : 'Save'}
            </button>
        </div>
    </div>
</div>

<style>
    .editor {
        position: absolute;
        inset: 0;
    }

    .camera-surface {
        position: absolute;
        inset: 0;
        cursor: grab;
    }

    .camera-surface.dragging {
        cursor: grabbing;
    }

    .badges {
        position: absolute;
        inset: 0;
        pointer-events: none;
    }

    .badge {
        position: absolute;
        transform: translate(-50%, -50%);
        pointer-events: auto;
        width: 52px;
        height: 52px;
        padding: 0;
        background: transparent;
        border: none;
        cursor: pointer;
        color: var(--dark-1);
        z-index: 1;
    }

    .badge.active {
        z-index: 20;
    }

    .badge:hover {
        z-index: 40;
    }

    .badge .inner {
        position: absolute;
        inset: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        background: var(--glass-solid);
        border: 1px solid var(--border);
        border-radius: var(--radius-sm);
        transform: rotate(45deg);
        transition: all 0.15s var(--ease);
        box-shadow: var(--shadow);
    }

    .badge .inner :global(svg) {
        transform: rotate(-45deg);
    }

    .badge.small {
        width: 40px;
        height: 40px;
    }

    .badge .strike::after {
        content: '';
        position: absolute;
        width: 68%;
        height: 1.5px;
        background: rgba(224, 49, 49, 0.85);
        transform: rotate(0deg);
        border-radius: 1px;
    }

    .badge:hover {
        color: var(--dark-0);
    }

    .badge:hover .inner {
        border-color: var(--accent-40);
        transform: rotate(45deg) scale(1.08);
    }

    .badge.active {
        color: var(--accent-light);
    }

    .badge.active .inner {
        background: var(--accent-25);
        border-color: var(--accent);
    }

    .tip {
        position: absolute;
        top: 50%;
        left: calc(100% + 14px);
        transform: translateY(-50%);
        white-space: nowrap;
        font-size: 11px;
        font-weight: 600;
        letter-spacing: 0.06em;
        text-transform: uppercase;
        color: var(--dark-0);
        background: var(--glass-solid);
        border: 1px solid var(--border);
        border-radius: 6px;
        padding: 4px 8px;
        opacity: 0;
        pointer-events: none;
        transition: opacity 0.12s var(--ease);
    }

    .badge:hover .tip {
        opacity: 1;
    }

    .badge.flip .tip {
        left: auto;
        right: calc(100% + 14px);
    }

    .right-side {
        position: absolute;
        top: 20px;
        right: 20px;
        bottom: 20px;
        width: 420px;
        display: flex;
        flex-direction: column;
        gap: 10px;
    }

    .right-panel {
        flex: 1;
        min-height: 0;
        overflow: hidden;
        display: flex;
        flex-direction: column;
        padding: 16px;
    }

    .actions {
        display: flex;
        gap: 8px;
        padding: 10px 12px;
    }

    .actions .grow {
        flex: 1;
    }

    .tools {
        position: absolute;
        top: 20px;
        left: 20px;
        display: flex;
        flex-direction: column;
        gap: 6px;
        padding: 8px;
    }

    .tool {
        position: relative;
        width: 40px;
        height: 40px;
        display: flex;
        align-items: center;
        justify-content: center;
        background: var(--dark-7);
        color: var(--dark-1);
        border: 1px solid var(--border);
        border-radius: var(--radius-sm);
        cursor: pointer;
        transition: all 0.12s var(--ease);
    }

    .tool:hover {
        color: var(--dark-0);
        border-color: var(--accent-40);
        z-index: 30;
    }

    .tool:hover .tip {
        opacity: 1;
    }

    .tool.lit {
        background: var(--accent-25);
        border-color: var(--accent);
        color: var(--accent-light);
    }

    .qmark {
        font-size: 17px;
        font-weight: 700;
    }

    .help-overlay {
        position: absolute;
        inset: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        background: rgba(0, 0, 0, 0.35);
        z-index: 10;
    }

    .help {
        width: 340px;
        padding: 16px;
    }

    .help-head {
        display: flex;
        justify-content: space-between;
        align-items: center;
        font-size: 14px;
        font-weight: 700;
        margin-bottom: 12px;
    }

    .help-body {
        display: flex;
        flex-direction: column;
        gap: 8px;
        font-size: 12px;
        color: var(--dark-1);
    }

    .help-body b {
        color: var(--dark-0);
        font-weight: 600;
    }
</style>
