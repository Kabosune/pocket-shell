import QtQuick
import Quickshell

// Status bar: notifications (Home) or the time (other pages) · page tabs
// between L1/R1 · Wi-Fi and battery. Themes choose a segmented tab pill or
// separate chunky tab buttons, and plain or pixel status icons.
Item {
    id: bar

    property int page: 0
    property var pages: ["Home", "Library", "Apps", "Glance"]
    signal pageTapped(int index)

    readonly property bool buttons: Theme.tabStyle === "buttons"
    readonly property bool pixel: Theme.statusStyle === "pixel"

    implicitHeight: bar.buttons ? 40 : 48

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bar
    }
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.borderWidth + 1
        color: Theme.barBorder
    }

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        // Pixel themes: a swatch of your colour, then the date or time
        Rectangle {
            visible: bar.pixel
            anchors.verticalCenter: parent.verticalCenter
            width: 14
            height: 14
            color: Theme.accent
            border.width: 2
            border.color: Theme.textStrong
        }

        Icon {
            visible: bar.page === 0 && !bar.pixel
            anchors.verticalCenter: parent.verticalCenter
            glyph: Icons.bell
            size: 18
            color: Theme.text
        }

        Text {
            visible: bar.page !== 0 || bar.pixel
            anchors.verticalCenter: parent.verticalCenter
            text: bar.page === 0 ? Qt.formatDate(clock.date, "ddd M/d").toUpperCase() : Qt.formatTime(clock.date, "HH:mm")
            color: Theme.text
            font.family: bar.pixel ? Theme.displayFont : Theme.bodyFont
            font.weight: Font.Bold
            font.pixelSize: bar.pixel ? 15 : 12
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: bar.buttons ? 6 : 8

        KeyCap {
            anchors.verticalCenter: parent.verticalCenter
            label: bar.buttons ? "L" : "L1"
        }

        // Segmented pill (Dusk Tide)
        Surface {
            visible: !bar.buttons
            anchors.verticalCenter: parent.verticalCenter
            width: tabs.implicitWidth + 6
            height: tabs.implicitHeight + 6
            radius: Theme.rPill

            Row {
                id: tabs
                anchors.centerIn: parent
                spacing: 2

                Repeater {
                    model: bar.buttons ? [] : bar.pages

                    Rectangle {
                        id: tab
                        required property string modelData
                        required property int index
                        readonly property bool current: index === bar.page

                        width: tabLabel.implicitWidth + 32
                        height: tabLabel.implicitHeight + 10
                        radius: Theme.rPill
                        color: current ? Theme.accent : "transparent"

                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            id: tabLabel
                            anchors.centerIn: parent
                            text: tab.modelData
                            color: tab.current ? Theme.accentInk : Theme.text
                            font.family: Theme.bodyFont
                            font.weight: tab.current ? Font.ExtraBold : Font.Bold
                            font.pixelSize: 12
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            onClicked: bar.pageTapped(tab.index)
                        }
                    }
                }
            }
        }

        // Separate chunky buttons
        Repeater {
            model: bar.buttons ? bar.pages : []

            Chip {
                id: tabButton
                required property string modelData
                required property int index

                anchors.verticalCenter: parent.verticalCenter
                width: buttonLabel.implicitWidth + 28
                height: 26
                radius: Theme.rKey
                active: index === bar.page
                pressed: buttonTap.pressed

                Text {
                    id: buttonLabel
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: Theme.bevel ? -1 : 0
                    text: tabButton.modelData
                    color: tabButton.active ? Theme.accentInk : Theme.textStrong
                    font.family: Theme.bodyFont
                    font.weight: tabButton.active ? Font.Black : Font.ExtraBold
                    font.pixelSize: 13
                }

                MouseArea {
                    id: buttonTap
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: bar.pageTapped(tabButton.index)
                }
            }
        }

        KeyCap {
            anchors.verticalCenter: parent.verticalCenter
            label: bar.buttons ? "R" : "R1"
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        Icon {
            visible: !bar.pixel
            anchors.verticalCenter: parent.verticalCenter
            glyph: Icons.wifi
            size: 18
            color: Theme.text
        }

        // Pixel signal bars
        Row {
            visible: bar.pixel
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Repeater {
                model: [4, 8, 12, 15]
                Rectangle {
                    required property int modelData
                    required property int index
                    anchors.bottom: parent.bottom
                    width: index === 3 ? 2 : 4
                    height: modelData
                    color: index === 3 ? Theme.line : Theme.textStrong
                }
            }
        }

        Loader {
            anchors.verticalCenter: parent.verticalCenter
            source: "BatteryStatus.qml"
        }
    }
}
