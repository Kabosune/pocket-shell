import QtQuick

// A game's box art, or a title card in the system's colour when there's no art.
Rectangle {
    id: cover

    property string art: ""
    property string title: ""
    property string caption: ""
    property color tint: "#2F5A45"

    radius: Theme.rArt
    color: image.status === Image.Ready ? Theme.surfaceStrong : tint
    clip: true

    Image {
        id: image
        anchors.fill: parent
        anchors.margins: 4
        source: cover.art ? "file://" + cover.art.split("/").map(encodeURIComponent).join("/") : ""
        fillMode: Image.PreserveAspectFit
        sourceSize.width: 240
        sourceSize.height: 320
        asynchronous: true
        visible: status === Image.Ready
    }

    Column {
        visible: image.status !== Image.Ready
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        spacing: 4

        DisplayText {
            width: parent.width
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            text: cover.title
            color: Theme.textStrong
            weight: Font.Black
            size: 16
            lineHeight: 0.95
        }

        Text {
            width: parent.width
            visible: cover.caption !== ""
            elide: Text.ElideRight
            text: cover.caption
            color: Qt.rgba(1, 1, 1, 0.6)
            font.family: Theme.bodyFont
            font.weight: Font.Bold
            font.pixelSize: 11
        }
    }
}
