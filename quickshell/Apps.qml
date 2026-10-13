import QtQuick
import Quickshell

// Apps page: every installed app (desktop entries), alphabetically.
// A opens, X pins to / unpins from the Home dock.
Item {
    id: page

    property var shell: null
    property bool current: false
    property int focusedIndex: 0

    readonly property int columns: 6

    // Our own "switch to Pocket Shell" launcher is for other desktops; here
    // it would only restart the shell.
    readonly property var hiddenIds: ["pocket-shell"]

    readonly property var apps: {
        const list = DesktopEntries.applications.values.filter(e => hiddenIds.indexOf(e.id) < 0);
        list.sort((a, b) => a.name.localeCompare(b.name));
        return list;
    }

    function move(step) {
        if (apps.length === 0)
            return;
        focusedIndex = Math.max(0, Math.min(apps.length - 1, focusedIndex + step));
    }

    function launch(index) {
        const entry = apps[index];
        if (entry)
            Wm.launchEntry(entry);
    }

    function togglePin(index) {
        const entry = apps[index];
        if (!entry)
            return;
        const wasPinned = Store.isPinned(entry.id);
        if (!Store.togglePin(entry.id)) {
            if (shell)
                shell.toast(`The dock is full (${Store.maxPins} apps)`, "error");
            return;
        }
        if (shell)
            shell.toast(wasPinned ? `Unpinned ${entry.name}` : `Pinned ${entry.name} to the dock`);
    }

    function handle(button) {
        switch (button) {
        case "left":
            move(-1);
            return true;
        case "right":
            move(1);
            return true;
        case "up":
            move(-columns);
            return true;
        case "down":
            move(columns);
            return true;
        case "a":
            launch(focusedIndex);
            return true;
        case "x":
            togglePin(focusedIndex);
            return true;
        }
        return false;
    }

    onAppsChanged: focusedIndex = Math.max(0, Math.min(focusedIndex, apps.length - 1))

    PageBackdrop {}

    PageTitle {
        text: "Apps"
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 48
        y: 72
        text: page.apps.length === 1 ? "1 app" : `${page.apps.length} apps`
        color: Theme.textMuted
        font.family: Theme.bodyFont
        font.weight: Font.Bold
        font.pixelSize: 14
    }

    GridView {
        id: grid
        x: 48
        y: 116
        width: parent.width - 96
        height: parent.height - y - 48
        cellWidth: width / page.columns
        cellHeight: 108
        clip: true
        model: page.apps
        currentIndex: page.focusedIndex
        highlightFollowsCurrentItem: false
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property bool focused: Controller.active && index === page.focusedIndex
            readonly property bool pinned: Store.isPinned(modelData.id)

            width: grid.cellWidth
            height: grid.cellHeight

            Column {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 8
                spacing: 8

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 64
                    height: 64
                    scale: cell.focused ? 1.08 : 1
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    FocusRing {
                        visible: cell.focused
                        radius: Theme.rIcon
                    }

                    Chip {
                        anchors.fill: parent
                        focused: cell.focused
                        pressed: tap.pressed

                        AppIcon {
                            anchors.centerIn: parent
                            entry: cell.modelData
                            size: 40
                        }
                    }

                    // Pinned marker
                    Rectangle {
                        visible: cell.pinned
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: -4
                        width: 18
                        height: 18
                        radius: Theme.rPill
                        color: Theme.accent

                        Icon {
                            anchors.centerIn: parent
                            glyph: Icons.pin
                            size: 12
                            weight: 2.2
                            color: Theme.accentInk
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: grid.cellWidth - 12
                    horizontalAlignment: Text.AlignHCenter
                    elide: Text.ElideRight
                    text: cell.modelData.name
                    color: cell.focused ? Theme.accent : Theme.text
                    font.family: Theme.bodyFont
                    font.weight: cell.focused ? Font.ExtraBold : Font.DemiBold
                    font.pixelSize: 13
                }
            }

            MouseArea {
                id: tap
                anchors.fill: parent
                onClicked: {
                    page.focusedIndex = cell.index;
                    page.launch(cell.index);
                }
                onPressAndHold: {
                    page.focusedIndex = cell.index;
                    page.togglePin(cell.index);
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: page.apps.length === 0
        text: "No apps found"
        color: Theme.textMuted
        font.family: Theme.bodyFont
        font.weight: Font.Bold
        font.pixelSize: 18
    }

    HintBar {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        items: [
            { key: "A", round: true, text: "Open" },
            { key: "X", round: true, text: "Pin to dock" },
            { key: "B", round: true, text: "Home" }
        ]
    }
}
