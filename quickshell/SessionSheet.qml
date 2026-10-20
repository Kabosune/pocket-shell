import QtQuick
import Quickshell.Io

// The Start menu: themes, and ways out of Pocket Shell (until there's a
// real settings app and power menu).
Item {
    id: sheet

    property bool open: false
    property int focusedIndex: 0
    readonly property var actions: ["themes", "sounds", "monitor", "plasma", "steam", "cancel"]
    signal themesRequested()

    function show() {
        focusedIndex = 0;
        open = true;
    }

    function activate(index) {
        const action = actions[index];
        if (action === "themes") {
            open = false;
            themesRequested();
        } else if (action === "sounds") {
            Store.setSounds(!Store.sounds);
            Sfx.play("toggle-on", 2);
        } else if (action === "monitor") {
            Docking.toggleMode();
            Sfx.play("toggle-on", 2);
        } else if (action === "plasma") {
            toPlasma.running = true;
            Sfx.play("launch", 2);
        } else if (action === "steam") {
            toSteam.running = true;
            Sfx.play("launch", 2);
        } else {
            open = false;
            Sfx.play("back", 1);
        }
    }

    // Controller input while the sheet is open
    function handle(button) {
        if (button === "up")
            focusedIndex = Math.max(0, focusedIndex - 1);
        else if (button === "down")
            focusedIndex = Math.min(actions.length - 1, focusedIndex + 1);
        else if (button === "a")
            activate(focusedIndex);
        else if (button === "b" || button === "home" || button === "start")
            open = false;
    }

    visible: open

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: {
                sheet.open = false;
                Sfx.play("back", 1);
            }
        }
    }

    Surface {
        anchors.centerIn: parent
        width: content.implicitWidth + 48
        height: content.implicitHeight + 48
        color: Theme.surfaceStrong

        // Swallow taps on the card so they don't close the sheet
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 12

            DisplayText {
                text: "Menu"
                color: Theme.textStrong
                weight: Font.Black
                size: 22
            }

            PillButton {
                width: 260
                label: "Themes"
                primary: true
                focused: Controller.active && sheet.focusedIndex === 0
                onActivated: sheet.activate(0)
            }
            PillButton {
                width: 260
                label: Store.sounds ? "Sounds: On" : "Sounds: Off"
                focused: Controller.active && sheet.focusedIndex === 1
                onActivated: sheet.activate(1)
            }
            // How a monitor on USB-C is used (bin/pocket-dock)
            PillButton {
                width: 260
                label: Docking.mode === "rp5" ? "Monitor: RP5 1080p" : "Monitor: Full res"
                focused: Controller.active && sheet.focusedIndex === 2
                onActivated: sheet.activate(2)
            }
            PillButton {
                width: 260
                label: "Plasma Mobile"
                focused: Controller.active && sheet.focusedIndex === 3
                onActivated: sheet.activate(3)
            }
            PillButton {
                width: 260
                label: "Steam mode"
                focused: Controller.active && sheet.focusedIndex === 4
                onActivated: sheet.activate(4)
            }
            PillButton {
                width: 260
                label: "Cancel"
                focused: Controller.active && sheet.focusedIndex === 5
                onActivated: sheet.activate(5)
            }
        }
    }

    Process { id: toPlasma; command: ["pocknix-desktop-select", "plasma-mobile", "--now"] }
    Process { id: toSteam; command: ["steamos-session-select", "gamescope"] }
}
