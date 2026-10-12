import QtQuick
import Quickshell.Io

// Quick toggles card. Wi-Fi and Bluetooth load separately so a missing
// service greys out its button instead of breaking the card.
Surface {
    id: card

    implicitHeight: row.implicitHeight + 28

    Row {
        id: row
        anchors.centerIn: parent
        spacing: (card.width - 36 - 4 * 76) / 3

        Item {
            width: 76
            height: wifi.status === Loader.Ready ? wifi.implicitHeight : wifiFallback.implicitHeight
            Loader { id: wifi; source: "WifiToggle.qml" }
            ToggleButton {
                id: wifiFallback
                visible: wifi.status === Loader.Error
                label: "Wi-Fi"
                glyph: Icons.wifi
                available: false
            }
        }

        Item {
            width: 76
            height: bt.status === Loader.Ready ? bt.implicitHeight : btFallback.implicitHeight
            Loader { id: bt; source: "BluetoothToggle.qml" }
            ToggleButton {
                id: btFallback
                visible: bt.status === Loader.Error
                label: "Bluetooth"
                glyph: Icons.bluetooth
                available: false
            }
        }

        ToggleButton {
            label: "Rotate"
            glyph: Icons.rotate
            available: false
        }

        ToggleButton {
            label: "Game mode"
            glyph: Icons.gamepad
            onActivated: toSteam.running = true
        }
    }

    Process {
        id: toSteam
        command: ["steamos-session-select", "gamescope"]
    }
}
