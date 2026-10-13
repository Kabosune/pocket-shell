import QtQuick

// Quick-toggle tile with a label underneath.
Item {
    id: toggle

    property string label
    property var glyph
    property bool active: false
    property bool available: true
    property bool focused: false
    property real size: 52
    signal activated()

    implicitWidth: Math.max(76, size + 24)
    implicitHeight: column.implicitHeight
    opacity: available ? 1 : 0.45

    Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: toggle.size
            height: toggle.size

            FocusRing {
                visible: toggle.focused
                radius: disc.radius
            }

            Chip {
                id: disc
                anchors.fill: parent
                radius: toggle.active ? Theme.rBtn : Theme.rPill
                active: toggle.active
                pressed: tap.pressed

                Icon {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: Theme.bevel ? -1 : 0
                    glyph: toggle.glyph
                    size: toggle.size * 0.42
                    weight: Theme.squareIcons ? 2 : 1.9
                    color: toggle.active ? Theme.accentInk : Theme.iconOnChip
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Theme.label(toggle.label)
            color: toggle.active ? Theme.textStrong : Theme.text
            font.family: Theme.bodyFont
            font.weight: toggle.active ? Font.Black : Font.Bold
            font.pixelSize: toggle.size > 56 ? 13 : 12
        }
    }

    MouseArea {
        id: tap
        anchors.fill: parent
        enabled: toggle.available
        onClicked: toggle.activated()
    }
}
