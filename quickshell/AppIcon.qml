import QtQuick
import Quickshell

// An app's icon from the system icon theme, or its first letter if the
// theme doesn't have one.
Item {
    id: appIcon

    property var entry: null
    property string fallbackName: entry ? entry.name : ""
    property real size: 32
    property color letterColor: Theme.iconOnChip

    readonly property string source: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : ""

    implicitWidth: size
    implicitHeight: size

    Image {
        id: image
        anchors.fill: parent
        source: appIcon.source
        sourceSize.width: appIcon.size * 2
        sourceSize.height: appIcon.size * 2
        asynchronous: true
        smooth: true
        mipmap: true
        visible: status === Image.Ready
    }

    Text {
        anchors.centerIn: parent
        visible: image.status !== Image.Ready
        text: appIcon.fallbackName.length > 0 ? appIcon.fallbackName.charAt(0).toUpperCase() : "?"
        color: appIcon.letterColor
        font.family: Theme.displayFont
        font.weight: Font.Black
        font.pixelSize: appIcon.size * 0.75
    }
}
