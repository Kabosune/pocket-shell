import QtQuick

// A pressable tile background (dock icons, toggles, app tiles). Bevel
// themes give it a darker bottom lip.
Rectangle {
    id: chip

    property bool focused: false
    property bool active: false
    property bool pressed: false

    radius: Theme.rIcon
    color: active ? Theme.accent : focused ? Theme.chipFocused : Theme.chip
    border.width: Theme.bevel ? Theme.borderWidth : 0
    border.color: active ? Theme.accentDeep : Theme.surfaceBorder
    opacity: pressed ? 0.8 : 1

    Rectangle {
        visible: Theme.bevel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: chip.border.width
        height: 4
        radius: Math.max(0, chip.radius - chip.border.width)
        color: chip.active ? Theme.accentDeep : Theme.ledge
    }
}
