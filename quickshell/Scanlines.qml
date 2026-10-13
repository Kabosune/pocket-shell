import QtQuick

// Faint CRT lines over the whole screen (style.scanlines). Plain
// rectangles, so the renderer batches them into one draw.
Item {
    id: lines

    property real spacing: 3
    property color shade: Qt.rgba(0, 0, 0, 0.22)

    Repeater {
        model: lines.visible ? Math.ceil(lines.height / lines.spacing) : 0
        Rectangle {
            required property int index
            y: index * lines.spacing
            width: lines.width
            height: 1
            color: lines.shade
        }
    }
}
