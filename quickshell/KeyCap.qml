import QtQuick

// A controller button label: L1, R1, A, B, SELECT...
// Outlined by default; themes with "keys": "filled" get solid caps.
Rectangle {
    id: cap

    property alias label: labelText.text
    property bool round: false
    readonly property bool filled: Theme.keyStyle === "filled"

    implicitWidth: round ? 20 : Math.max(26, labelText.implicitWidth + 12)
    implicitHeight: 20
    radius: round ? height / 2 : Theme.rKey
    color: filled ? Theme.textStrong : "transparent"
    border.width: filled ? 0 : 1
    border.color: Theme.keyBorder

    DisplayText {
        id: labelText
        anchors.centerIn: parent
        color: cap.filled ? Theme.bg : Theme.text
        font.family: cap.filled ? Theme.displayFont : Theme.bodyFont
        weight: Font.ExtraBold
        size: cap.label.length > 2 ? 10 : 11
    }
}
