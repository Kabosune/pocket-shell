import QtQuick
import "PortraitFrames.js" as Portrait

// The headphone girl (an original character): ASCII line art made by
// tools/make-portrait.py, in tiny type. Headphones and eyes take the theme
// colour, the rest the text colour. She blinks now and then.
Text {
    id: portrait

    property bool running: true
    property bool blinking: false
    property real size: 5
    readonly property int rowCount: Portrait.frames[0].rows.length

    function htmlChar(ch) {
        return ch === "<" ? "&lt;" : ch === ">" ? "&gt;" : ch === "&" ? "&amp;"
            : ch === "\"" ? "&quot;" : ch === " " ? "&nbsp;" : ch;
    }

    function build(frame, ink, accent) {
        const rows = [];
        for (let y = 0; y < frame.rows.length; y++) {
            const line = frame.rows[y], mask = frame.accent[y];
            let html = "", run = "", runAccent = null;
            const flush = () => {
                if (run !== "")
                    html += `<font color="${runAccent ? accent : ink}">${run}</font>`;
                run = "";
            };
            for (let x = 0; x < line.length; x++) {
                const isAccent = mask[x] === "1";
                if (isAccent !== runAccent) {
                    flush();
                    runAccent = isAccent;
                }
                run += htmlChar(line[x]);
            }
            flush();
            rows.push(html);
        }
        return rows.join("<br>");
    }

    readonly property var rendered: Portrait.frames.map(f => build(f, String(Theme.textStrong), String(Theme.accent)))

    textFormat: Text.StyledText
    text: rendered[blinking ? 1 : 0]
    font.family: Theme.bodyFont
    font.pixelSize: size
    lineHeight: 1.0

    // A blink every few seconds, a little irregular
    Timer {
        id: blinkWait
        interval: 3500
        running: portrait.running && portrait.visible && !portrait.blinking
        onTriggered: {
            portrait.blinking = true;
            interval = 2500 + Math.random() * 3500;
        }
    }
    Timer {
        interval: 140
        running: portrait.blinking
        onTriggered: portrait.blinking = false
    }
}
