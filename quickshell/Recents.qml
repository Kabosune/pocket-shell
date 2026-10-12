import QtQuick

// Recents: open apps and games as cards. Hold Home to open it.
// Left/right to choose, A to switch, X to close the app, B to leave.
Item {
    id: recents

    property bool open: false
    property int focusedIndex: 0
    property var items: []

    function show() {
        items = Wm.apps.slice();
        focusedIndex = 0;
        open = true;
    }

    function hide() {
        open = false;
    }

    function switchTo(index) {
        const app = items[index];
        hide();
        if (app)
            Wm.focusApp(app);
    }

    function closeAt(index) {
        const app = items[index];
        if (!app)
            return;
        Wm.closeApp(app);
        const list = items.slice();
        list.splice(index, 1);
        items = list;
        focusedIndex = Math.max(0, Math.min(focusedIndex, items.length - 1));
    }

    function handle(button) {
        switch (button) {
        case "left":
            focusedIndex = Math.max(0, focusedIndex - 1);
            break;
        case "right":
            focusedIndex = Math.min(items.length - 1, focusedIndex + 1);
            break;
        case "a":
            switchTo(focusedIndex);
            break;
        case "x":
            closeAt(focusedIndex);
            break;
        case "b":
        case "home":
        case "recents":
        case "start":
            hide();
            break;
        }
    }

    visible: open

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(6 / 255, 16 / 255, 18 / 255, 0.85)

        MouseArea {
            anchors.fill: parent
            onClicked: recents.hide()
        }
    }

    Text {
        x: 48
        y: 58
        text: "Recents"
        color: Theme.textStrong
        font.family: Theme.displayFont
        font.weight: Font.Black
        font.pixelSize: 34
    }

    Text {
        anchors.centerIn: parent
        visible: recents.items.length === 0
        text: "No apps open"
        color: Theme.textMuted
        font.family: Theme.bodyFont
        font.weight: Font.Bold
        font.pixelSize: 18
    }

    ListView {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 240
        leftMargin: 48
        rightMargin: 48
        orientation: ListView.Horizontal
        spacing: 20
        clip: false
        model: recents.items
        currentIndex: recents.focusedIndex
        highlightFollowsCurrentItem: false
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Item {
            id: card
            required property var modelData
            required property int index
            readonly property bool focused: Controller.active && index === recents.focusedIndex

            width: 260
            height: 200
            y: (list.height - height) / 2
            scale: focused ? 1.05 : 1
            Behavior on scale { NumberAnimation { duration: 120 } }

            FocusRing {
                visible: card.focused
                radius: Theme.rCard
            }

            Surface {
                anchors.fill: parent
                color: Qt.rgba(14 / 255, 36 / 255, 40 / 255, 0.95)

                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: 18
                    spacing: 4

                    Rectangle {
                        width: 56
                        height: 56
                        radius: Theme.rIcon
                        color: Theme.chip

                        AppIcon {
                            anchors.centerIn: parent
                            entry: Wm.entryFor(card.modelData)
                            fallbackName: card.modelData.title
                            size: 34
                        }
                    }

                    Item { width: 1; height: 8 }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: Wm.appName(card.modelData)
                        color: Theme.textStrong
                        font.family: Theme.bodyFont
                        font.weight: Font.ExtraBold
                        font.pixelSize: 17
                    }

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: card.modelData.title
                        color: Theme.textMuted
                        font.family: Theme.bodyFont
                        font.weight: Font.DemiBold
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: recents.switchTo(card.index)
                }

                Rectangle {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 10
                    width: 36
                    height: 36
                    radius: Theme.rPill
                    color: Theme.chip

                    Icon {
                        anchors.centerIn: parent
                        glyph: Icons.close
                        size: 18
                        color: Theme.text
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        onClicked: recents.closeAt(card.index)
                    }
                }
            }
        }
    }

    HintBar {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        items: [
            { key: "A", round: true, text: "Switch" },
            { key: "X", round: true, text: "Close" },
            { key: "B", round: true, text: "Back" }
        ]
    }
}
