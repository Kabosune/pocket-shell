import QtQuick

// Falling-code wallpaper: columns of glyphs that slide down the screen,
// bright at the head and fading up the trail, flickering as they fall.
// Drops come in three depths (small, dim and slow at the back; big,
// bright and fast at the front).
//
// Each drop is one Text moved by a YAnimator, so the falling runs on the
// render thread; the only script work is a few glyph swaps per tick.
// Everything stops while `running` is false (an app covers the shell).
Item {
    id: rain

    property color glyphColor: Theme.accent
    property color background: "black"
    // Colour of the leading glyph. Left transparent, heads are the glyph
    // colour washed toward white (for dark backgrounds); on a light page
    // give a dark one.
    property color head: "transparent"
    property string fontFamily: Theme.bodyFont
    property real size: 16          // glyph size of the middle layer, px
    property real density: 1        // drops per column
    property real speed: 1          // fall speed multiplier
    property bool running: true
    // false: no background and no fade, for rain laid over another wallpaper
    property bool fill: true

    readonly property real columnWidth: Math.round(size * 0.78)
    readonly property int columns: Math.max(1, Math.floor(width / columnWidth))
    readonly property int dropCount: width > 0 ? Math.round(columns * density * 1.25) : 0

    // Characters that read as "code" and exist in the bundled mono font
    readonly property string glyphSet:
        "0123456789ZΔΘΛΞΠΣΦΨΩαβγδεζηθλμξπσφψωЖЗИЙЛФЦЧШЩЪЫЬЭЮЯ:.=*+-|¦╌"

    // Back to front: size, brightness, speed, share of the drops
    readonly property var layers: [
        { scale: 0.7, bright: 0.38, speed: 0.55, share: 0.45 },
        { scale: 1.0, bright: 0.72, speed: 1.0, share: 0.38 },
        { scale: 1.35, bright: 1.0, speed: 1.55, share: 0.17 }
    ]

    // Per layer, colours from the end of a trail (index 0) to just behind
    // the head; heads get their own, nearly white.
    readonly property int steps: 14
    readonly property var palettes: makePalettes(glyphColor, background)
    readonly property var heads: layers.map(l => head.a > 0
        ? String(mix(background, head, 0.35 + 0.65 * l.bright))
        : mixHex(glyphColor, "#FFFFFF", 0.35 + 0.5 * l.bright))

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    function mixHex(a, b, t) {
        return String(mix(Qt.color(a), Qt.color(b), t));
    }

    function makePalettes(fg, bg) {
        const out = [];
        for (const layer of layers) {
            const row = [];
            for (let i = 0; i < steps; i++) {
                const t = Math.pow((i + 1) / steps, 1.5) * layer.bright;
                row.push(String(mix(bg, fg, t)));
            }
            out.push(row);
        }
        return out;
    }

    function randomGlyph() {
        return glyphSet.charAt(Math.floor(Math.random() * glyphSet.length));
    }

    function pickLayer() {
        let r = Math.random();
        for (let i = 0; i < layers.length; i++) {
            r -= layers[i].share;
            if (r <= 0)
                return i;
        }
        return layers.length - 1;
    }

    // Build the drop's text: one glyph per line, tail first, head last
    function paint(drop) {
        const palette = palettes[drop.depth];
        const n = drop.glyphs.length;
        let html = "";
        for (let i = 0; i < n; i++) {
            const c = i === n - 1 ? heads[drop.depth]
                : palette[Math.min(steps - 1, Math.floor(i / (n - 1) * steps))];
            html += `<font color="${c}">${drop.glyphs[i]}</font>`;
            if (i < n - 1)
                html += "<br>";
        }
        drop.text = html;
    }

    function spawn(drop, scattered) {
        const layer = pickLayer();
        const glyphs = [];
        const length = 6 + Math.floor(Math.random() * 20);
        for (let i = 0; i < length; i++)
            glyphs.push(randomGlyph());

        drop.depth = layer;
        drop.glyphs = glyphs;
        drop.mirrored = Math.random() < 0.5;
        drop.x = Math.floor(Math.random() * columns) * columnWidth;
        paint(drop);

        const tall = length * drop.lineStep;
        const from = scattered
            ? -tall + Math.random() * (height + tall)
            : -tall - Math.random() * height * 0.6;
        const pxPerSecond = (70 + Math.random() * 80) * layers[layer].speed * speed;
        drop.fall(from, height + 4, (height + 4 - from) / pxPerSecond * 1000);
    }

    // New accent: recolour what's already falling
    onPalettesChanged: {
        for (let i = 0; i < drops.count; i++) {
            const drop = drops.itemAt(i);
            if (drop && drop.glyphs.length > 0)
                paint(drop);
        }
    }

    // Swap a few glyphs now and then, mostly near the head
    Timer {
        interval: 90
        repeat: true
        running: rain.running && rain.dropCount > 0
        onTriggered: {
            const swaps = Math.max(1, Math.round(rain.dropCount * 0.1));
            for (let k = 0; k < swaps; k++) {
                const drop = drops.itemAt(Math.floor(Math.random() * drops.count));
                if (!drop || drop.glyphs.length === 0)
                    continue;
                const g = drop.glyphs.slice();
                const near = Math.random() < 0.6;
                const i = near ? g.length - 1 - Math.floor(Math.random() * Math.min(3, g.length))
                    : Math.floor(Math.random() * g.length);
                g[i] = rain.randomGlyph();
                drop.glyphs = g;
                rain.paint(drop);
            }
        }
    }

    Rectangle {
        visible: rain.fill
        anchors.fill: parent
        color: rain.background
    }

    Repeater {
        id: drops
        model: rain.dropCount

        Text {
            id: drop

            property int depth: 0
            property var glyphs: []
            property bool mirrored: false
            readonly property real px: Math.round(rain.size * rain.layers[depth].scale)
            readonly property real lineStep: Math.round(px * 1.12)

            function fall(from, to, ms) {
                y = from;
                anim.from = from;
                anim.to = to;
                anim.duration = Math.max(200, ms);
                anim.restart();
            }

            z: depth
            textFormat: Text.StyledText
            font.family: rain.fontFamily
            font.pixelSize: px
            lineHeightMode: Text.FixedHeight
            lineHeight: lineStep
            transform: Scale {
                origin.x: drop.width / 2
                xScale: drop.mirrored ? -1 : 1
            }

            YAnimator {
                id: anim
                target: drop
                paused: anim.running && !rain.running
                onFinished: rain.spawn(drop, false)
            }

            Component.onCompleted: rain.spawn(drop, true)
        }
    }

    // Fade out behind the button hints so they stay readable
    Rectangle {
        visible: rain.fill
        z: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 110
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(rain.background.r, rain.background.g, rain.background.b, 0) }
            GradientStop { position: 0.55; color: Qt.rgba(rain.background.r, rain.background.g, rain.background.b, 0.85) }
            GradientStop { position: 1; color: rain.background }
        }
    }
}
