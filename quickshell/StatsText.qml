import QtQuick
import Quickshell.Io

// "cpu 12%  mem 38%" for the bar, read from /proc every 2 seconds while
// the shell is showing.
Text {
    id: stats

    property real cpu: -1
    property real mem: -1
    property var last: null

    function read() {
        statFile.reload();
        memFile.reload();

        const fields = (statFile.text().split("\n")[0] || "").trim().split(/\s+/).slice(1).map(Number);
        if (fields.length >= 5) {
            const idle = fields[3] + (fields[4] || 0);
            const total = fields.reduce((a, b) => a + b, 0);
            if (last && total > last.total)
                cpu = 1 - (idle - last.idle) / (total - last.total);
            last = { idle: idle, total: total };
        }

        const info = memFile.text();
        const total = Number((info.match(/^MemTotal:\s+(\d+)/m) || [0, 0])[1]);
        const avail = Number((info.match(/^MemAvailable:\s+(\d+)/m) || [0, 0])[1]);
        if (total > 0)
            mem = (total - avail) / total;
    }

    function pct(v) {
        return v < 0 ? "--" : `${Math.round(v * 100)}%`;
    }

    textFormat: Text.StyledText
    text: `<font color="${Theme.textMuted}">cpu</font> ${pct(cpu)}  <font color="${Theme.textMuted}">mem</font> ${pct(mem)}`
    color: Theme.text
    font.family: Theme.bodyFont
    font.pixelSize: 12

    FileView { id: statFile; path: "/proc/stat"; blockLoading: true; printErrors: false }
    FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true; printErrors: false }

    Timer {
        interval: 2000
        repeat: true
        running: Wm.inShell
        triggeredOnStart: true
        onTriggered: stats.read()
    }
}
