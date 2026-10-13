pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness through brightnessctl (backlight class devices).
//
// level is 0..1, or -1 until it's been read. set() is safe to call on
// every slider step: only the latest value is sent, one command at a time.
// Brightness never goes below `minimum`, so the screen can't be turned
// fully dark by accident.
Singleton {
    id: brightness

    property real level: -1
    property bool available: false
    property string problem: ""
    readonly property real minimum: 0.05

    property real target: -1

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    function set(v) {
        if (!available)
            return;
        const clamped = Math.max(minimum, Math.min(1, v));
        level = clamped;
        target = clamped;
        if (!writer.running)
            writeNext();
    }

    function step(delta) {
        set((level < 0 ? 0.5 : level) + delta);
    }

    function writeNext() {
        if (target < 0)
            return;
        const pct = Math.round(target * 100);
        target = -1;
        writer.command = ["brightnessctl", "-q", "-c", "backlight", "set", `${pct}%`];
        writer.running = true;
    }

    // `brightnessctl -m` prints: device,class,current,percent,max
    Process {
        id: reader
        command: ["sh", "-c", "command -v brightnessctl >/dev/null || exit 127; exec brightnessctl -m -c backlight info"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split("\n")[0].split(",");
                if (parts.length >= 5) {
                    const current = Number(parts[2]);
                    const max = Number(parts[4]);
                    if (max > 0) {
                        brightness.level = current / max;
                        brightness.available = true;
                        brightness.problem = "";
                    }
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                brightness.available = false;
                brightness.problem = exitCode === 127
                    ? "Install brightnessctl to change brightness"
                    : "No screen backlight found";
            }
        }
    }

    Process {
        id: writer
        stderr: StdioCollector {
            id: writeErr
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                const why = writeErr.text.trim();
                brightness.problem = why.toLowerCase().indexOf("permission") >= 0
                    ? "No permission to change brightness"
                    : (why || "Couldn't change brightness");
                brightness.target = -1;
                brightness.refresh();
                return;
            }
            brightness.problem = "";
            brightness.writeNext();
        }
    }

    Component.onCompleted: refresh()
}
