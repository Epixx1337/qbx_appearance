<script>
    let { name, size = 22 } = $props()

    const PATHS = {
        dna: 'M8 3c0 6 8 6 8 9M16 3c0 6-8 6-8 9M8 21c0-6 8-6 8-9M16 21c0-6-8-6-8-9M9 6.5h6M9 17.5h6',
        hair: 'M7 4c5-2 10 1 10 6 0 2-1 3-1 5l1 5-3-2-2 2-2-2-3 2 1-5c0-2-1-3-1-5 0-2 0-4 0-6zM10 9h.01M14 9h.01',
        shirt: 'M9 4l3 2 3-2 2 1 3 4-3 2-1-1v10H8V10l-1 1-3-2 3-4z',
        tattoo: 'M12 3l5 5-8.5 11.5L4 21l1.5-4.5zM14 10l-2-2M19 19h.01',
        hanger: 'M12 4a2 2 0 1 1 2 2c-1 0-2 .8-2 2M12 8l9 8H3z',
        pants: 'M8 3h8l1.5 18h-4.5L12 12l-1 9H6.5z M8 7h8',
        shoe: 'M4 17V9h5l3 4h6a3 3 0 0 1 3 3v2H4zM4 19h17',
        watch: 'M12 8a4.5 4.5 0 1 1 0 9 4.5 4.5 0 0 1 0-9zM10 8V3h4v5M10 17v4h4v-4',
        spotlight: 'M9 3h6l-1 5h-4zM8 8h8l4 13H4zM10 15h4',
        pose: 'M12 3a2 2 0 1 1 0 4 2 2 0 0 1 0-4zM4 9l4-2h8l4 2M12 7v7l-3 7M12 14l3 7',
        save: 'M5 4h11l3 3v13H5zM8 4v5h7V4M8 15h8v5H8z',
        pen: 'M14 5l5 5L8 21H3v-5zM12 7l5 5',
        share: 'M12 14V3M12 3L8 7M12 3l4 4M5 12v8h14v-8',
        close: 'M6 6l12 12M18 6L6 18',
        mask: 'M5 8c0-3 3-5 7-5s7 2 7 5v4c0 5-3 9-7 9s-7-4-7-9zM9 11h.01M15 11h.01M10 16c.7.6 1.3.8 2 .8s1.3-.2 2-.8',
        glasses: 'M4 12a3 3 0 1 0 6 0 3 3 0 0 0-6 0zM14 12a3 3 0 1 0 6 0 3 3 0 0 0-6 0zM10 12h4M2 11l2-1M22 11l-2-1',
        hat: 'M5 14a7 7 0 0 1 14 0v1H5zM2 17h20M7 15v2M17 15v2',
        bag: 'M6 8h12l1.5 12h-15zM9 8V6a3 3 0 0 1 6 0v2',
        vest: 'M7 3c1 2 3 3 5 3s4-1 5-3l3 4-3 3v10H7V10L4 7zM12 6v14',
        decal: 'M12 3l2.4 5.2L20 9l-4 4 1 6-5-3-5 3 1-6-4-4 5.6-.8z',
        earring: 'M9 3c0 3 3 3 3 6M12 12a3.5 3.5 0 1 1-.01 7 3.5 3.5 0 0 1 .01-7z',
        bracelet: 'M12 7c4 0 7 2 7 5s-3 5-7 5-7-2-7-5 3-5 7-5zM9 7.5V5M15 7.5V5',
        tank: 'M8 3c0 3 1 4 1 6v12h6V9c0-2 1-3 1-6M8 3h1.5M14.5 3H16',
        glove: 'M8 12V5a1.4 1.4 0 0 1 2.8 0v5M10.8 10V4a1.4 1.4 0 0 1 2.8 0v6M13.6 10V5a1.4 1.4 0 0 1 2.8 0v7c0 5-2 9-6 9-3 0-4.5-2-5.5-5l-1.4-4a1.4 1.4 0 0 1 2.6-1l1.5 3',
        chain: 'M5 4c2 5 5 7 7 7s5-2 7-7M12 11v3M10 17.5l2-2 2 2-2 2z',
        face: 'M12 3a9 9 0 1 0 0 18 9 9 0 0 0 0-18zM9 10h.01M15 10h.01M9 14.5c1 1 2 1.5 3 1.5s2-.5 3-1.5',
        eye: 'M2 12c3-5 6.5-7 10-7s7 2 10 7c-3 5-6.5 7-10 7s-7-2-10-7zM12 9a3 3 0 1 0 .01 6 3 3 0 0 0-.01-6z',
        grid: 'M4 4h16v16H4zM12 4v16M4 12h16',
        flip: 'M4 12a8 8 0 0 1 13.5-5.5M20 12a8 8 0 0 1-13.5 5.5M18 2.5v4h-4M6 21.5v-4h4',
    }
</script>

<svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    stroke-width="1.7"
    stroke-linecap="round"
    stroke-linejoin="round"
>
    <path d={PATHS[name] ?? PATHS.shirt} />
</svg>
