import QtQuick

// App dock. The focused item gets the focus ring, a slight zoom and a name pill.
Surface {
    id: dock

    property int focusedIndex: -1
    readonly property var apps: [
        { id: "browser",  name: "Browser",  glyph: Icons.browser },
        { id: "files",    name: "Files",    glyph: Icons.files },
        { id: "music",    name: "Music",    glyph: Icons.music },
        { id: "gallery",  name: "Gallery",  glyph: Icons.gallery },
        { id: "settings", name: "Settings", glyph: Icons.settings }
    ]
    signal tapped(int index)
    signal activated(string appId)

    function activate(index) {
        if (index >= 0 && index < apps.length)
            activated(apps[index].id);
    }

    implicitWidth: row.implicitWidth + 28
    implicitHeight: row.implicitHeight + 20
    radius: Theme.rDock

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 14

        Repeater {
            model: dock.apps

            Item {
                id: slot
                required property var modelData
                required property int index
                readonly property bool focused: index === dock.focusedIndex

                width: 56
                height: 56
                z: focused ? 1 : 0

                Item {
                    anchors.fill: parent
                    scale: slot.focused ? 1.08 : 1
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    FocusRing {
                        visible: slot.focused
                        radius: Theme.rIcon
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.rIcon
                        color: slot.focused ? Theme.chipFocused : Theme.chip
                        opacity: tap.pressed ? 0.8 : 1

                        Icon {
                            anchors.centerIn: parent
                            glyph: slot.modelData.glyph
                            size: 26
                            color: slot.focused ? Theme.textStrong : Theme.iconOnChip
                        }
                    }
                }

                Rectangle {
                    visible: slot.focused
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: -34
                    width: nameText.implicitWidth + 20
                    height: nameText.implicitHeight + 6
                    radius: Theme.rPill
                    color: Theme.accent

                    Text {
                        id: nameText
                        anchors.centerIn: parent
                        text: slot.modelData.name
                        color: Theme.accentInk
                        font.family: Theme.bodyFont
                        font.weight: Font.ExtraBold
                        font.pixelSize: 11
                    }
                }

                MouseArea {
                    id: tap
                    anchors.fill: parent
                    onClicked: {
                        dock.tapped(slot.index);
                        dock.activate(slot.index);
                    }
                }
            }
        }
    }
}
