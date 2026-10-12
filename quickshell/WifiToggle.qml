import QtQuick
import Quickshell.Networking

// Wi-Fi on/off through NetworkManager.
ToggleButton {
    label: "Wi-Fi"
    glyph: Icons.wifi
    active: Networking.wifiEnabled
    available: Networking.wifiHardwareEnabled
    onActivated: Networking.wifiEnabled = !Networking.wifiEnabled
}
