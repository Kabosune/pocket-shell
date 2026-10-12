import QtQuick

// Controller focus ring around its parent. Sharp: dark gap + accent ring.
// Soft: a single accent ring.
Item {
    id: ring

    property real radius: 0

    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        anchors.margins: -(Theme.focusGapWidth + Theme.focusRingWidth)
        radius: ring.radius + Theme.focusGapWidth + Theme.focusRingWidth
        color: "transparent"
        border.width: Theme.focusRingWidth
        border.color: Theme.accent
    }

    Rectangle {
        visible: Theme.focusGapWidth > 0
        anchors.fill: parent
        anchors.margins: -Theme.focusGapWidth
        radius: ring.radius + Theme.focusGapWidth
        color: "transparent"
        border.width: Theme.focusGapWidth
        border.color: Theme.focusGap
    }
}
