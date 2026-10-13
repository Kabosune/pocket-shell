import QtQuick
import Quickshell.Io

// Audio bars from cava (https://github.com/karlstav/cava), reading what
// PipeWire is playing. cava runs only while `running` is true and goes
// to sleep by itself during silence. Without cava installed the bars
// stay flat and `mode` says "no cava".
Item {
    id: viz

    property bool running: true
    property int bars: 14
    property real spacing: 4
    property var levels: []
    property string mode: "idle"     // "live" | "idle" | "no cava"

    function parse(line) {
        const parts = line.split(";");
        const out = [];
        for (let i = 0; i < bars && i < parts.length; i++) {
            const v = parseInt(parts[i]);
            out.push(isNaN(v) ? 0 : Math.min(1, v / 100));
        }
        levels = out;
        mode = "live";
        quiet.restart();
    }

    Process {
        id: cava
        running: viz.running && viz.mode !== "no cava"
        command: ["sh", "-c",
            "command -v cava >/dev/null || exit 127\n"
            + "conf=\"${XDG_RUNTIME_DIR:-/tmp}/pocket-shell-cava.conf\"\n"
            + "printf '%s\\n' '[general]' 'bars = " + viz.bars + "' 'framerate = 30' 'sleep_timer = 2' "
            + "'[input]' 'method = pipewire' 'source = auto' "
            + "'[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' "
            + "'ascii_max_range = 100' 'bar_delimiter = 59' 'frame_delimiter = 10' 'channels = mono' > \"$conf\"\n"
            + "exec cava -p \"$conf\""]
        stdout: SplitParser {
            onRead: data => viz.parse(data)
        }
        onExited: (code, status) => {
            if (code === 127)
                viz.mode = "no cava";
        }
    }

    // No frames for a moment: cava is asleep, nothing is playing
    Timer {
        id: quiet
        interval: 600
        onTriggered: {
            viz.levels = [];
            if (viz.mode === "live")
                viz.mode = "idle";
        }
    }

    Row {
        anchors.fill: parent
        spacing: viz.spacing

        Repeater {
            model: viz.bars

            Item {
                required property int index
                readonly property real level: viz.levels.length > index ? viz.levels[index] : 0

                width: (viz.width - viz.spacing * (viz.bars - 1)) / viz.bars
                height: viz.height

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(2, parent.level * parent.height)
                    color: Theme.textStrong
                    opacity: 0.35 + 0.65 * parent.level
                }
            }
        }
    }
}
