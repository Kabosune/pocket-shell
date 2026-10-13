import QtQuick
import Quickshell.Networking

// "wifi on" / "wifi off" for text-style status bars.
Text {
    text: Networking.wifiEnabled ? "wifi on" : "wifi off"
    color: Networking.wifiEnabled ? Theme.text : Theme.textMuted
    font.family: Theme.bodyFont
    font.pixelSize: 13
}
