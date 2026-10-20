import QtQuick
import Quickshell.Io

// Battery settings: the charge limit (bin/pocket-battery). Opened from the
// Start menu. Left/right move the limit by 5%, B closes; touch drags.
Item {
    id: sheet

    property bool open: false

    readonly property int minLimit: 50
    readonly property int step: 5

    // From `pocket-battery status`
    property bool known: false
    property bool supported: false
    property bool writable: false
    property int capacity: -1
    property string chargeState: ""
    property int savedLimit: 75

    // What the slider shows; applied a moment after it stops moving
    property int limit: 75
    property string problem: ""

    function show() {
        problem = "";
        open = true;
        refresh();
    }

    function hide() {
        open = false;
        Sfx.play("back", 1);
    }

    function refresh() {
        if (!reader.running)
            reader.running = true;
    }

    function setLimit(n) {
        const v = Math.max(minLimit, Math.min(100, Math.round(n)));
        if (v === limit)
            return;
        limit = v;
        applyTimer.restart();
    }

    function handle(button) {
        switch (button) {
        case "left":
            setLimit(Math.ceil(limit / step) * step - step);
            break;
        case "right":
            setLimit(Math.floor(limit / step) * step + step);
            break;
        case "b":
        case "home":
        case "start":
        case "select":
            hide();
            break;
        }
    }

    readonly property string stateText: {
        if (!known)
            return "";
        const pct = capacity >= 0 ? `${capacity}%` : "";
        const st = chargeState.toLowerCase();
        let what = "";
        if (st === "charging")
            what = "charging";
        else if (st === "not charging")
            what = "plugged in, not charging";
        else if (st === "full")
            what = "full";
        else if (st === "discharging")
            what = "on battery";
        return [pct, what].filter(s => s !== "").join(" · ");
    }

    readonly property string explainText: {
        if (!supported)
            return "This system's kernel has no charge limit. Update pocknix to get it.";
        if (!writable)
            return "Run install.sh in the pocket-shell folder, then restart, to change the limit from here.";
        if (limit >= 100)
            return "No limit: the battery charges to 100%.";
        return `Charging stops at ${limit}% and starts again below ${limit - step}%. Plugged in, the RP5 runs from the charger in between. Keeping the battery away from 100% helps it last longer.`;
    }

    Process {
        id: reader
        command: ["pocket-battery", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = {};
                text.split("\n").forEach(line => {
                    const i = line.indexOf("=");
                    if (i > 0)
                        v[line.slice(0, i)] = line.slice(i + 1);
                });
                sheet.supported = v.supported === "1";
                sheet.writable = v.writable === "1";
                sheet.capacity = v.capacity ? parseInt(v.capacity) : -1;
                sheet.chargeState = v.status || "";
                const saved = parseInt(v.saved || "75");
                sheet.savedLimit = saved;
                // Show what the kernel has, unless the slider is mid-change
                if (!applyTimer.running && !writer.running) {
                    const end = parseInt(v.end || "");
                    sheet.limit = isNaN(end) ? saved : end;
                }
                sheet.known = true;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0 && !sheet.known) {
                sheet.known = true;
                sheet.supported = false;
                sheet.problem = "pocket-battery isn't installed (run install.sh)";
            }
        }
    }

    Timer {
        id: applyTimer
        interval: 600
        onTriggered: {
            if (writer.running) {
                restart();
                return;
            }
            writer.command = ["pocket-battery", "set", String(sheet.limit)];
            writer.running = true;
        }
    }

    Process {
        id: writer
        stderr: StdioCollector {
            id: writeErr
        }
        onExited: (exitCode, exitStatus) => {
            sheet.problem = exitCode === 0 ? "" : (writeErr.text.trim().replace(/^pocket-battery: /, "") || "Couldn't change the limit");
            Sfx.play(exitCode === 0 ? "toggle-on" : "error", 1);
            sheet.refresh();
        }
    }

    // Charging state changes slowly; look again now and then while open
    Timer {
        interval: 5000
        repeat: true
        running: sheet.open
        onTriggered: sheet.refresh()
    }

    visible: open

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: sheet.hide()
        }
    }

    Surface {
        anchors.centerIn: parent
        width: 560
        height: content.implicitHeight + 40
        color: Theme.surfaceStrong

        // Keep taps on the card from closing it
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 10

            Item {
                width: parent.width
                height: titleText.implicitHeight

                DisplayText {
                    id: titleText
                    text: "Battery"
                    color: Theme.textStrong
                    weight: Font.Black
                    size: 20
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: Theme.label(sheet.stateText)
                    color: Theme.textMuted
                    font.family: Theme.bodyFont
                    font.weight: Font.Bold
                    font.pixelSize: 13
                }
            }

            SettingRow {
                width: parent.width
                label: "Charge limit"
                glyph: Icons.battery
                value: (sheet.limit - sheet.minLimit) / (100 - sheet.minLimit)
                valueText: sheet.limit >= 100 ? "Off (100%)" : `${sheet.limit}%`
                note: sheet.problem
                usable: sheet.supported && sheet.writable
                focused: Controller.active && sheet.open
                onMoved: v => {
                    if (sheet.supported && sheet.writable)
                        sheet.setLimit(sheet.minLimit + v * (100 - sheet.minLimit));
                }
            }

            Text {
                width: parent.width
                wrapMode: Text.Wrap
                text: sheet.explainText
                color: Theme.textMuted
                font.family: Theme.bodyFont
                font.weight: Font.DemiBold
                font.pixelSize: 13
                lineHeight: 1.15
            }

            Item {
                width: parent.width
                height: 22

                HintBar {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    items: [
                        { key: "◀ ▶", round: false, text: "5%" },
                        { key: "B", round: true, text: "Close" }
                    ]
                }
            }
        }
    }
}
