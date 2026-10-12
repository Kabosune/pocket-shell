import QtQuick
import Quickshell.Services.UPower

// Battery from UPower: an icon + percentage, or (themes with "status":
// "pixel") four chunky segments. Hidden if there's no battery to report.
Row {
    id: battery
    spacing: 6

    readonly property var device: UPower.displayDevice
    readonly property real level: {
        if (!device || !device.ready)
            return 0;
        const p = device.percentage;
        return p > 1 ? p / 100 : p;
    }
    readonly property bool pixel: Theme.statusStyle === "pixel"

    visible: device !== null && device.ready && device.isLaptopBattery

    Icon {
        visible: !battery.pixel
        anchors.verticalCenter: parent.verticalCenter
        size: 22
        color: Theme.text
        glyph: ({
            stroke: Icons.rrect(2, 7, 18, 10, 3) + "M22 10.5v3",
            fill: Icons.rrect(4, 9, Math.max(3, 14 * battery.level), 6, 1.5)
        })
    }

    Row {
        visible: battery.pixel
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
            width: segments.implicitWidth + 8
            height: 17
            color: "transparent"
            border.width: 2
            border.color: Theme.textStrong

            Row {
                id: segments
                anchors.centerIn: parent
                spacing: 2

                Repeater {
                    model: 4
                    Rectangle {
                        required property int index
                        width: 5
                        height: 9
                        color: battery.level > index * 0.25 + 0.05 ? Theme.textStrong : Theme.line
                    }
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 3
            height: 6
            color: Theme.textStrong
        }
    }

    DisplayText {
        anchors.verticalCenter: parent.verticalCenter
        text: `${Math.round(battery.level * 100)}%`
        color: Theme.text
        font.family: battery.pixel ? Theme.displayFont : Theme.bodyFont
        weight: Font.Bold
        size: battery.pixel ? 13 : 12
    }
}
