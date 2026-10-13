import QtQuick

// Big page title, top left (Apps, Library, Glance). Themes can add a
// prefix in the accent colour, like a shell path: "~/library".
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
        text: title.text
        color: title.color
        weight: Font.Black
        size: 34
    }
}
