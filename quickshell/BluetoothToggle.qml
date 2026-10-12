import QtQuick
import Quickshell.Bluetooth

// Bluetooth on/off through BlueZ.
ToggleButton {
    readonly property var adapter: Bluetooth.defaultAdapter

    label: "Bluetooth"
    glyph: Icons.bluetooth
    active: adapter !== null && adapter.enabled
    available: adapter !== null
    onActivated: adapter.enabled = !adapter.enabled
}
