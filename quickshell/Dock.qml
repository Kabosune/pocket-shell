import QtQuick

// App dock: pinned apps, then Settings. The focused item gets the focus
// ring, a slight zoom and a name pill.
//
// items: [{ id, name, entry }] for apps, or [{ id, name, glyph }] for built-ins.
Surface {
    id: dock

    property var items: []
    property int focusedIndex: -1
    signal tapped(int index)
    signal activated(int index)

    implicitWidth: row.implicitWidth + 28
    implicitHeight: row.implicitHeight + 20
    radius: Theme.rDock

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 14

        Repeater {
            model: dock.items

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

                        AppIcon {
                            anchors.centerIn: parent
                            visible: slot.modelData.entry !== undefined
                            entry: slot.modelData.entry ?? null
                            size: 32
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: slot.modelData.glyph !== undefined
                            glyph: slot.modelData.glyph ?? ({})
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
                        dock.activated(slot.index);
                    }
                }
            }
        }
    }
}
