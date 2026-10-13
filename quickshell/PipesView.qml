import QtQuick

// The old pipes screensaver, in a tile: a few pipes wander a grid,
// turning now and then and wrapping at the edges. Only new segments are
// drawn each tick; every so often the older ones fade back so the tile
// never fills up.
Canvas {
    id: pipes

    property bool running: true
    property var colors: ["#B9A7F0", "#E6E3EE", "#8CD4C8", "#E8C07D"]
    property real cell: 8
    property int pipeCount: 3
    property real lineWidth: 2

    property var heads: []
    property var pending: []
    property int sinceFade: 0
    property bool needsReset: true

    readonly property int cols: Math.max(1, Math.floor(width / cell))
    readonly property int rows: Math.max(1, Math.floor(height / cell))

    // Directions: 0 right, 1 down, 2 left, 3 up
    readonly property var dx: [1, 0, -1, 0]
    readonly property var dy: [0, 1, 0, -1]

    function newHead() {
        const dir = Math.floor(Math.random() * 4);
        return {
            x: dir === 0 ? 0 : dir === 2 ? cols - 1 : Math.floor(Math.random() * cols),
            y: dir === 1 ? 0 : dir === 3 ? rows - 1 : Math.floor(Math.random() * rows),
            dir: dir,
            color: colors.length > 0 ? colors[Math.floor(Math.random() * colors.length)] : "white"
        };
    }

    function step() {
        if (heads.length !== pipeCount) {
            const h = [];
            for (let i = 0; i < pipeCount; i++)
                h.push(newHead());
            heads = h;
        }
        const out = pending;
        for (const p of heads) {
            // Turn left or right sometimes, never straight back
            if (Math.random() < 0.14)
                p.dir = (p.dir + (Math.random() < 0.5 ? 1 : 3)) % 4;
            const nx = p.x + dx[p.dir];
            const ny = p.y + dy[p.dir];
            if (nx < 0 || ny < 0 || nx >= cols || ny >= rows) {
                Object.assign(p, newHead());
                continue;
            }
            out.push({ x0: p.x, y0: p.y, x1: nx, y1: ny, color: p.color });
            p.x = nx;
            p.y = ny;
        }
        pending = out;
        sinceFade += heads.length;
    }

    onPaint: {
        const ctx = getContext("2d");
        if (needsReset) {
            ctx.reset();
            needsReset = false;
        }
        if (sinceFade > cols * rows * 0.35) {
            ctx.globalCompositeOperation = "destination-out";
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.45);
            ctx.fillRect(0, 0, width, height);
            ctx.globalCompositeOperation = "source-over";
            sinceFade = 0;
        }
        ctx.lineWidth = lineWidth;
        ctx.lineCap = "square";
        const half = cell / 2;
        for (const s of pending) {
            ctx.strokeStyle = s.color;
            ctx.beginPath();
            ctx.moveTo(s.x0 * cell + half, s.y0 * cell + half);
            ctx.lineTo(s.x1 * cell + half, s.y1 * cell + half);
            ctx.stroke();
        }
        pending = [];
    }

    // Start with some pipes already laid, so the tile isn't empty
    function prefill() {
        if (width <= 0 || height <= 0)
            return;
        needsReset = true;
        heads = [];
        pending = [];
        sinceFade = 0;
        for (let i = 0; i < Math.round(cols * rows * 0.06); i++)
            step();
        requestPaint();
    }

    onWidthChanged: prefill()
    onHeightChanged: prefill()
    onColorsChanged: prefill()

    Timer {
        interval: 70
        repeat: true
        running: pipes.running && pipes.width > 0
        onTriggered: {
            pipes.step();
            pipes.requestPaint();
        }
    }
}
