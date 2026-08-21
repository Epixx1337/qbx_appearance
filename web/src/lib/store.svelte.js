export const app = $state({
    view: null,
})

export const editor = $state({
    sections: {},
    charCreation: false,
    catalog: null,
    current: null,
    category: 'clothing',
    subcategory: null,
    slot: null,
    collectionFilter: '__all__',
})

export const studio = $state({
    total: 0,
    index: 0,
    failures: 0,
    empty: 0,
    item: null,
    paused: false,
    background: 'green',
    headHide: true,
    speed: 1,
    sections: [],
    tuning: {},
    cdn: { configured: false, auto: false },
    manual: false,
    model: '',
})

export const bag = $state({
    outfits: [],
})
