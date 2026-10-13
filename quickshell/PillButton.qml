import QtQuick

// Wide labelled button for sheets and menus.
Item {
    id: button

    property string label: ""
    property bool primary: false
    property bool focused: false
    signal activated()

    implicitWidth: Math.max(220, labelText.implicitWidth + 40)
    implicitHeight: 52

    FocusRing {
        visible: button.focused
        radius: background.radius
    }

    Chip {
        id: background
        anchors.fill: parent
        radius: Theme.rBtn
        active: button.primary
        pressed: tap.pressed
    }

    Text {
        id: labelText
        anchors.centerIn: parent
        text: Theme.label(button.label)
        anchors.verticalCenterOffset: Theme.bevel ? -1 : 0
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
