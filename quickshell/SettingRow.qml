import QtQuick

// A labelled slider row for Quick settings: icon, name, slider, value.
Item {
    id: row

    property string label
    property var glyph
    property real value: 0
    property string valueText: `${Math.round(value * 100)}%`
    property string note: ""
    property bool focused: false
    property bool usable: true
    signal moved(real value)
    signal iconTapped()

    implicitHeight: 64

    Chip {
        id: iconButton
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 48
        height: 48
        pressed: iconTap.pressed

        Icon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Theme.bevel ? -1 : 0
            glyph: row.glyph
            size: 24
            color: Theme.iconOnChip
        }

        MouseArea {
            id: iconTap
            anchors.fill: parent
            onClicked: row.iconTapped()
        }
    }

    Column {
        anchors.left: iconButton.right
        anchors.leftMargin: 16
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Item {
            width: parent.width
            height: nameText.implicitHeight

            Text {
                id: nameText
                text: Theme.label(row.label)
                color: Theme.textStrong
                font.family: Theme.bodyFont
                font.weight: Font.ExtraBold
                font.pixelSize: 14
            }

            Text {
                anchors.right: parent.right
                text: row.note || row.valueText
                color: row.note ? Theme.textMuted : Theme.textStrong
                font.family: Theme.bodyFont
                font.weight: Font.Bold
                font.pixelSize: 13
            }
        }

        ValueSlider {
            width: parent.width
            value: row.value
            focused: row.focused
            usable: row.usable
            onMoved: v => row.moved(v)
        }
    }
}
