import QtQuick
import Quickshell.Services.UPower

// Glance card for the battery, from UPower.
GlanceCard {
    readonly property var device: UPower.displayDevice
    readonly property bool hasBattery: device !== null && device.ready && device.isLaptopBattery
    readonly property real level: {
        if (!hasBattery)
            return 0;
        const p = device.percentage;
        return p > 1 ? p / 100 : p;
    }

    function duration(seconds) {
        if (!seconds || seconds <= 0)
            return "";
        const h = Math.floor(seconds / 3600);
        const m = Math.round((seconds % 3600) / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }

    label: "Battery"
    glyph: Icons.battery
    value: hasBattery ? `${Math.round(level * 100)}%` : "—"
    fill: hasBattery ? level : -1
    detail: {
        if (!hasBattery)
            return "No battery reported";
        if (!UPower.onBattery) {
            const full = duration(device.timeToFull);
            return full ? `Charging · full in ${full}` : "Plugged in";
        }
        const left = duration(device.timeToEmpty);
        return left ? `About ${left} left` : "On battery";
    }
}
