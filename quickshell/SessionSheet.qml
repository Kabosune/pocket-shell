import QtQuick
import Quickshell.Io

// Temporary way out of Pocket Shell until there's a real power menu.
Item {
    id: sheet

    property bool open: false

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
                onActivated: toPlasma.running = true
            }
            PillButton {
                width: 260
                label: "Steam game mode"
                onActivated: toSteam.running = true
            }
            PillButton {
                width: 260
                label: "Cancel"
                onActivated: sheet.open = false
            }
        }
    }

    Process { id: toPlasma; command: ["pocknix-desktop-select", "plasma-mobile", "--now"] }
    Process { id: toSteam; command: ["steamos-session-select", "gamescope"] }
}
