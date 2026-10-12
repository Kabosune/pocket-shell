import QtQuick

// One small card on the Glance page: label, a big value, a detail line.
Surface {
    id: card

    property string label
    property var glyph
    property string value
    property string detail
    property real fill: -1   // 0..1 shows a bar; -1 hides it

    Column {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 6

        Row {
            spacing: 8

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                glyph: card.glyph
                size: 18
                color: Theme.textMuted
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: card.label.toUpperCase()
                color: Theme.textMuted
                font.family: Theme.bodyFont
                font.weight: Font.ExtraBold
                font.pixelSize: 11
                font.letterSpacing: 1.5
            }
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: card.value
            color: Theme.textStrong
            font.family: Theme.displayFont
            font.weight: Font.Black
            font.pixelSize: 30
        }

        Rectangle {
            visible: card.fill >= 0
            width: parent.width
            height: 6
            radius: 3
            color: Theme.chip

            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, card.fill))
                height: parent.height
                radius: parent.radius
                color: Theme.accent
            }
        }

        Text {
            width: parent.width
            elide: Text.ElideRight
            text: card.detail
            color: Theme.textMuted
            font.family: Theme.bodyFont
            font.weight: Font.DemiBold
            font.pixelSize: 13
        }
    }
}
