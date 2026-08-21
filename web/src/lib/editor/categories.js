export const CLOTHING_SLOTS = [
    { key: 'tops', label: 'Tops', id: 11, icon: 'shirt', camera: 'torso' },
    { key: 'undershirts', label: 'Undershirts', id: 8, icon: 'tank', camera: 'torso' },
    { key: 'arms', label: 'Arms & Gloves', id: 3, icon: 'glove', camera: 'arms' },
    { key: 'pants', label: 'Pants', id: 4, icon: 'pants', camera: 'pants' },
    { key: 'shoes', label: 'Shoes', id: 6, icon: 'shoe', camera: 'shoes' },
    { key: 'masks', label: 'Masks', id: 1, icon: 'mask', camera: 'mask' },
    { key: 'accessories', label: 'Chains & Scarfs', id: 7, icon: 'chain', camera: 'torso' },
    { key: 'bags', label: 'Bags', id: 5, icon: 'bag', camera: 'bag' },
    { key: 'armor', label: 'Body Armor', id: 9, icon: 'vest', camera: 'torso' },
    { key: 'decals', label: 'Decals', id: 10, icon: 'decal', camera: 'torso' },
    { key: 'hats', label: 'Hats', id: 0, prop: true, icon: 'hat', camera: 'hat' },
    { key: 'glasses', label: 'Glasses', id: 1, prop: true, icon: 'glasses', camera: 'glasses' },
    { key: 'ears', label: 'Earrings', id: 2, prop: true, icon: 'earring', camera: 'ears' },
    { key: 'watches', label: 'Watches', id: 6, prop: true, icon: 'watch', camera: 'watch' },
    { key: 'bracelets', label: 'Bracelets', id: 7, prop: true, icon: 'bracelet', camera: 'bracelet' },
]

export const CLOTHING_GROUPS = [
    { key: 'upper', label: 'Upper Body', icon: 'shirt',
      slots: ['tops', 'undershirts', 'arms', 'armor'] },
    { key: 'accessories', label: 'Accessories & Bags', icon: 'bag',
      slots: ['bags', 'accessories', 'decals'] },
    { key: 'lower', label: 'Lower Body', icon: 'pants', slots: ['pants', 'shoes'] },
    { key: 'head', label: 'Head & Face', icon: 'face', slots: ['masks', 'glasses', 'hats', 'ears'] },
    { key: 'wrists', label: 'Wrists', icon: 'watch', slots: ['watches', 'bracelets'] },
]

export const TATTOO_ZONES = [
    { key: 'ZONE_TORSO', label: 'Torso', icon: 'vest', zone: 'ZONE_TORSO' },
    { key: 'ZONE_BACK', label: 'Back', icon: 'pose', zone: 'ZONE_TORSO', back: true },
    { key: 'ZONE_HEAD', label: 'Head', icon: 'face', zone: 'ZONE_HEAD' },
    { key: 'ZONE_LEFT_ARM', label: 'Left Arm', icon: 'glove', zone: 'ZONE_LEFT_ARM' },
    { key: 'ZONE_RIGHT_ARM', label: 'Right Arm', icon: 'glove', zone: 'ZONE_RIGHT_ARM' },
    { key: 'ZONE_LEFT_LEG', label: 'Left Leg', icon: 'pants', zone: 'ZONE_LEFT_LEG' },
    { key: 'ZONE_RIGHT_LEG', label: 'Right Leg', icon: 'pants', zone: 'ZONE_RIGHT_LEG' },
]

export function availableSlots(catalog, sections) {
    return CLOTHING_SLOTS.filter((slot) => {
        if (slot.prop && !sections?.props) return false
        if (!slot.prop && !sections?.components) return false
        const groups = slot.prop
            ? catalog?.props?.[String(slot.id)]
            : catalog?.components?.[String(slot.id)]
        return groups && groups.length > 0
    })
}

export function subcategoriesFor(category, catalog, sections, charCreation) {
    if (category === 'dna') {
        const list = []
        if (sections?.model && !catalog?.freemodeOnly) {
            list.push({ key: 'model', label: 'Ped Model', icon: 'pose', camera: 'full' })
        }
        if (catalog?.freemode) {
            if (sections?.headBlend) list.push({ key: 'heritage', label: 'Heritage', icon: 'dna', camera: 'face' })
            if (sections?.faceFeatures) list.push({ key: 'features', label: 'Facial Features', icon: 'grid', camera: 'face' })
            if (sections?.eyeColor) list.push({ key: 'eyes', label: 'Eye Color', icon: 'eye', camera: 'eyes' })
        }
        return list
    }
    if (category === 'hair') {
        const list = []
        if (sections?.hair) list.push({ key: 'style', label: 'Hair Style', icon: 'hair', camera: 'hair' })
        if (sections?.headOverlays && catalog?.freemode) {
            list.push({ key: 'overlays', label: 'Facial Hair & Makeup', icon: 'face', camera: 'face' })
        }
        return list
    }
    if (category === 'clothing') {
        const available = availableSlots(catalog, sections)
        return CLOTHING_GROUPS.filter((group) =>
            group.slots.some((key) => available.find((slot) => slot.key === key))
        )
    }
    if (category === 'tattoos') {
        return TATTOO_ZONES
    }
    return []
}

export function slotsForGroup(groupKey, catalog, sections) {
    const group = CLOTHING_GROUPS.find((g) => g.key === groupKey)
    if (!group) return []
    const available = availableSlots(catalog, sections)
    return group.slots
        .map((key) => available.find((slot) => slot.key === key))
        .filter(Boolean)
}
