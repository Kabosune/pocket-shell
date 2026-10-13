import QtQuick

// Big page title, top left (Apps, Library, Glance). Themes can add a
// prefix in the accent colour, like a shell path: "~/library", and a
// blinking block cursor after it.
Row {
    id: title

    property string text: ""
    property color color: Theme.textStrong

    x: 48
    y: 58

    DisplayText {
        visible: Theme.titlePrefix !== ""
        text: Theme.titlePrefix
        color: Theme.accent
        weight: Font.Black
        size: 34
    }

    DisplayText {
        id: titleText
        text: title.text
        color: title.color
        weight: Font.Black
        size: 34
    }

    Item {
        visible: Theme.cursor
        width: cursorBlock.width + 6
        height: titleText.height

        Rectangle {
            id: cursorBlock
            x: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 32
            color: Theme.accent
            BlinkCursor on opacity {}
        }
    }
}
