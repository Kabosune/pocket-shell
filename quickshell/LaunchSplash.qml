import QtQuick

// "Opening <app>…" — shown on a freshly launched app's workspace until its
// window appears (see Wm.launchEntry). Pressing the app again while this
// is up doesn't start a second copy. B or Home goes back to the shell; the
// app keeps starting and opens in the background.
Item {
    id: splash

    property var launch: null
    readonly property bool open: launch !== null

    // Seconds since the launch started, for the "taking a while" line
    property int elapsed: 0

    visible: open

    onLaunchChanged: elapsed = launch ? Math.floor((Date.now() - launch.since) / 1000) : 0

    Timer {
        interval: 1000
        repeat: true
        running: splash.open
        onTriggered: splash.elapsed = Math.floor((Date.now() - splash.launch.since) / 1000)
    }

    // Swallow taps so nothing underneath reacts
    MouseArea {
        anchors.fill: parent
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -10
        spacing: 22

        Item {
            id: badge
            anchors.horizontalCenter: parent.horizontalCenter
            width: 168
            height: 168

            // Ripple rings going out from the icon
            Repeater {
                model: 2

                Rectangle {
                    id: ring
                    required property int index
                    anchors.centerIn: parent
                    width: 120
                    height: 120
                    radius: Theme.squareIcons ? Theme.rIcon : width / 2
                    color: "transparent"
                    border.color: Theme.accent
                    border.width: 3
                    opacity: 0

                    SequentialAnimation {
                        running: splash.open
                        loops: Animation.Infinite

                        PauseAnimation { duration: ring.index * 700 }
                        ParallelAnimation {
                            NumberAnimation { target: ring; property: "scale"; from: 0.9; to: 1.45; duration: 1400; easing.type: Easing.OutCubic }
                            NumberAnimation { target: ring; property: "opacity"; from: 0.7; to: 0; duration: 1400; easing.type: Easing.OutCubic }
                        }
                        PauseAnimation { duration: (1 - ring.index) * 700 }
                    }
                }
            }

            Chip {
                id: iconChip
                visible: !splash.launch || splash.launch.art === ""
                anchors.centerIn: parent
                width: 120
                height: 120
                radius: Theme.squareIcons ? Theme.rIcon : Theme.rCard

                AppIcon {
                    anchors.centerIn: parent
                    entry: splash.launch ? splash.launch.entry : null
                    fallbackName: splash.launch ? splash.launch.name : ""
                    size: 76
                }

                SequentialAnimation on scale {
                    running: splash.open
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 1.05; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1.05; to: 1; duration: 700; easing.type: Easing.InOutSine }
                }
            }

            GameCover {
                visible: splash.launch !== null && splash.launch.art !== ""
                anchors.centerIn: parent
                width: 120
                height: 160
                art: splash.launch ? splash.launch.art : ""
                title: splash.launch ? splash.launch.name : ""
            }
        }

        DisplayText {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, splash.width - 96)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: splash.launch ? splash.launch.name : ""
            color: Theme.textStrong
            weight: Font.Black
            size: 30
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Theme.label(splash.elapsed >= 8 ? "Still opening" : "Opening")
                color: Theme.textMuted
                font.family: Theme.bodyFont
                font.weight: Font.Bold
                font.pixelSize: 16
            }

            // Three dots taking turns
            Repeater {
                model: 3

                Rectangle {
                    id: dot
                    required property int index
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.accent
                    opacity: 0.25

                    SequentialAnimation on opacity {
                        running: splash.open
                        loops: Animation.Infinite
                        PauseAnimation { duration: dot.index * 180 }
                        NumberAnimation { to: 1; duration: 240 }
                        NumberAnimation { to: 0.25; duration: 240 }
                        PauseAnimation { duration: (2 - dot.index) * 180 + 300 }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: splash.elapsed >= 8
            text: "Games and big apps can take a little while."
            color: Theme.textHint
            font.family: Theme.bodyFont
            font.weight: Font.DemiBold
            font.pixelSize: 13
        }
    }

    PillButton {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 56
        visible: !Controller.active
        label: "Wait on Home"
        onActivated: {
            Wm.goHome();
            Sfx.play("back", 1);
        }
    }

    HintBar {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        items: [
            { key: "B", round: true, text: "Wait on Home" }
        ]
    }
}
