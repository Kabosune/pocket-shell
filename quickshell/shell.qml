import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    PanelWindow {
        id: root
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "#1A2838"

        property string time: Qt.formatTime(new Date(), "HH:mm")
        Timer {
            interval: 1000; running: true; repeat: true
            onTriggered: root.time = Qt.formatTime(new Date(), "HH:mm")
        }

        Column {
            anchors.centerIn: parent
            spacing: 20

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.time
                color: "#EAF3F1"
                font.pixelSize: 140
                font.weight: Font.Black
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Pocket Shell · hello from Quickshell"
                color: "#A9C4C0"
                font.pixelSize: 18
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 16
                Rectangle {
                    width: 240; height: 56; radius: 4; color: "#F4B78E"
                    Text { anchors.centerIn: parent; text: "Back to Plasma Mobile"; color: "#2B1A10"; font.pixelSize: 17; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: toPlasma.running = true }
                }
                Rectangle {
                    width: 200; height: 56; radius: 4; color: "#1F4447"
                    Text { anchors.centerIn: parent; text: "Steam game mode"; color: "#EAF3F1"; font.pixelSize: 17; font.bold: true }
                    MouseArea { anchors.fill: parent; onClicked: toSteam.running = true }
                }
            }
        }

        Process { id: toPlasma; command: ["pocknix-desktop-select", "plasma-mobile", "--now"] }
        Process { id: toSteam; command: ["steamos-session-select", "gamescope"] }
    }
}
