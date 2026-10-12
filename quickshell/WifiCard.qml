import QtQuick
import Quickshell.Networking

// Glance card for Wi-Fi, from NetworkManager.
GlanceCard {
    label: "Wi-Fi"
    glyph: Icons.wifi
    value: !Networking.wifiHardwareEnabled ? "Off" : Networking.wifiEnabled ? "On" : "Off"
    detail: !Networking.wifiHardwareEnabled ? "Turned off by a hardware switch"
        : Networking.wifiEnabled ? "Wireless is enabled" : "Turn it on from Home"
}
