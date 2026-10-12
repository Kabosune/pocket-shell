import QtQuick

// Round quick-toggle with a label underneath.
Item {
    id: toggle

    property string label
    property var glyph
    property bool active: false
    property bool available: true
    property bool focused: false
    signal activated()

    implicitWidth: 76
    implicitHeight: column.implicitHeight
    opacity: available ? (tap.pressed ? 0.8 : 1) : 0.45

    Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Rectangle {
            id: disc
            anchors.horizontalCenter: parent.horizontalCenter
            width: 52
            height: 52
            radius: toggle.active ? Theme.rBtn : Theme.rPill
            color: toggle.active ? Theme.accent : Theme.chip

            FocusRing {
                visible: toggle.focused
                radius: disc.radius
            }

            Icon {
                anchors.centerIn: parent
                glyph: toggle.glyph
                size: 22
                weight: 1.9
                color: toggle.active ? Theme.accentInk : Theme.iconOnChip
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: toggle.label
            color: Theme.text
            font.family: Theme.bodyFont
            font.weight: Font.Bold
            font.pixelSize: 12
        }
    }

    MouseArea {
        id: tap
        anchors.fill: parent
        enabled: toggle.available
        onClicked: toggle.activated()
    }
}
