import QtQuick

// App dock: pinned apps, then Settings. The focused item gets the focus
// ring, a lift and its name, either in a pill above it or, with `banner`,
// in a name panel at the left of the dock (Stylus layout).
//
// items: [{ id, name, entry }] for apps, or [{ id, name, glyph }] for built-ins.
Surface {
    id: dock

    property var items: []
    property int focusedIndex: -1
    property real tileSize: 56
    property bool banner: false
    // The item the banner describes when nothing is focused (last touched).
    property int shownIndex: 0
    signal tapped(int index)
    signal activated(int index)

    readonly property var shownItem: items.length > 0
        ? items[Math.max(0, Math.min(focusedIndex >= 0 ? focusedIndex : shownIndex, items.length - 1))] : null

    implicitWidth: row.implicitWidth + 28
    implicitHeight: row.implicitHeight + 20
    radius: Theme.rDock

    // Name panel (banner mode)
    Rectangle {
        id: nameBanner
        visible: dock.banner
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        width: 200
        height: dock.tileSize + 22
        radius: Theme.rKey
        color: Theme.accentPale
        border.width: 2
        border.color: Theme.accent

        Column {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            spacing: 2

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: dock.shownItem ? dock.shownItem.name : ""
                color: Theme.mix(Theme.accent, Qt.rgba(0, 0, 0, 1), 0.7)
                font.family: Theme.displayFont
                font.weight: Font.Bold
                font.pixelSize: 26
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: {
                    const it = dock.shownItem;
                    if (!it)
                        return "";
                    if (it.entry)
                        return it.entry.genericName || it.entry.comment || "App";
                    return it.id === "settings" ? "Themes and sessions" : "";
                }
                color: Theme.mix(Theme.accent, Qt.rgba(0, 0, 0, 1), 0.55)
                font.family: Theme.bodyFont
                font.weight: Font.Bold
                font.pixelSize: 12
            }
        }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: dock.banner ? undefined : parent.horizontalCenter
        anchors.left: dock.banner ? nameBanner.right : undefined
        anchors.right: dock.banner ? parent.right : undefined
        anchors.leftMargin: 24
        anchors.rightMargin: 22
        spacing: dock.banner
            ? Math.max(14, (width - dock.items.length * dock.tileSize) / Math.max(1, dock.items.length - 1))
            : 14

        Repeater {
            model: dock.items

            Item {
                id: slot
                required property var modelData
                required property int index
                readonly property bool focused: index === dock.focusedIndex

                width: dock.tileSize
                height: dock.tileSize
                z: focused ? 1 : 0

                Item {
                    anchors.fill: parent
                    scale: slot.focused && !dock.banner ? 1.08 : 1
                    y: slot.focused && dock.banner ? -6 : 0
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    FocusRing {
                        visible: slot.focused
                        radius: Theme.rIcon
                    }

                    Chip {
                        anchors.fill: parent
                        focused: slot.focused
                        pressed: tap.pressed

                        AppIcon {
                            anchors.centerIn: parent
                            visible: slot.modelData.entry !== undefined
                            entry: slot.modelData.entry ?? null
                            size: dock.tileSize * 0.58
                        }

                        Icon {
                            anchors.centerIn: parent
                            visible: slot.modelData.glyph !== undefined
                            glyph: slot.modelData.glyph ?? ({})
                            size: dock.tileSize * 0.46
                            color: slot.focused ? Theme.textStrong : Theme.iconOnChip
                        }
                    }
                }

                Rectangle {
                    visible: slot.focused && !dock.banner
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
                        dock.shownIndex = slot.index;
                        dock.tapped(slot.index);
                        dock.activated(slot.index);
                    }
                }
            }
        }
    }
}
