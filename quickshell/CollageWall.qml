import QtQuick

// An editorial, photocopied-poster wallpaper: scraps of paper, huge
// outlined words, halftone dots, a barcode, a hex dump, crop marks and
// small captions, all in one ink colour at low opacity, plus a single
// sticker in the accent. Drawn once from a seed, so it's the same every
// boot; change "seed" or "words" in theme.json for a different one.
Canvas {
    id: wall

    property color background: "#0C0B10"
    property color ink: "#D9D6E3"
    property color accent: Theme.accent
    property int seed: 7
    property var words: ["NO SIGNAL", "ctrl", "[0]", "EOF", "/dev/null", "login:"]
    property string fontFamily: Theme.bodyFont

    function rng(s) {
        // mulberry32
        let a = s >>> 0;
        return function () {
            a = (a + 0x6D2B79F5) >>> 0;
            let t = a;
            t = Math.imul(t ^ (t >>> 15), t | 1);
            t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
            return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
        };
    }

    function inkA(a) {
        return Qt.rgba(ink.r, ink.g, ink.b, a);
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const w = width, h = height;
        if (w <= 0 || h <= 0)
            return;
        const r = rng(seed);
        const between = (lo, hi) => lo + r() * (hi - lo);

        ctx.fillStyle = background;
        ctx.fillRect(0, 0, w, h);

        // Paper scraps
        for (let i = 0; i < 8; i++) {
            ctx.save();
            ctx.translate(between(0, w), between(0, h));
            ctx.rotate(between(-0.25, 0.25));
            const sw = between(120, 340), sh = between(80, 240);
            ctx.fillStyle = inkA(between(0.03, 0.075));
            ctx.fillRect(-sw / 2, -sh / 2, sw, sh);
            if (r() < 0.6) {
                ctx.strokeStyle = inkA(0.09);
                ctx.lineWidth = 1;
                ctx.strokeRect(-sw / 2, -sh / 2, sw, sh);
            }
            ctx.restore();
        }

        // Diagonal hatching
        ctx.save();
        const hx = between(w * 0.55, w * 0.8), hy = between(h * 0.05, h * 0.3);
        ctx.beginPath();
        ctx.rect(hx, hy, 150, 90);
        ctx.clip();
        ctx.strokeStyle = inkA(0.08);
        ctx.lineWidth = 1;
        for (let i = -100; i < 260; i += 7) {
            ctx.beginPath();
            ctx.moveTo(hx + i, hy);
            ctx.lineTo(hx + i + 90, hy + 90);
            ctx.stroke();
        }
        ctx.restore();

        // Halftone fields: dots shrinking across a block
        for (let k = 0; k < 2; k++) {
            const bx = between(0, w - 220), by = between(0, h - 140);
            const bw = between(160, 260), bh = between(100, 160);
            ctx.fillStyle = inkA(0.12);
            for (let y = 0; y < bh; y += 7) {
                for (let x = 0; x < bw; x += 7) {
                    const rad = 2.8 * (1 - x / bw) * (0.4 + 0.6 * (1 - y / bh));
                    if (rad < 0.4)
                        continue;
                    ctx.beginPath();
                    ctx.arc(bx + x, by + y, rad, 0, Math.PI * 2);
                    ctx.fill();
                }
            }
        }

        // Huge words, some outlined, some filled, a couple on their side
        for (let i = 0; i < words.length; i++) {
            ctx.save();
            const size = Math.round(between(64, 150));
            ctx.font = `bold ${size}px "${fontFamily}"`;
            ctx.translate(between(-40, w - 120), between(size * 0.8, h + 20));
            if (r() < 0.3)
                ctx.rotate(-Math.PI / 2);
            else
                ctx.rotate(between(-0.06, 0.06));
            if (r() < 0.55) {
                ctx.strokeStyle = inkA(between(0.09, 0.15));
                ctx.lineWidth = 1.2;
                ctx.strokeText(words[i], 0, 0);
            } else {
                ctx.fillStyle = inkA(between(0.05, 0.09));
                ctx.fillText(words[i], 0, 0);
            }
            ctx.restore();
        }

        // Barcode
        const bcx = between(w * 0.05, w * 0.4), bcy = between(h * 0.6, h * 0.85);
        let x = 0;
        ctx.fillStyle = inkA(0.14);
        while (x < 130) {
            const bar = r() < 0.35 ? 3 : 1;
            if (r() < 0.6)
                ctx.fillRect(bcx + x, bcy, bar, 40);
            x += bar + 1 + Math.floor(r() * 2);
        }
        ctx.font = `9px "${fontFamily}"`;
        ctx.fillText("0 451 2077 6 3", bcx, bcy + 52);

        // Hex dump
        const hdx = between(w * 0.6, w - 230), hdy = between(h * 0.55, h - 90);
        ctx.fillStyle = inkA(0.13);
        ctx.font = `9px "${fontFamily}"`;
        const hex = "0123456789abcdef";
        for (let line = 0; line < 7; line++) {
            let s = (line * 16).toString(16).padStart(4, "0") + "  ";
            for (let b = 0; b < 8; b++)
                s += hex[Math.floor(r() * 16)] + hex[Math.floor(r() * 16)] + " ";
            ctx.fillText(line === 0 ? "0000  7f 45 4c 46 02 01 01 00  .ELF...." : s, hdx, hdy + line * 12);
        }

        // Crop marks and captions
        ctx.strokeStyle = inkA(0.22);
        ctx.lineWidth = 1;
        const captions = ["fig. 03", "rev. b", "no. 0451", "side a", "tx/rx", "-- 404 --"];
        for (let i = 0; i < 6; i++) {
            const cx = between(30, w - 30), cy = between(30, h - 30);
            ctx.beginPath();
            ctx.moveTo(cx - 8, cy);
            ctx.lineTo(cx + 8, cy);
            ctx.moveTo(cx, cy - 8);
            ctx.lineTo(cx, cy + 8);
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(cx, cy, 4, 0, Math.PI * 2);
            ctx.stroke();
            ctx.fillStyle = inkA(0.2);
            ctx.font = `9px "${fontFamily}"`;
            ctx.fillText(captions[i], cx + 12, cy + 3);
        }

        // Speckle, like a photocopy
        ctx.fillStyle = inkA(0.05);
        for (let i = 0; i < 900; i++)
            ctx.fillRect(between(0, w), between(0, h), 1, 1);

        // One sticker in the accent colour
        ctx.save();
        ctx.translate(between(w * 0.1, w * 0.75), between(h * 0.15, h * 0.75));
        ctx.rotate(between(-0.12, 0.12));
        ctx.strokeStyle = Qt.rgba(accent.r, accent.g, accent.b, 0.55);
        ctx.lineWidth = 1.5;
        ctx.strokeRect(0, 0, 108, 26);
        ctx.fillStyle = Qt.rgba(accent.r, accent.g, accent.b, 0.7);
        ctx.font = `bold 12px "${fontFamily}"`;
        ctx.fillText("[ online ]", 14, 17);
        ctx.restore();
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onAccentChanged: requestPaint()
    onInkChanged: requestPaint()
    onBackgroundChanged: requestPaint()
    onSeedChanged: requestPaint()
    onWordsChanged: requestPaint()
}
