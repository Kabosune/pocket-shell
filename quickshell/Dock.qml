import QtQuick

// App dock. The focused item gets the double focus ring and a name pill.
// Touch focuses and activates in one tap; the controller will move focus.
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
    signal activated(string appId)

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

                    // Focus ring: accent outer ring with a dark gap (sharp), or just the accent ring (soft)
                    Rectangle {
                        visible: slot.focused
                        anchors.fill: parent
                        anchors.margins: -(Theme.focusGapWidth + Theme.focusRingWidth)
                        radius: Theme.rIcon + Theme.focusGapWidth + Theme.focusRingWidth
                        color: "transparent"
                        border.width: Theme.focusRingWidth
                        border.color: Theme.accent
                    }
                    Rectangle {
                        visible: slot.focused && Theme.focusGapWidth > 0
                        anchors.fill: parent
                        anchors.margins: -Theme.focusGapWidth
                        radius: Theme.rIcon + Theme.focusGapWidth
                        color: "transparent"
                        border.width: Theme.focusGapWidth
                        border.color: Theme.focusGap
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
                        dock.focusedIndex = slot.index;
                        dock.activated(slot.modelData.id);
                    }
                }
            }
        }
    }
}
