return {
    tattoos = {
        maxOpacityLayers = 4,
        maxPerPlayer = 24,
    },

    clothingBag = {
        item = 'clothing_bag',
        cooldown = 60,
        uses = 10,
        menu = 'nui',
    },

    imageSource = 'local',

    physicalItems = {
        enabled = true,
        item = 'clothing_item',
        slots = {
            hat = { command = 'hat', label = 'Hat', prop = 0,
                anim = { dict = 'mp_masks@standard_car@ds@', clip = 'put_on_mask', dur = 600 },
                animOff = { dict = 'missheist_agency2ahelmet', clip = 'take_off_helmet_stand', dur = 1200 } },
            glasses = { command = 'glasses', label = 'Glasses', prop = 1,
                anim = { dict = 'clothingspecs', clip = 'take_off', dur = 1400 } },
            ears = { command = 'earring', label = 'Earring', prop = 2,
                anim = { dict = 'mp_cp_stolen_tut', clip = 'b_think', dur = 900 } },
            watch = { command = 'watch', label = 'Watch', prop = 6,
                anim = { dict = 'nmt_3_rcm-10', clip = 'cs_nigel_dual-10', dur = 1200 } },
            bracelet = { command = 'bracelet', label = 'Bracelet', prop = 7,
                anim = { dict = 'nmt_3_rcm-10', clip = 'cs_nigel_dual-10', dur = 1200 } },
            mask = { command = 'mask', label = 'Mask', component = 1,
                anim = { dict = 'mp_masks@standard_car@ds@', clip = 'put_on_mask', dur = 800 } },
            shirt = { command = 'shirt', label = 'Shirt', component = 11,
                anim = { dict = 'clothingtie', clip = 'try_tie_negative_a', dur = 1200 } },
            pants = { command = 'pants', label = 'Pants', component = 4,
                anim = { dict = 're@construction', clip = 'out_of_breath', dur = 1300 } },
            shoes = { command = 'shoes', label = 'Shoes', component = 6,
                anim = { dict = 'random@domestic', clip = 'pickup_low', dur = 1200, flag = 0 } },
            bag = { command = 'bag', label = 'Bag', component = 5,
                anim = { dict = 'anim@heists@ornate_bank@grab_cash', clip = 'intro', dur = 1600 } },
        },
    },

    outfits = {
        maxSaved = 30,
        maxGroupOutfits = 20,
    },

    studio = {
        hairColor = 4,
        hairHighlight = 4,
        heroAngle = 25.0,
        cameraHeight = 0.18,
        propPoses = {
            [6] = { dict = 'cellphone@', clip = 'cellphone_text_read_base', settle = 600 },
            [7] = { dict = 'cellphone@', clip = 'cellphone_text_read_base', settle = 600 },
        },
        decalBase = {
            ['mp_m_freemode_01'] = {
                { component = 3, collection = '', drawable = 15, texture = 0 },
            },
            ['mp_f_freemode_01'] = {
                { component = 3, collection = '', drawable = 15, texture = 0 },
                { component = 8, collection = '', drawable = 2, texture = 0 },
            },
        },
    },

    creation = {
        freemodeOnly = true,
        defaultMale = 'mp_m_freemode_01',
        defaultFemale = 'mp_f_freemode_01',
    },
}
