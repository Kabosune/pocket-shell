pragma Singleton
import QtQuick
import Quickshell

// Line icons from the concept canvas, drawn on a 24x24 grid.
// Each glyph has a `stroke` path (outlined) and optionally a `fill` path.
Singleton {
    function circle(cx, cy, r) {
        return `M${cx - r} ${cy}a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0Z`;
    }

    function rrect(x, y, w, h, r) {
        const iw = w - 2 * r, ih = h - 2 * r;
        return `M${x + r} ${y}h${iw}a${r} ${r} 0 0 1 ${r} ${r}v${ih}a${r} ${r} 0 0 1 ${-r} ${r}`
             + `h${-iw}a${r} ${r} 0 0 1 ${-r} ${-r}v${-ih}a${r} ${r} 0 0 1 ${r} ${-r}Z`;
    }

    readonly property var bell: ({
        stroke: "M6 16V11a6 6 0 0 1 12 0v5l1.5 2h-15zM10 20.5a2 2 0 0 0 4 0"
    })
    readonly property var wifi: ({
        stroke: "M2.5 9a14 14 0 0 1 19 0M5.5 12.5a9.5 9.5 0 0 1 13 0M8.8 16a5 5 0 0 1 6.4 0",
        fill: circle(12, 19, 1)
    })
    readonly property var bluetooth: ({
        stroke: "M7 7l10 10-5 4V3l5 4L7 17"
    })
    readonly property var rotate: ({
        stroke: "M20 12a8 8 0 1 1-2.3-5.6M20 4v4h-4"
    })
    readonly property var gamepad: ({
        stroke: "M7 8h10a4 4 0 0 1 4 4.5l-.6 3.2a2.6 2.6 0 0 1-4.6 1.1L14.5 15h-5l-1.3 1.8a2.6 2.6 0 0 1-4.6-1.1L3 12.5A4 4 0 0 1 7 8z"
              + "M8 11v3M6.5 12.5h3M15.5 12h.01M17.5 13.5h.01"
    })
    readonly property var previous: ({
        stroke: "M6 5v14M18 6l-9 6 9 6z"
    })
    readonly property var next: ({
        stroke: "M18 5v14M6 6l9 6-9 6z"
    })
    readonly property var play: ({
        fill: "M8 5.5v13l11-6.5z"
    })
    readonly property var pause: ({
        fill: rrect(6.5, 5, 4, 14, 1) + rrect(13.5, 5, 4, 14, 1)
    })
    readonly property var browser: ({
        stroke: circle(12, 12, 9) + "M3 12h18M12 3c3 3.2 3 14.8 0 18M12 3c-3 3.2-3 14.8 0 18"
    })
    readonly property var files: ({
        stroke: "M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"
    })
    readonly property var music: ({
        stroke: "M9 18V6l10-2v12" + circle(6.5, 18, 2.5) + circle(16.5, 16, 2.5)
    })
    readonly property var gallery: ({
        stroke: rrect(3, 4, 18, 16, 3) + circle(9, 10, 1.8) + "M4 18l5-5 4 4 3-3 4 4"
    })
    readonly property var close: ({
        stroke: "M6 6l12 12M18 6L6 18"
    })
    readonly property var back: ({
        stroke: "M15 5l-7 7 7 7"
    })
    readonly property var pin: ({
        stroke: "M9 4h6l-1 5 3 3H7l3-3zM12 15v5"
    })
    readonly property var storage: ({
        stroke: rrect(3, 6, 18, 12, 3) + "M7 12h6",
        fill: circle(17, 12, 1)
    })
    readonly property var battery: ({
        stroke: rrect(2, 7, 18, 10, 3) + "M22 10.5v3"
    })
    readonly property var steam: ({
        stroke: circle(12, 12, 9) + circle(15.5, 9.5, 2.5) + "M3.5 13.5l5 2M13.2 11.4l-3.6 4.2",
        fill: circle(8.5, 15.8, 1.6)
    })
    readonly property var android: ({
        stroke: rrect(5, 9, 14, 11, 2) + "M5 9a7 6 0 0 1 14 0M8 5l1.2 2M16 5l-1.2 2",
        fill: circle(9.5, 13, 0.9) + circle(14.5, 13, 0.9)
    })
    readonly property var apps: ({
        stroke: rrect(4, 4, 7, 7, 2) + rrect(13, 4, 7, 7, 2) + rrect(4, 13, 7, 7, 2) + rrect(13, 13, 7, 7, 2)
    })
    readonly property var volume: ({
        stroke: "M4 9h4l5-4v14l-5-4H4zM16.5 9a4 4 0 0 1 0 6M19 6.5a8 8 0 0 1 0 11"
    })
    readonly property var volumeOff: ({
        stroke: "M4 9h4l5-4v14l-5-4H4zM16.5 9.5l5 5M21.5 9.5l-5 5"
    })
    readonly property var brightness: ({
        stroke: circle(12, 12, 4) + "M12 2.5v2M12 19.5v2M2.5 12h2M19.5 12h2M5.3 5.3l1.4 1.4M17.3 17.3l1.4 1.4M5.3 18.7l1.4-1.4M17.3 6.7l1.4-1.4"
    })
    readonly property var settings: ({
        stroke: "M4 7h10M18 7h2M4 17h4M12 17h8" + circle(16, 7, 2) + circle(10, 17, 2)
    })
}
