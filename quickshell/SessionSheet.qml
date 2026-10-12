import QtQuick
import Quickshell.Io

// Temporary way out of Pocket Shell until there's a real power menu.
Item {
    id: sheet

    property bool open: false
    property int focusedIndex: 0
    readonly property int count: 3

    function show() {
        focusedIndex = 0;
        open = true;
    }

    function activate(index) {
        if (index === 0)
            toPlasma.running = true;
        else if (index === 1)
            toSteam.running = true;
        else
            open = false;
    }

    // Controller input while the sheet is open
    function handle(button) {
        if (button === "up")
            focusedIndex = Math.max(0, focusedIndex - 1);
        else if (button === "down")
            focusedIndex = Math.min(count - 1, focusedIndex + 1);
        else if (button === "a")
            activate(focusedIndex);
        else if (button === "b" || button === "home" || button === "start")
            open = false;
    }

    visible: open

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.5)

        MouseArea {
            anchors.fill: parent
            onClicked: sheet.open = false
        }
    }

    Surface {
        anchors.centerIn: parent
        width: content.implicitWidth + 48
        height: content.implicitHeight + 48
        color: Qt.rgba(14 / 255, 36 / 255, 40 / 255, 0.96)

        // Swallow taps on the card so they don't close the sheet
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 12

            Text {
                text: "Switch session"
                color: Theme.textStrong
                font.family: Theme.bodyFont
                font.weight: Font.ExtraBold
                font.pixelSize: 18
            }

            PillButton {
                width: 260
                label: "Plasma Mobile"
                primary: true
                focused: Controller.active && sheet.focusedIndex === 0
                onActivated: sheet.activate(0)
            }
            PillButton {
                width: 260
                label: "Steam mode"
                focused: Controller.active && sheet.focusedIndex === 1
                onActivated: sheet.activate(1)
            }
            PillButton {
                width: 260
                label: "Cancel"
                focused: Controller.active && sheet.focusedIndex === 2
                onActivated: sheet.activate(2)
            }
        }
    }

    Process { id: toPlasma; command: ["pocknix-desktop-select", "plasma-mobile", "--now"] }
    Process { id: toSteam; command: ["steamos-session-select", "gamescope"] }
}
