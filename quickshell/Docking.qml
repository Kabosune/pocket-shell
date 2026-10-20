pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// A monitor on the USB-C port (bin/pocket-dock does the work).
//
// mode: "match" draws everything for the monitor (biggest resolution first)
// and shows a copy on the built-in screen; "smooth" does the same with the
// highest refresh rate first; "rp5" draws for the built-in screen (1080p,
// 60 Hz) and shows a copy on the monitor. Saved by pocket-dock in
// ~/.config/pocket-shell/dock-mode.
//
// mainOutput: the output everything is drawn for right now, when that isn't
// the built-in screen (pocket-dock writes it while docked in "match").
Singleton {
    id: docking

    readonly property string configFile: (Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`) + "/pocket-shell/dock-mode"
    readonly property string mainFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pocket-dock/main"

    property string mode: "match"
    readonly property var modes: ["match", "smooth", "rp5"]
    readonly property var labels: ({ match: "Full res", smooth: "Smooth", rp5: "RP5 1080p" })
    readonly property string label: labels[mode] || "Full res"
    property string mainOutput: ""

    function setMode(m) {
        if (modes.indexOf(m) < 0)
            return;
        mode = m;
        apply.command = ["pocket-dock", "mode", m];
        apply.running = true;
    }

    // Full res → Smooth → RP5 1080p → Full res
    function nextMode() {
        setMode(modes[(modes.indexOf(mode) + 1) % modes.length]);
    }

    Process {
        id: apply
        onExited: {
            mainView.reload();
            settle.restart();
        }
    }

    // Read once at start
    FileView {
        path: docking.configFile
        blockLoading: true
        printErrors: false
        onLoaded: {
            const m = text().trim();
            docking.mode = docking.modes.indexOf(m) >= 0 ? m : "match";
        }
    }

    FileView {
        id: mainView
        path: docking.mainFile
        blockLoading: true
        printErrors: false
        onLoaded: docking.mainOutput = text().trim()
        onLoadFailed: docking.mainOutput = ""
    }

    // The file only changes around plugging in and out (pocket-dock polls
    // every 2 s), so check it while there's more than the built-in screen,
    // or while docked.
    Timer {
        interval: 1000
        repeat: true
        running: Quickshell.screens.length > 1 || docking.mainOutput !== ""
        onTriggered: mainView.reload()
    }

    // Look again shortly after the screens change or a mode switch
    Timer {
        id: settle
        interval: 1500
        onTriggered: mainView.reload()
    }

    Connections {
        target: Quickshell
        function onScreensChanged() {
            mainView.reload();
            settle.restart();
        }
    }
}
