import QtQuick
import "DancerFrames.js" as Dancer

// A little chibi girl (an original character) doing the hands-on-head,
// hip-swaying dance, drawn in coloured half-block text. The pixel art and
// frames come from tools/make-dancer.py. Hair and dress follow the theme.
Text {
    id: dancer

    property bool running: true
    property int frame: 0
    // About 165 beats a minute: a frame per half beat
    property int interval: 182

    readonly property var palette8: ({
        H: String(Theme.accent),
        D: String(Theme.mix(Theme.accent, Qt.rgba(0, 0, 0, 1), 0.3)),
        S: "#F6DFD0",
        E: "#2B2533",
        B: "#F2A0A0",
        R: "#F28B82",
        L: "#C5CCD9"
    })

    // Each frame as StyledText: runs of one colour share a <font> tag
    readonly property var rendered: Dancer.frames.map(f => {
        const rows = [];
        for (let y = 0; y < f.chars.length; y++) {
            const chars = f.chars[y], codes = f.codes[y];
            let html = "", run = "", runCode = "";
            const flush = () => {
                if (run === "")
                    return;
                html += runCode === "." ? run : `<font color="${palette8[runCode]}">${run}</font>`;
                run = "";
            };
            for (let x = 0; x < chars.length; x++) {
                const code = codes[x];
                if (code !== runCode) {
                    flush();
                    runCode = code;
                }
                run += code === "." ? "&nbsp;" : chars[x];
            }
            flush();
            rows.push(html);
        }
        return rows.join("<br>");
    })

    textFormat: Text.StyledText
    text: rendered[frame % rendered.length]
    font.family: Theme.bodyFont
    font.pixelSize: 13
    // A touch under 1 so the block rows meet without hairline gaps
    lineHeight: 0.97

    Timer {
        interval: dancer.interval
        repeat: true
        running: dancer.running && dancer.visible
        onTriggered: dancer.frame = (dancer.frame + 1) % dancer.rendered.length
    }
}
