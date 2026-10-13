import QtQuick
import Quickshell.Services.UPower

// "bat 78%" (with a + while charging) for text-style status bars.
Text {
    readonly property var device: UPower.displayDevice
    readonly property bool ok: device !== null && device.ready && device.isLaptopBattery
    readonly property real level: {
        if (!ok)
            return 0;
        const p = device.percentage;
        return p > 1 ? p / 100 : p;
    }

    visible: ok
    text: `bat ${Math.round(level * 100)}%${UPower.onBattery ? "" : "+"}`
    color: level < 0.15 && UPower.onBattery ? "#F28B82" : Theme.text
    font.family: Theme.bodyFont
    font.pixelSize: 13
}
