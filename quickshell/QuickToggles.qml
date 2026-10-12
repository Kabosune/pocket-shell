import QtQuick

// Quick toggles card. Wi-Fi and Bluetooth load separately so a missing
// service greys out its button instead of breaking the card.
Surface {
    id: card

    property int focusedIndex: -1
    readonly property int count: 3

    function activate(index) {
        const item = index === 0 ? wifi.item : index === 1 ? bt.item : null;
        if (item && item.available)
            item.activated();
    }

    implicitHeight: row.implicitHeight + 28

    Row {
        id: row
        anchors.centerIn: parent
        spacing: (card.width - 36 - card.count * 76) / (card.count - 1)

        Item {
            width: 76
            height: wifi.status === Loader.Ready ? wifi.implicitHeight : wifiFallback.implicitHeight
            Loader { id: wifi; source: "WifiToggle.qml" }
            Binding {
                when: wifi.status === Loader.Ready
                target: wifi.item
                property: "focused"
                value: card.focusedIndex === 0
            }
            ToggleButton {
                id: wifiFallback
                visible: wifi.status === Loader.Error
                label: "Wi-Fi"
                glyph: Icons.wifi
                available: false
                focused: card.focusedIndex === 0
            }
        }

        Item {
            width: 76
            height: bt.status === Loader.Ready ? bt.implicitHeight : btFallback.implicitHeight
            Loader { id: bt; source: "BluetoothToggle.qml" }
            Binding {
                when: bt.status === Loader.Ready
                target: bt.item
                property: "focused"
                value: card.focusedIndex === 1
            }
            ToggleButton {
                id: btFallback
                visible: bt.status === Loader.Error
                label: "Bluetooth"
                glyph: Icons.bluetooth
                available: false
                focused: card.focusedIndex === 1
            }
        }

        ToggleButton {
            label: "Rotate"
            glyph: Icons.rotate
            available: false
            focused: card.focusedIndex === 2
        }
    }
}
