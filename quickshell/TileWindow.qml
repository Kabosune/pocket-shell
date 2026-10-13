import QtQuick

// A "terminal window" frame for the tiles Home layout: a thin title bar
// with a name on the left and either a status word or window buttons on
// the right. Content goes in the area under the bar; `barHeight` lets
// the page place things there.
Surface {
    id: win

    property string title: ""
    property string status: ""
    property bool active: false
    readonly property real barHeight: 22

    border.color: active ? Theme.accent : Theme.surfaceBorder

    Rectangle {
        id: titleBar
        x: win.border.width
        y: win.border.width
        width: win.width - win.border.width * 2
        height: win.barHeight - win.border.width
        radius: Math.max(0, win.radius - win.border.width)
        color: Theme.chip

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.surfaceBorder
        }

        Rectangle {
            id: bullet
            x: 9
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            color: win.active ? Theme.accent : Theme.textMuted
        }

        Text {
            anchors.left: bullet.right
            anchors.leftMargin: 7
            anchors.right: statusText.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: Theme.label(win.title)
            color: win.active ? Theme.textStrong : Theme.text
            font.family: Theme.bodyFont
            font.pixelSize: 11
        }

        Text {
            id: statusText
            anchors.right: parent.right
            anchors.rightMargin: 9
            anchors.verticalCenter: parent.verticalCenter
            text: win.status !== "" ? Theme.label(win.status) : "─  □  ×"
            color: Theme.textMuted
            font.family: Theme.bodyFont
            font.pixelSize: 10
        }
    }
}
