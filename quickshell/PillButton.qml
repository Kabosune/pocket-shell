import QtQuick

// Wide labelled button for sheets and menus.
Rectangle {
    id: button

    property alias label: labelText.text
    property bool primary: false
    signal activated()

    implicitWidth: Math.max(220, labelText.implicitWidth + 40)
    implicitHeight: 52
    radius: Theme.rBtn
    color: primary ? Theme.accent : Theme.chip
    opacity: tap.pressed ? 0.8 : 1

    Text {
        id: labelText
        anchors.centerIn: parent
        color: button.primary ? Theme.accentInk : Theme.textStrong
        font.family: Theme.bodyFont
        font.weight: Font.ExtraBold
        font.pixelSize: 16
    }

    MouseArea {
        id: tap
        anchors.fill: parent
        onClicked: button.activated()
    }
}
