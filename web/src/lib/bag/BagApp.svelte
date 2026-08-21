<script>
    import { fetchNui } from '../nui.js'
    import { bag } from '../store.svelte.js'

    const KIND_LABELS = { full: 'Full outfit', clothing: 'Clothing only', style: 'Hair & tattoos' }

    function pick(id) {
        fetchNui('bag:pick', { id })
    }
</script>

<div class="overlay">
    <div class="bag panel">
        <div class="header">
            <span class="title">Clothing Bag</span>
            <button class="btn small" onclick={() => pick(null)}>Close</button>
        </div>
        <div class="list">
            {#each bag.outfits as outfit (outfit.id)}
                <button class="outfit" onclick={() => pick(outfit.id)}>
                    <span class="name">{outfit.label}</span>
                    <span class="kind">{KIND_LABELS[outfit.kind] ?? outfit.kind}</span>
                </button>
            {/each}
        </div>
    </div>
</div>

<style>
    .overlay {
        position: absolute;
        inset: 0;
        display: flex;
        align-items: center;
        justify-content: center;
    }

    .bag {
        width: 360px;
        max-height: 60vh;
        padding: 16px;
        display: flex;
        flex-direction: column;
        gap: 12px;
    }

    .header {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .title {
        font-size: 15px;
        font-weight: 700;
    }

    .list {
        overflow-y: auto;
        display: flex;
        flex-direction: column;
        gap: 6px;
    }

    .outfit {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 10px 12px;
        background: var(--dark-7);
        color: var(--dark-0);
        border: 1px solid var(--border);
        border-radius: var(--radius-sm);
        font-family: inherit;
        font-size: 13px;
        cursor: pointer;
        transition: border-color 0.12s var(--ease);
    }

    .outfit:hover {
        border-color: var(--accent);
        background: var(--accent-8);
    }

    .kind {
        font-size: 11px;
        color: var(--dark-2);
    }
</style>
