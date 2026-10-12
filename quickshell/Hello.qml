import QtQuick
import Quickshell
import Quickshell.Io

// Placeholder screen until Home lands. Uses the real Theme tokens and
// lays itself out from the window size, so nothing is hardcoded to a resolution.
Item {
    id: root

    readonly property bool portrait: height > width

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    component BigDigits: Text {
        font.family: Theme.displayFont
        font.weight: Font.Black
        font.pixelSize: root.portrait ? 196 : 168
        font.letterSpacing: root.portrait ? -6 : -5
        lineHeightMode: Text.ProportionalHeight
        lineHeight: 0.84
    }

    component ShellButton: Rectangle {
        id: button
        property alias label: labelText.text
        property bool primary: false
        signal activated()

        implicitWidth: Math.max(220, labelText.implicitWidth + 40)
        implicitHeight: 52
        radius: Theme.rBtn
        color: primary ? Theme.accent : Theme.chip
        opacity: tap.pressed ? 0.8 : 1

        Text {
            id: labelText
            anchors.centerIn: parent
            color: button.primary ? Theme.onAccent : Theme.textStrong
            font.family: Theme.bodyFont
            font.weight: Font.ExtraBold
            font.pixelSize: 16
        }

        MouseArea {
            id: tap
            anchors.fill: parent
            onClicked: button.activated()
        }
    }

    Column {
        id: clockBlock
        x: root.portrait ? (root.width - width) / 2 : Theme.edge
        y: root.portrait ? 96 : 70

        BigDigits {
            anchors.horizontalCenter: root.portrait ? parent.horizontalCenter : undefined
            text: Qt.formatTime(clock.date, "HH")
            color: Theme.textStrong
        }
        BigDigits {
            anchors.horizontalCenter: root.portrait ? parent.horizontalCenter : undefined
            text: Qt.formatTime(clock.date, "mm")
            color: Theme.accent
        }

        Item { width: 1; height: 18 }

        Row {
            anchors.horizontalCenter: root.portrait ? parent.horizontalCenter : undefined
            spacing: 10

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: dayText.implicitWidth + 24
                height: dayText.implicitHeight + 10
                radius: Theme.rPill
                color: Theme.surface
                border.color: Theme.surfaceBorder
                border.width: 1

                Text {
                    id: dayText
                    anchors.centerIn: parent
                    text: Qt.formatDate(clock.date, "ddd").toUpperCase()
                    color: Theme.text
                    font.family: Theme.bodyFont
                    font.weight: Font.ExtraBold
                    font.pixelSize: 12
                    font.letterSpacing: 1.5
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Qt.formatDate(clock.date, "MMMM d")
                color: Theme.textStrong
                font.family: Theme.bodyFont
                font.weight: Font.ExtraBold
                font.pixelSize: 20
            }
        }
    }

    Column {
        id: actions
        spacing: 14
        x: root.portrait ? (root.width - width) / 2 : root.width - width - 40
        y: root.portrait ? clockBlock.y + clockBlock.height + 48 : (root.height - height) / 2

        ShellButton {
            label: "Back to Plasma Mobile"
            primary: true
            onActivated: toPlasma.running = true
        }
        ShellButton {
            label: "Steam game mode"
            onActivated: toSteam.running = true
        }
    }

    // What the shell actually sees. Handy while the layout is being tuned.
    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 14
        color: Theme.textMuted
        font.family: Theme.bodyFont
        font.pixelSize: 12
        text: {
            const s = Device.screen;
            const name = s ? s.name : "no screen";
            const dpr = s ? s.devicePixelRatio : 0;
            return `${Math.round(root.width)}×${Math.round(root.height)} · ${name} · scale ${dpr}`;
        }
    }

    Process { id: toPlasma; command: ["pocknix-desktop-select", "plasma-mobile", "--now"] }
    Process { id: toSteam; command: ["steamos-session-select", "gamescope"] }
}
