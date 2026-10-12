import QtQuick
import Quickshell.Services.UPower

// Battery icon + percentage from UPower. Hidden if there's no battery to report.
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

    visible: device !== null && device.ready && device.isLaptopBattery

    Icon {
        anchors.verticalCenter: parent.verticalCenter
        size: 22
        color: Theme.text
        glyph: ({
            stroke: Icons.rrect(2, 7, 18, 10, 3) + "M22 10.5v3",
            fill: Icons.rrect(4, 9, Math.max(3, 14 * battery.level), 6, 1.5)
        })
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: `${Math.round(battery.level * 100)}%`
        color: Theme.text
        font.family: Theme.bodyFont
        font.weight: Font.Bold
        font.pixelSize: 12
    }
}
