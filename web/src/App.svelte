<script>
    import { onMount } from 'svelte'
    import { onMessage, fetchNui, isBrowser, setCdnMap } from './lib/nui.js'
    import { applyTheme } from './lib/mantine.js'
    import { app, editor, studio, bag } from './lib/store.svelte.js'
    import EditorApp from './lib/editor/EditorApp.svelte'
    import StudioApp from './lib/studio/StudioApp.svelte'
    import BagApp from './lib/bag/BagApp.svelte'

    onMount(async () => {
        if (isBrowser) {
            const { bootDevMock } = await import('./lib/devmock.js')
            bootDevMock()
            return
        }
        const config = await fetchNui('getConfig')
        if (config) applyTheme(config.primaryColor, config.primaryShade)
    })

    onMessage('editor:open', (data) => {
        setCdnMap(data.cdnMap)
        editor.sections = data.sections ?? {}
        editor.charCreation = data.charCreation ?? false
        editor.catalog = data.catalog
        editor.current = data.current
        editor.category = data.charCreation ? 'dna' : 'clothing'
        editor.subcategory = null
        editor.collectionFilter = '__all__'
        app.view = 'editor'
    })
    onMessage('editor:close', () => {
        if (app.view === 'editor') app.view = null
    })

    onMessage('studio:open', (data) => {
        studio.total = data.total ?? 0
        studio.index = 0
        studio.failures = 0
        studio.item = null
        studio.paused = data.manual === true
        studio.background = 'green'
        studio.headHide = data.headHide ?? true
        studio.sections = data.sections ?? []
        studio.tuning = data.tuning ?? {}
        studio.cdn = data.cdn ?? { configured: false }
        studio.manual = data.manual === true
        studio.model = data.model ?? ''
        studio.hairColors = data.hairColors ?? []
        studio.hairColor = data.hairColor ?? 0
        studio.speed = 1
        app.view = 'studio'
    })
    onMessage('studio:tuning', (data) => {
        studio.tuning = data.tuning ?? {}
    })
    onMessage('studio:progress', (data) => {
        studio.index = data.index
        studio.total = data.total
        studio.item = data.item
        studio.failures = data.failures
        studio.empty = data.empty ?? studio.empty
    })
    onMessage('studio:close', () => {
        if (app.view === 'studio') app.view = null
    })

    onMessage('studio:process', async (data) => {
        let result
        try {
            const { processPair } = await import('./lib/studio/processor.js')
            result = await processPair(data.uri1, data.uri2, data.opaque, data.despill, data.tint)
        } catch (err) {
            result = { ok: false, error: String(err) }
        }
        fetchNui('studio:processed', { id: data.id, result })
    })

    onMessage('bag:open', (data) => {
        bag.outfits = data.outfits ?? []
        app.view = 'bag'
    })
    onMessage('bag:close', () => {
        if (app.view === 'bag') app.view = null
    })

    function onKeydown(event) {
        if (event.key === 'Escape' && app.view) {
            fetchNui('close')
        }
    }
</script>

<svelte:window onkeydown={onKeydown} oncontextmenu={(e) => e.preventDefault()} />

{#if app.view === 'editor'}
    <EditorApp />
{:else if app.view === 'studio'}
    <StudioApp />
{:else if app.view === 'bag'}
    <BagApp />
{/if}
