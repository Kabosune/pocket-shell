import QtQuick

// Quick settings, pulled down from the top: brightness, volume and the
// quick toggles. Opens with Select or by tapping the status icons.
//
// Controller: up/down choose a row, left/right adjust it (or move along
// the toggles), A mutes / switches a toggle, B or Select closes.
Item {
    id: panel

    property bool open: false
    property int row: 0
    property int toggleIndex: 0

    readonly property var rows: ["brightness", "volume", "toggles"]
    readonly property real stepSize: 0.05

    function show() {
        Brightness.refresh();
        row = 0;
        open = true;
        Store.quickPanelOpen = true;
        Sfx.play("open", 1);
    }

    function hide() {
        open = false;
        Store.quickPanelOpen = false;
        Sfx.play("back", 1);
    }

    function adjust(direction) {
        const name = rows[row];
        if (name === "brightness") {
            Brightness.step(direction * stepSize);
        } else if (name === "volume") {
            if (volume.item)
                volume.item.step(direction * stepSize);
        } else {
            toggleIndex = Math.max(0, Math.min(toggles.count - 1, toggleIndex + direction));
        }
    }

    function handle(button) {
        switch (button) {
        case "up":
            row = Math.max(0, row - 1);
            break;
        case "down":
            row = Math.min(rows.length - 1, row + 1);
            break;
        case "left":
            adjust(-1);
            break;
        case "right":
            adjust(1);
            break;
        case "a":
            if (rows[row] === "volume" && volume.item)
                volume.item.toggleMute();
            else if (rows[row] === "toggles")
                toggles.activate(toggleIndex);
            break;
        case "b":
        case "select":
        case "home":
        case "start":
            hide();
            break;
        }
    }

    visible: open || sheet.y > -sheet.height

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: panel.open ? 0.6 : 0
        Behavior on opacity { NumberAnimation { duration: 160 } }

        MouseArea {
            anchors.fill: parent
            enabled: panel.open
            onClicked: panel.hide()
        }
    }

    Surface {
        id: sheet
        anchors.horizontalCenter: parent.horizontalCenter
        width: 560
        height: content.implicitHeight + 40
        y: panel.open ? 48 : -height - 8
        color: Theme.surfaceStrong
        Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

        // Keep taps on the sheet from closing it
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 20
            spacing: 10

            Item {
                width: parent.width
                height: titleText.implicitHeight

                DisplayText {
                    id: titleText
                    text: "Quick settings"
                    color: Theme.textStrong
                    weight: Font.Black
                    size: 20
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    KeyCap {
                        anchors.verticalCenter: parent.verticalCenter
                        label: "B"
                        round: true
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: Theme.label("Close")
                        color: Theme.textHint
                        font.family: Theme.bodyFont
                        font.weight: Font.Bold
                        font.pixelSize: 12
                    }
                }
            }

            SettingRow {
                width: parent.width
                label: "Brightness"
                glyph: Icons.brightness
                value: Brightness.level < 0 ? 0 : Brightness.level
                note: Brightness.problem || (Brightness.available ? "" : "Checking…")
                usable: Brightness.available
                focused: Controller.active && panel.open && panel.row === 0
                onMoved: v => Brightness.set(v)
            }

            Item {
                width: parent.width
                height: volume.status === Loader.Ready ? volume.item.implicitHeight : volumeFallback.implicitHeight

                Loader {
                    id: volume
                    width: parent.width
                    source: "VolumeRow.qml"
                }
                Binding {
                    when: volume.status === Loader.Ready
                    target: volume.item
                    property: "focused"
                    value: Controller.active && panel.open && panel.row === 1
                }

                SettingRow {
                    id: volumeFallback
                    width: parent.width
                    visible: volume.status === Loader.Error
                    label: "Volume"
                    glyph: Icons.volume
                    note: "Audio service not available"
                    usable: false
                    focused: Controller.active && panel.open && panel.row === 1
                }
            }

            QuickToggles {
                id: toggles
                width: parent.width
                color: "transparent"
                border.width: 0
                focusedIndex: Controller.active && panel.open && panel.row === 2 ? panel.toggleIndex : -1
            }
        }
    }
}
