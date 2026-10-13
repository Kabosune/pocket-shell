import QtQuick
import Quickshell.Bluetooth

// Bluetooth on/off through BlueZ.
ToggleButton {
    readonly property var adapter: Bluetooth.defaultAdapter

    label: "Bluetooth"
    glyph: Icons.bluetooth
    active: adapter !== null && adapter.enabled
    available: adapter !== null
    onActivated: {
        Sfx.play(adapter.enabled ? "toggle-off" : "toggle-on", 2);
        adapter.enabled = !adapter.enabled;
    }
}
