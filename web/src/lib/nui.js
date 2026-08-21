export const isBrowser = !window.invokeNative

const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'qbx_appearance'

export async function fetchNui(name, data = {}) {
    if (isBrowser) return null
    const response = await fetch(`https://${resourceName}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    })
    return response.json()
}

const handlers = new Map()

export function onMessage(action, handler) {
    handlers.set(action, handler)
}

window.addEventListener('message', (event) => {
    const { action, data } = event.data ?? {}
    const handler = handlers.get(action)
    if (handler) handler(data)
})

const COMP_FOLDERS = {
    1: 'masks', 2: 'hair', 3: 'arms', 4: 'pants', 5: 'bags', 6: 'shoes',
    7: 'accessories', 8: 'undershirts', 9: 'armor', 10: 'decals', 11: 'tops',
}
const PROP_FOLDERS = { 0: 'hats', 1: 'glasses', 2: 'ears', 6: 'watches', 7: 'bracelets' }

const SCREENSHOTS_BASE = `nui://${resourceName}/screenshots`

let cdnMap = null

export function setCdnMap(map) {
    cdnMap = map && Object.keys(map).length > 0 ? map : null
}

function resolve(relPath) {
    return cdnMap?.[relPath] ?? `${SCREENSHOTS_BASE}/${relPath}`
}

export function thumbUrl(model, isProp, id, collection, drawable) {
    const folder = (isProp ? PROP_FOLDERS[id] : COMP_FOLDERS[id]) ?? 'tops'
    const name = `${model}_${collection || 'base'}_${drawable}`.replace(/[^\w-]/g, '_')
    return resolve(`clothing/${folder}/${name}.webp`)
}

export function faceThumbUrl(kind, index) {
    return resolve(`faces/${kind}_${index}.webp`)
}

export function pedThumbUrl(model) {
    return resolve(`peds/${model}.webp`)
}

const svgUri = (body) =>
    `data:image/svg+xml,${encodeURIComponent(
        `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">${body}</svg>`
    )}`

export const CLOTHING_PLACEHOLDER = svgUri(
    '<path d="M25 13l7 4 7-4 5 3 8 9-7 6-3-3v24H22V28l-3 3-7-6 8-9z" fill="none" stroke="#5c5f66" stroke-width="2.5" stroke-linejoin="round"/>'
)

export const FACE_PLACEHOLDER = svgUri(
    '<circle cx="32" cy="23" r="11" fill="none" stroke="#5c5f66" stroke-width="2.5"/>' +
    '<path d="M13 54c2-11 10-15 19-15s17 4 19 15" fill="none" stroke="#5c5f66" stroke-width="2.5" stroke-linecap="round"/>'
)

export function thumbFallback(placeholder) {
    return (event) => {
        const img = event.currentTarget
        img.onerror = null
        img.src = placeholder
        img.classList.add('ph')
    }
}
