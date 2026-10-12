import QtQuick

// Status bar: notifications · page tabs between L1/R1 · Wi-Fi and battery.
Item {
    id: bar

    property int page: 0
    readonly property var pages: ["Home", "Library", "Apps", "Glance"]

    implicitHeight: 48

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Icon {
            glyph: Icons.bell
            size: 18
            color: Theme.text
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 8

        KeyCap {
            anchors.verticalCenter: parent.verticalCenter
            label: "L1"
        }

        Surface {
            anchors.verticalCenter: parent.verticalCenter
            width: tabs.implicitWidth + 6
            height: tabs.implicitHeight + 6
            radius: Theme.rPill

            Row {
                id: tabs
                anchors.centerIn: parent
                spacing: 2

                Repeater {
                    model: bar.pages

                    Rectangle {
                        id: tab
                        required property string modelData
                        required property int index
                        readonly property bool current: index === bar.page

                        width: tabLabel.implicitWidth + 32
                        height: tabLabel.implicitHeight + 10
                        radius: Theme.rPill
                        color: current ? Theme.accent : "transparent"

                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: tab.modelData
                            color: tab.current ? Theme.accentInk : Theme.text
                            font.family: Theme.bodyFont
                            font.weight: tab.current ? Font.ExtraBold : Font.Bold
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }

        KeyCap {
            anchors.verticalCenter: parent.verticalCenter
            label: "R1"
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            glyph: Icons.wifi
            size: 18
            color: Theme.text
        }

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            source: "BatteryStatus.qml"
        }
    }
}
