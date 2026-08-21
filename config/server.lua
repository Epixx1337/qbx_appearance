return {
    legacyMirror = false,

    studioGroup = 'group.admin',
    studioAce = 'qbx_appearance.studio',
    studioCommands = true,

    convert = {
        batchSize = 25,
    },

    imageUpload = {
        provider = 'qbox',
        apiKey = '',
        autoUpload = false,

        custom = {
            url = '',
            field = 'file',
            responsePath = 'data.url',
            storagePath = nil,
            deleteUrl = nil,
        },
    },

    pedAccess = {},

    prices = {
        clothing = 100,
        barber = 50,
        tattoo = 250,
        surgeon = 2500,
    },
}
