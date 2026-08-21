<script>
    import { onMount } from 'svelte'
    import { fetchNui } from '../nui.js'
    import Icon from './Icon.svelte'

    let outfits = $state([])
    let groupInfo = $state({ job: null, gang: null })
    let groupOutfits = $state({ job: [], gang: [] })

    let saveLabel = $state('')
    let renameId = $state(null)
    let renameLabel = $state('')

    let groupForm = $state({ type: 'job', label: '', minGrade: 0, gender: 'any' })

    async function refresh() {
        outfits = (await fetchNui('outfits:list')) ?? []
        for (const type of ['job', 'gang']) {
            const info = await fetchNui('group:info', { type })
            groupInfo[type] = info && info !== 1 ? info : null
            if (groupInfo[type]?.name) {
                groupOutfits[type] = (await fetchNui('group:list', { type })) ?? []
            }
        }
    }

    onMount(refresh)

    async function save() {
        if (!saveLabel.trim()) return
        await fetchNui('outfits:save', { label: saveLabel.trim(), kind: 'full' })
        saveLabel = ''
        refresh()
    }

    async function apply(id, part) {
        await fetchNui('outfits:apply', { id, part })
    }

    async function overwrite(id) {
        await fetchNui('outfits:overwrite', { id })
        refresh()
    }

    async function rename() {
        if (!renameLabel.trim() || renameId === null) return
        await fetchNui('outfits:rename', { id: renameId, label: renameLabel.trim() })
        renameId = null
        renameLabel = ''
        refresh()
    }

    async function remove(id) {
        await fetchNui('outfits:delete', { id })
        refresh()
    }

    let shareFor = $state(null)
    let sharePlayers = $state([])

    async function share(outfit) {
        const result = await fetchNui('outfits:share', { id: outfit.id })
        if (result?.mode === 'players' && result.players.length > 0) {
            shareFor = outfit
            sharePlayers = result.players
        }
    }

    async function shareTo(target) {
        const id = shareFor?.id
        shareFor = null
        sharePlayers = []
        if (id != null) await fetchNui('outfits:shareTo', { id, target })
    }

    async function saveGroupOutfit() {
        if (!groupForm.label.trim()) return
        await fetchNui('group:save', {
            type: groupForm.type,
            label: groupForm.label.trim(),
            minGrade: Number(groupForm.minGrade),
            gender: groupForm.gender,
        })
        groupForm.label = ''
        refresh()
    }

    async function applyGroup(type, id) {
        await fetchNui('group:apply', { type, id })
    }

    async function deleteGroup(type, id) {
        await fetchNui('group:delete', { type, id })
        refresh()
    }

    const KIND_LABELS = { full: 'Full', clothing: 'Clothing', style: 'Hair & Tattoos' }

    function gradeName(type, level) {
        const grade = groupInfo[type]?.grades?.find((g) => g.level === level)
        return grade?.name ?? `Grade ${level}`
    }
</script>

