<script>
    let { label, xMin, xMax, yMin, yMax, x = 0, y = 0, onchange } = $props()

    let pad
    let dragging = $state(false)

    function apply(event) {
        const rect = pad.getBoundingClientRect()
        const nx = Math.max(-1, Math.min(1, ((event.clientX - rect.left) / rect.width) * 2 - 1))
        const ny = Math.max(-1, Math.min(1, -(((event.clientY - rect.top) / rect.height) * 2 - 1)))
        onchange?.(Number(nx.toFixed(2)), Number(ny.toFixed(2)))
    }

    function onPointerDown(event) {
        dragging = true
        pad.setPointerCapture(event.pointerId)
        apply(event)
    }

    function onPointerMove(event) {
        if (dragging) apply(event)
    }

    function reset() {
        onchange?.(0, 0)
    }
</script>

<div class="feature">
    <div class="head">
        <span class="name">{label}</span>
        <button class="reset" onclick={reset} title="Reset">0</button>
    </div>
    <div
        class="pad"
        bind:this={pad}
        onpointerdown={onPointerDown}
        onpointermove={onPointerMove}
        onpointerup={() => (dragging = false)}
    >
        <span class="edge top">{yMax}</span>
        <span class="edge bottom">{yMin}</span>
        <span class="edge left">{xMin}</span>
        <span class="edge right">{xMax}</span>
        <div class="marker" style="left: {(x + 1) * 50}%; top: {(1 - y) * 50}%"></div>
    </div>
</div>

<style>
    .feature {
        display: flex;
        flex-direction: column;
        gap: 4px;
    }

    .head {
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .name {
        font-size: 11px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: var(--dark-1);
    }

    .reset {
        width: 18px;
        height: 18px;
        font-size: 10px;
        background: var(--dark-6);
        color: var(--dark-2);
        border: 1px solid var(--border);
        border-radius: 4px;
        cursor: pointer;
    }

    .reset:hover {
        color: var(--dark-0);
        border-color: var(--accent-40);
    }

    .pad {
        position: relative;
        aspect-ratio: 1;
        background: var(--dark-8);
        border: 1px solid var(--border);
        border-radius: var(--radius-sm);
        cursor: crosshair;
        overflow: hidden;
        background-image:
            linear-gradient(var(--dark-6) 1px, transparent 1px),
            linear-gradient(90deg, var(--dark-6) 1px, transparent 1px);
        background-size: 25% 25%;
        background-position: center;
    }

    .edge {
        position: absolute;
        font-size: 9px;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        color: var(--dark-3);
        pointer-events: none;
    }

    .edge.top { top: 4px; left: 50%; transform: translateX(-50%); }
    .edge.bottom { bottom: 4px; left: 50%; transform: translateX(-50%); }
    .edge.left { left: 4px; top: 50%; transform: translateY(-50%) rotate(180deg); writing-mode: vertical-rl; }
    .edge.right { right: 4px; top: 50%; transform: translateY(-50%); writing-mode: vertical-rl; }

    .marker {
        position: absolute;
        width: 10px;
        height: 10px;
        background: var(--accent);
        border: 2px solid #fff;
        border-radius: 3px;
        transform: translate(-50%, -50%) rotate(45deg);
        pointer-events: none;
        box-shadow: 0 0 8px var(--accent-40);
    }
</style>
