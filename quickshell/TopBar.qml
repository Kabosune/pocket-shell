import QtQuick
import Quickshell
import Quickshell.Io

// Status bar: notifications (Home) or the time (other pages) · page tabs
// between L1/R1 · Wi-Fi and battery. Themes choose the tab style
// (segmented pill, chunky buttons, numbered "workspaces", or bare
// "numbers") and the status style (icons, pixel, a plain text line, or
// "stats": a tiling-WM bar with workspaces left, what's playing in the
// middle, and cpu/mem/wifi/battery/time on the right).
Item {
    id: bar

    property int page: 0
    property var pages: ["Home", "Library", "Apps", "Glance"]
    signal pageTapped(int index)
    signal statusTapped()

    readonly property bool buttons: Theme.tabStyle === "buttons"
    readonly property bool workspaces: Theme.tabStyle === "workspaces"
    readonly property bool pixel: Theme.statusStyle === "pixel"
    readonly property bool stats: Theme.statusStyle === "stats"
    readonly property bool textStatus: Theme.statusStyle === "text" || stats
    readonly property bool numbers: Theme.tabStyle === "numbers"

    readonly property string user: Quickshell.env("USER") || "user"
    readonly property string host: hostFile.text().trim() || "pocket"

    implicitHeight: bar.buttons || bar.workspaces || bar.numbers ? 40 : 48

    FileView {
        id: hostFile
        path: "/etc/hostname"
        blockLoading: true
        printErrors: false
    }

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
        visible: !bar.stats
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        // Text status: user@host, like a shell prompt
        Text {
            visible: bar.textStatus
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.StyledText
            text: `<font color="${Theme.accent}">${bar.user}</font>@${bar.host}`
            color: Theme.textMuted
            font.family: Theme.bodyFont
            font.pixelSize: 13
        }

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
            visible: bar.page === 0 && !bar.pixel && !bar.textStatus
            anchors.verticalCenter: parent.verticalCenter
            glyph: Icons.bell
            size: 18
            color: Theme.text
        }

        DisplayText {
            visible: (bar.page !== 0 || bar.pixel) && !bar.textStatus
            anchors.verticalCenter: parent.verticalCenter
            text: bar.page === 0 ? Qt.formatDate(clock.date, "ddd M/d").toUpperCase() : Qt.formatTime(clock.date, "HH:mm")
            color: Theme.text
            font.family: bar.pixel ? Theme.displayFont : Theme.bodyFont
            weight: Font.Bold
            size: bar.pixel ? 15 : 12
        }
    }

    Row {
        id: tabRow
        anchors.centerIn: bar.stats ? undefined : parent
        anchors.left: bar.stats ? parent.left : undefined
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: bar.buttons ? 6 : 8

        KeyCap {
            anchors.verticalCenter: parent.verticalCenter
            label: bar.buttons ? "L" : "L1"
        }

        // Segmented pill (Dusk Tide)
        Surface {
            visible: !bar.buttons && !bar.workspaces && !bar.numbers
            anchors.verticalCenter: parent.verticalCenter
            width: tabs.implicitWidth + 6
            height: tabs.implicitHeight + 6
            radius: Theme.rPill

            Row {
                id: tabs
                anchors.centerIn: parent
                spacing: 2

                Repeater {
                    model: bar.buttons || bar.workspaces || bar.numbers ? [] : bar.pages

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
                            text: Theme.label(tab.modelData)
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
                    text: Theme.label(tabButton.modelData)
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

        // Numbered workspaces, like a tiling WM's bar: "1 home 2 library …"
        Repeater {
            model: bar.workspaces ? bar.pages : []

            Rectangle {
                id: ws
                required property string modelData
                required property int index
                readonly property bool current: index === bar.page

                anchors.verticalCenter: parent.verticalCenter
                width: wsLabel.implicitWidth + 18
                height: 26
                radius: Theme.rKey
                color: current ? Theme.accent : "transparent"

                Text {
                    id: wsLabel
                    anchors.centerIn: parent
                    textFormat: Text.StyledText
                    text: ws.current
                        ? `${ws.index + 1} ${Theme.label(ws.modelData)}`
                        : `<font color="${Theme.accent}">${ws.index + 1}</font> ${Theme.label(ws.modelData)}`
                    color: ws.current ? Theme.accentInk : Theme.textMuted
                    font.family: Theme.bodyFont
                    font.weight: ws.current ? Font.Bold : Font.Normal
                    font.pixelSize: 13
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: bar.pageTapped(ws.index)
                }
            }
        }

        // Bare numbers, the current one opened up: "1 [2 library] 3 4"
        Repeater {
            model: bar.numbers ? bar.pages : []

            Rectangle {
                id: num
                required property string modelData
                required property int index
                readonly property bool current: index === bar.page

                anchors.verticalCenter: parent.verticalCenter
                width: current ? numLabel.implicitWidth + 18 : 24
                height: 24
                radius: Theme.rKey
                color: current ? Theme.accent : "transparent"
                border.width: current ? 0 : 1
                border.color: Theme.line
                Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                Text {
                    id: numLabel
                    anchors.centerIn: parent
                    text: num.current ? `${num.index + 1} ${Theme.label(num.modelData)}` : `${num.index + 1}`
                    color: num.current ? Theme.accentInk : Theme.textMuted
                    font.family: Theme.bodyFont
                    font.weight: num.current ? Font.Bold : Font.Normal
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    onClicked: bar.pageTapped(num.index)
                }
            }
        }

        KeyCap {
            anchors.verticalCenter: parent.verticalCenter
            label: bar.buttons ? "R" : "R1"
        }

        // Layout tag, like a tiling WM's "[]=" or "BSP"
        Text {
            visible: bar.stats
            anchors.verticalCenter: parent.verticalCenter
            leftPadding: 4
            text: "[tile]"
            color: Theme.textMuted
            font.family: Theme.bodyFont
            font.pixelSize: 12
        }
    }

    // What's playing, centred between the tabs and the status
    Loader {
        id: mediaText
        readonly property real room: Math.max(0, Math.min(bar.width / 2 - tabRow.x - tabRow.width, status.x - bar.width / 2) - 24)
        active: bar.stats
        anchors.centerIn: parent
        width: item ? Math.min(item.implicitWidth, room * 2) : 0
        source: "MediaText.qml"
        onLoaded: item.width = Qt.binding(() => mediaText.width)
    }

    // Tap the status icons for Quick settings
    MouseArea {
        anchors.fill: status
        anchors.margins: -10
        onClicked: bar.statusTapped()
    }

    Row {
        id: status
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        // Text status: "wifi on │ bat 78% │ 21:58"
        Row {
            visible: bar.textStatus
            anchors.verticalCenter: parent.verticalCenter
            spacing: bar.stats ? 8 : 10

            component Sep: Text {
                text: "│"
                color: Theme.line
                font.family: Theme.bodyFont
                font.pixelSize: 13
            }

            Loader {
                anchors.verticalCenter: parent.verticalCenter
                active: bar.stats
                visible: active
                source: "StatsText.qml"
            }
            Sep {
                anchors.verticalCenter: parent.verticalCenter
                visible: bar.stats
            }
            Loader {
                anchors.verticalCenter: parent.verticalCenter
                active: bar.textStatus
                source: "WifiText.qml"
            }
            Sep {
                anchors.verticalCenter: parent.verticalCenter
            }
            Loader {
                id: batteryText
                anchors.verticalCenter: parent.verticalCenter
                active: bar.textStatus
                source: "BatteryText.qml"
            }
            Sep {
                anchors.verticalCenter: parent.verticalCenter
                visible: batteryText.item !== null && batteryText.item.visible
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: bar.stats ? Theme.label(Qt.formatDateTime(clock.date, "ddd HH:mm")) : Qt.formatTime(clock.date, "HH:mm")
                color: Theme.textStrong
                font.family: Theme.bodyFont
                font.weight: Font.Bold
                font.pixelSize: 13
            }
        }

        Icon {
            visible: !bar.pixel && !bar.textStatus
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
            active: !bar.textStatus
            source: "BatteryStatus.qml"
        }
    }
}
