import QtQuick
import Quickshell
import Quickshell.Io

// Tells apps to look dark or light to match the theme (bin/pocket-colors):
// a dark theme background means dark apps, a light one (paper, cream...)
// light apps. Firefox follows it with its "System theme — auto" theme;
// GTK apps pick it up when they start.
Scope {
    id: colors

    readonly property string wanted: Theme.luminance(Theme.bg) < 0.18 ? "dark" : "light"
    property string applied: ""

    onWantedChanged: settle.restart()
    Component.onCompleted: settle.restart()

    // Theme switches come in bursts (theme, then its mode); wait them out
    Timer {
        id: settle
        interval: 800
        onTriggered: {
            if (colors.wanted === colors.applied || runner.running)
                return;
            runner.command = ["pocket-colors", colors.wanted];
            runner.running = true;
        }
    }

    Process {
        id: runner
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0)
                colors.applied = runner.command[1];
            if (colors.wanted !== colors.applied)
                settle.restart();
        }
    }
}
