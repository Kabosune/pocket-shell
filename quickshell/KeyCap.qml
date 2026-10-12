import QtQuick

// A controller button label: L1, R1, A, B, SELECT...
Rectangle {
    id: cap

    property alias label: labelText.text
    property bool round: false
    property real borderAlpha: 0.35

    implicitWidth: round ? 20 : Math.max(26, labelText.implicitWidth + 12)
    implicitHeight: 20
    radius: round ? Theme.rPill : Theme.rKey
    color: "transparent"
    border.width: 1
    border.color: Qt.rgba(207 / 255, 230 / 255, 225 / 255, borderAlpha)

    Text {
        id: labelText
        anchors.centerIn: parent
        color: Theme.text
        font.family: Theme.bodyFont
        font.weight: Font.ExtraBold
        font.pixelSize: cap.label.length > 2 ? 10 : 11
    }
}
