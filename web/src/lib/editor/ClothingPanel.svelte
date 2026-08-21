<script>
    import { fetchNui } from '../nui.js'
    import { editor } from '../store.svelte.js'
    import { slotsForGroup } from './categories.js'
    import DrawableGrid from './DrawableGrid.svelte'

    const catalog = $derived(editor.catalog)
    const slots = $derived(slotsForGroup(editor.subcategory, catalog, editor.sections))
    const active = $derived(slots.find((s) => s.key === editor.slot) ?? slots[0])

    function currentFor(slot) {
        if (!slot || !editor.current) return null
        const source = slot.prop ? editor.current.props : editor.current.components
        return source?.[String(slot.id)] ?? null
    }

    function onselect(collection, drawable, texture) {
        if (!active) return
        if (active.prop) {
            if (collection === null) {
                fetchNui('editor:setProp', { id: active.id, clear: true })
            } else {
                fetchNui('editor:setProp', { id: active.id, collection, drawable, texture })
            }
        } else if (collection !== null) {
            fetchNui('editor:setComponent', { id: active.id, collection, drawable, texture })
        }
    }
</script>

{#if active}
    <div class="slot-title section-title">{active.label}</div>
    {#key active.key + (active.prop ? 'p' : 'c')}
        <DrawableGrid
            slotId={active.id}
            isProp={active.prop ?? false}
            collections={(active.prop
                ? catalog?.props?.[String(active.id)]
                : catalog?.components?.[String(active.id)]) ?? []}
            current={currentFor(active)}
            clearable={active.prop ?? false}
            {onselect}
        />
    {/key}
{/if}

<style>
    .slot-title {
        margin-bottom: 10px;
    }
</style>