<div class="content">
    <div class="section-title">Save Current Look</div>
    <div class="save-form">
        <input class="input" type="text" placeholder="Outfit name..." bind:value={saveLabel} />
        <button class="btn primary" onclick={save}>Save Outfit</button>
    </div>

    {#if shareFor}
        <div class="share-modal">
            <div class="share-title">Share "{shareFor.label}" with…</div>
            {#each sharePlayers as player (player.id)}
                <button class="btn" onclick={() => shareTo(player.id)}>{player.name}</button>
            {/each}
            <button class="btn danger" onclick={() => { shareFor = null; sharePlayers = [] }}>Cancel</button>
        </div>
    {/if}

    <div class="section-title">My Outfits — {outfits.length}</div>
    <div class="list">
        {#each outfits as outfit (outfit.id)}
            <div class="row">
                {#if renameId === outfit.id}
                    <input class="input" type="text" bind:value={renameLabel} />
                    <button class="btn small primary" onclick={rename}>OK</button>
                    <button class="btn small" onclick={() => (renameId = null)}>✕</button>
                {:else}
                    <button class="name" onclick={() => apply(outfit.id)}>
                        {outfit.label}
                        {#if outfit.kind !== 'full'}
                            <span class="kind">{KIND_LABELS[outfit.kind]}</span>
                        {/if}
                    </button>
                    <button class="ibtn" onclick={() => apply(outfit.id, 'clothing')}>
                        <Icon name="shirt" size={14} />
                        <span class="itip">Wear clothing only</span>
                    </button>
                    <button class="ibtn" onclick={() => apply(outfit.id, 'style')}>
                        <Icon name="hair" size={14} />
                        <span class="itip">Wear hair &amp; tattoos only</span>
                    </button>
                    <button class="ibtn" onclick={() => overwrite(outfit.id)}>
                        <Icon name="save" size={14} />
                        <span class="itip">Overwrite with current look</span>
                    </button>
                    <button class="ibtn" onclick={() => share(outfit)}>
                        <Icon name="share" size={14} />
                        <span class="itip">Share this outfit</span>
                    </button>
                    <button class="ibtn" onclick={() => { renameId = outfit.id; renameLabel = outfit.label }}>
                        <Icon name="pen" size={14} />
                        <span class="itip">Rename</span>
                    </button>
                    <button class="ibtn danger" onclick={() => remove(outfit.id)}>
                        <Icon name="close" size={14} />
                        <span class="itip">Delete</span>
                    </button>
                {/if}
            </div>
        {/each}
        {#if outfits.length === 0}
            <div class="empty">No saved outfits yet</div>
        {/if}
    </div>

    {#each ['job', 'gang'] as type (type)}
        {#if groupInfo[type]?.name && groupInfo[type].name !== 'none' && (groupOutfits[type].length > 0 || groupInfo[type].isboss)}
            <div class="section-title">
                {groupInfo[type].label ?? groupInfo[type].name} Outfits ({type})
            </div>
            <div class="list">
                {#each groupOutfits[type] as outfit (outfit.id)}
                    <div class="row">
                        <button class="name" onclick={() => applyGroup(type, outfit.id)}>
                            {outfit.label}
                            <span class="kind">{gradeName(type, outfit.minGrade)}+{outfit.gender !== 'any' ? ` · ${outfit.gender}` : ''}</span>
                        </button>
                        {#if groupInfo[type].isboss}
                            <button class="btn small danger" onclick={() => deleteGroup(type, outfit.id)}>✕</button>
                        {/if}
                    </div>
                {/each}
            </div>
            {#if groupInfo[type].isboss}
                <div class="group-form">
                    <input class="input" type="text" placeholder="Preset name (uses current clothing)..."
                        bind:value={groupForm.label} onfocus={() => (groupForm.type = type)} />
                    <div class="group-controls">
                        <select class="input" bind:value={groupForm.minGrade}>
                            {#each groupInfo[type].grades ?? [] as grade (grade.level)}
                                <option value={grade.level}>Grade {grade.level} — {grade.name}</option>
                            {/each}
                        </select>
                        <select class="input" bind:value={groupForm.gender}>
                            <option value="any">Any gender</option>
                            <option value="male">Male</option>
                            <option value="female">Female</option>
                        </select>
                        <button class="btn primary small" onclick={() => { groupForm.type = type; saveGroupOutfit() }}>
                            Create
                        </button>
                    </div>
                </div>
            {/if}
        {/if}
    {/each}
</div>

<style>
    .content {
        flex: 1;
        overflow-y: auto;
        display: flex;
        flex-direction: column;
        padding-right: 4px;
    }

    .save-form {
        display: flex;
        flex-direction: column;
        gap: 8px;
        margin-bottom: 16px;
    }

    .ibtn {
        position: relative;
        width: 30px;
        height: 30px;
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

    .ibtn:hover {
        color: var(--dark-0);
        border-color: var(--accent-40);
        z-index: 30;
    }

    .ibtn.danger:hover {
        color: #ff6b6b;
        border-color: rgba(224, 49, 49, 0.6);
    }

    .itip {
        position: absolute;
        bottom: calc(100% + 8px);
        left: 50%;
        transform: translateX(-50%);
        white-space: nowrap;
        font-size: 11px;
        font-weight: 600;
        color: var(--dark-0);
        background: var(--glass-solid);
        border: 1px solid var(--border);
        border-radius: 6px;
        padding: 4px 8px;
        opacity: 0;
        pointer-events: none;
        transition: opacity 0.12s var(--ease);
    }

    .ibtn:hover .itip {
        opacity: 1;
    }

    .share-modal {
        display: flex;
        flex-direction: column;
        gap: 6px;
        background: var(--dark-8);
        border: 1px solid var(--border);
        border-radius: var(--radius-sm);
        padding: 12px;
        margin-bottom: 12px;
    }

    .share-title {
        font-size: 12px;
        font-weight: 700;
    }

    .list {
        display: flex;
        flex-direction: column;
        gap: 6px;
        margin-bottom: 16px;
    }

    .row {
        display: flex;
        align-items: center;
        gap: 6px;
    }

    .name {
        flex: 1;
        display: flex;
        align-items: center;
        gap: 8px;
        text-align: left;
        padding: 8px 10px;
        background: var(--dark-7);
        color: var(--dark-0);
        border: 1px solid var(--border);
        border-radius: var(--radius-sm);
        font-family: inherit;
        font-size: 13px;
        cursor: pointer;
        transition: border-color 0.12s var(--ease);
    }

    .name:hover {
        border-color: var(--accent);
    }

    .kind {
        font-size: 10px;
        color: var(--dark-2);
        background: var(--dark-6);
        padding: 1px 6px;
        border-radius: 999px;
    }

    .group-form {
        display: flex;
        flex-direction: column;
        gap: 6px;
        margin-bottom: 16px;
    }

    .group-controls {
        display: grid;
        grid-template-columns: 1fr 1fr auto;
        gap: 6px;
    }

    .empty {
        font-size: 12px;
        color: var(--dark-3);
        padding: 8px;
        text-align: center;
    }
</style>
