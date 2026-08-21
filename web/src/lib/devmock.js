import { app, editor, studio, bag } from './store.svelte.js'
import { applyTheme } from './mantine.js'

function mockCollections(count, extra) {
    const groups = [{ collection: '', count }]
    if (extra) groups.push({ collection: extra, count: 12 })
    return groups
}

export function bootDevMock() {
    applyTheme('blue', 8)
    document.body.style.background =
        'radial-gradient(circle at 40% 40%, #3d4450 0%, #14161a 70%)'

    editor.sections = {
        model: true, headBlend: true, faceFeatures: true, headOverlays: true,
        eyeColor: true, hair: true, components: true, props: true, tattoos: true,
    }
    editor.charCreation = false
    editor.catalog = {
        model: 'mp_m_freemode_01',
        freemode: true,
        models: ['mp_m_freemode_01', 'mp_f_freemode_01'],
        components: {
            1: mockCollections(60, 'mp_heist'), 3: mockCollections(100), 4: mockCollections(80, 'custom_pack_1'),
            5: mockCollections(40), 6: mockCollections(70), 7: mockCollections(30),
            8: mockCollections(90), 9: mockCollections(20), 10: mockCollections(15),
            11: mockCollections(700, 'custom_pack_1'),
        },
        props: {
            0: mockCollections(50, 'mp_biker'), 1: mockCollections(30), 2: mockCollections(20),
            6: mockCollections(15), 7: mockCollections(12),
        },
        overlays: { 0: 12, 1: 29, 2: 34, 3: 15, 4: 25, 5: 7, 6: 12, 7: 11, 8: 10, 9: 18, 10: 17, 11: 12 },
        hairColors: Array.from({ length: 64 }, (_, i) => {
            const t = i / 63
            return [Math.round(40 + 180 * t), Math.round(28 + 90 * (1 - t)), Math.round(20 + 60 * Math.abs(0.5 - t))]
        }),
        makeupColors: Array.from({ length: 64 }, (_, i) => {
            const t = i / 63
            return [Math.round(120 + 120 * t), Math.round(40 + 60 * (1 - t)), Math.round(80 + 100 * Math.abs(0.5 - t))]
        }),
        eyeColors: 32,
        faceShapes: 46,
        skinTones: 46,
        maxTattoos: 24,
        freemodeOnly: false,
        canStudio: true,
        poses: ['Idle', 'Hands Up', 'Flex', 'Sit', 'Lean'],
        tattoos: [
            { index: 1, overlay: 'MP_Bea_M_Chest_000', collection: 'mpbeach_overlays', zone: 'ZONE_TORSO', label: 'Flower Chain' },
            { index: 2, overlay: 'MP_Bea_M_Chest_001', collection: 'mpbeach_overlays', zone: 'ZONE_TORSO', label: 'Tribal Chest' },
            { index: 3, overlay: 'MP_Bea_M_Back_000', collection: 'mpbeach_overlays', zone: 'ZONE_TORSO', label: 'Back Tribal' },
            { index: 4, overlay: 'MP_Bea_M_RArm_000', collection: 'mpbeach_overlays', zone: 'ZONE_RIGHT_ARM', label: 'Arm Tribal' },
            { index: 5, overlay: 'MP_Bea_M_LArm_000', collection: 'mpbeach_overlays', zone: 'ZONE_LEFT_ARM', label: 'Arm Band' },
            { index: 6, overlay: 'MP_Bea_M_Head_000', collection: 'mpbeach_overlays', zone: 'ZONE_HEAD', label: 'Dolphin' },
        ],
        hairFades: [
            { collection: 'multiplayer_overlays', overlay: 'NG_M_Hair_001', label: 'Fade 1' },
            { collection: 'multiplayer_overlays', overlay: 'NG_M_Hair_002', label: 'Fade 2' },
            { collection: 'multiplayer_overlays', overlay: 'NG_M_Hair_003', label: 'Fade 3' },
        ],
    }
    editor.current = {
        model: 'mp_m_freemode_01',
        headBlend: { shapeFirst: 21, shapeSecond: 4, shapeThird: 0, skinFirst: 21, skinSecond: 4, skinThird: 0, shapeMix: 0.5, skinMix: 0.5, thirdMix: 0 },
        faceFeatures: Array(20).fill(0),
        headOverlays: { 1: { style: 10, opacity: 0.9, firstColor: 0 }, 2: { style: 4, opacity: 1, firstColor: 0 } },
        eyeColor: 3,
        hair: { collection: '', drawable: 14, texture: 0, color: 5, highlight: 12, fade: null },
        components: {
            4: { collection: '', drawable: 21, texture: 0 },
            6: { collection: '', drawable: 34, texture: 0 },
            11: { collection: 'custom_pack_1', drawable: 2, texture: 1 },
        },
        props: { 0: { collection: 'mp_biker', drawable: 3, texture: 0 } },
        tattoos: [
            { overlay: 'MP_Bea_M_RArm_000', collection: 'mpbeach_overlays', zone: 'ZONE_RIGHT_ARM', opacity: 1.0, label: 'Arm Tribal' },
            { overlay: 'MP_Bea_M_RArm_000', collection: 'mpbeach_overlays', zone: 'ZONE_RIGHT_ARM', opacity: 0.4, label: 'Arm Tribal' },
        ],
    }
    editor.category = 'clothing'
    app.view = 'editor'

    window.__preview = (view) => {
        if (view === 'studio') {
            studio.total = 812
            studio.index = 341
            studio.failures = 3
            studio.item = { id: 11, isProp: false, collection: 'custom_pack_1', drawable: 17 }
            studio.background = 'auto'
            studio.headHide = false
        } else if (view === 'bag') {
            bag.outfits = [
                { id: 1, label: 'Street Fit', kind: 'full' },
                { id: 2, label: 'Work Uniform', kind: 'clothing' },
                { id: 3, label: 'Fresh Cut', kind: 'style' },
            ]
        }
        app.view = view
    }
}
