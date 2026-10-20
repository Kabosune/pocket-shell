import QtQuick
import Quickshell.Wayland

// Recents: open apps and games as big cards with a picture of each, most
// recently used first. Hold Home to open it; double-tap Home anywhere to
// jump straight back to the previous app (Main.qml).
//
// Controller: left/right (or L1/R1 for the ends) to choose, A to switch,
// X to close, Y to close everything, B to leave.
// Touch: swipe sideways to browse, tap a card to switch, swipe a card up
// (or tap its ×) to close it.
Item {
    id: recents

    property bool open: false
    property int focusedIndex: 0
    property var items: []

    readonly property real cardWidth: Math.min(440, width * 0.46)
    readonly property real previewHeight: Math.round(cardWidth * 9 / 16)

    signal closedAll()

    function show() {
        items = Wm.appsByRecent.slice();
        focusedIndex = 0;
        open = true;
        list.positionViewAtIndex(0, ListView.Center);
        Wm.refreshWindows();
    }

    function hide() {
        open = false;
        Sfx.play("back", 1);
    }

    function switchTo(index) {
        const app = items[index];
        open = false;
        if (app)
            Wm.focusApp(app);
    }

    // Starts the card's fly-away animation; it calls removeAt() when done.
    function closeAt(index) {
        const card = list.itemAtIndex(index);
        if (card)
            card.dismiss();
        else
            removeAt(index);
    }

    function removeAt(index) {
        const app = items[index];
        if (!app)
            return;
        Wm.closeApp(app);
        const next = items.slice();
        next.splice(index, 1);
        items = next;
        focusedIndex = Math.max(0, Math.min(focusedIndex, items.length - 1));
    }

    function closeAll() {
        if (items.length === 0)
            return;
        Wm.closeApps(items);
        items = [];
        open = false;
    }

    function handle(button) {
        switch (button) {
        case "left":
            focusedIndex = Math.max(0, focusedIndex - 1);
            break;
        case "right":
            focusedIndex = Math.min(items.length - 1, focusedIndex + 1);
            break;
        case "l1":
            focusedIndex = 0;
            break;
        case "r1":
            focusedIndex = Math.max(0, items.length - 1);
            break;
        case "a":
            switchTo(focusedIndex);
            break;
        case "x":
            closeAt(focusedIndex);
            break;
        case "y":
            closeAll();
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
        color: Theme.scrim

        MouseArea {
            anchors.fill: parent
            onClicked: recents.hide()
        }
    }

    DisplayText {
        x: 48
        y: 58
        text: "Recents"
        color: Theme.textStrong
        weight: Font.Black
        size: 34
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 48
        y: 72
        visible: recents.items.length > 0
        text: recents.items.length === 1 ? "1 app open" : `${recents.items.length} apps open`
        color: Theme.textMuted
        font.family: Theme.bodyFont
        font.weight: Font.Bold
        font.pixelSize: 14
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
        anchors.verticalCenterOffset: 14
        height: recents.previewHeight + 110
        orientation: ListView.Horizontal
        spacing: 28
        clip: false
        model: recents.items
        currentIndex: recents.focusedIndex
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width - recents.cardWidth) / 2
        preferredHighlightEnd: (width + recents.cardWidth) / 2
        highlightMoveDuration: 220
        snapMode: ListView.SnapOneItem
        boundsBehavior: Flickable.StopAtBounds
        onCurrentIndexChanged: {
            if (currentIndex >= 0 && currentIndex !== recents.focusedIndex)
                recents.focusedIndex = currentIndex;
        }

        delegate: Item {
            id: card
            required property var modelData
            required property int index
            readonly property bool current: index === recents.focusedIndex
            readonly property bool focused: Controller.active && current
            property bool leaving: false

            function dismiss() {
                if (leaving)
                    return;
                leaving = true;
                flyAway.from = body.y;
                flyAway.start();
            }

            width: recents.cardWidth
            height: list.height
            z: current ? 1 : 0
            scale: current ? 1 : 0.86
            opacity: current ? 1 : 0.6
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Item {
                id: body
                width: parent.width
                height: parent.height
                // How far a swipe has pulled the card up, as 0..1
                readonly property real pulled: Math.min(1, Math.max(0, -y / 160))
                opacity: 1 - pulled * 0.7

                SequentialAnimation {
                    id: flyAway
                    property real from: 0
                    ParallelAnimation {
                        NumberAnimation { target: body; property: "y"; from: flyAway.from; to: -card.height; duration: 200; easing.type: Easing.InCubic }
                        NumberAnimation { target: body; property: "opacity"; to: 0; duration: 200 }
                    }
                    ScriptAction {
                        script: {
                            const i = card.index;
                            Qt.callLater(() => recents.removeAt(i));
                        }
                    }
                }

                NumberAnimation {
                    id: springBack
                    target: body
                    property: "y"
                    to: 0
                    duration: 160
                    easing.type: Easing.OutCubic
                }

                // App name above the picture, like a phone's recents
                Row {
                    id: header
                    x: 4
                    y: 6
                    width: parent.width - 8
                    height: 36
                    spacing: 10

                    Chip {
                        width: 36
                        height: 36
                        anchors.verticalCenter: parent.verticalCenter

                        AppIcon {
                            anchors.centerIn: parent
                            entry: Wm.entryFor(card.modelData)
                            fallbackName: Wm.appName(card.modelData)
                            size: 24
                        }
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 46
                        spacing: 0

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: Wm.appName(card.modelData)
                            color: Theme.textStrong
                            font.family: Theme.bodyFont
                            font.weight: Font.ExtraBold
                            font.pixelSize: 16
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            visible: text !== "" && text !== Wm.appName(card.modelData)
                            text: card.modelData.title
                            color: Theme.textMuted
                            font.family: Theme.bodyFont
                            font.weight: Font.DemiBold
                            font.pixelSize: 12
                        }
                    }
                }

                Item {
                    id: frame
                    y: header.y + header.height + 12
                    width: parent.width
                    height: recents.previewHeight

                    FocusRing {
                        visible: card.focused
                        radius: Theme.rCard
                    }

                    Surface {
                        id: preview
                        anchors.fill: parent
                        color: Theme.surfaceStrong
                        clip: true

                        // Stand-in until (or unless) the picture arrives
                        AppIcon {
                            anchors.centerIn: parent
                            visible: !shot.hasContent
                            entry: Wm.entryFor(card.modelData)
                            fallbackName: Wm.appName(card.modelData)
                            size: 72
                        }

                        // A still picture of the window (Hyprland's
                        // toplevel export), taken when Recents opens.
                        ScreencopyView {
                            id: shot
                            anchors.fill: parent
                            anchors.margins: preview.border.width
                            visible: hasContent
                            live: false
                            captureSource: recents.open && card.modelData ? card.modelData.wayland : null
                        }

                        // In case the first capture comes back empty
                        Timer {
                            interval: 350
                            running: recents.open
                            onTriggered: {
                                if (!shot.hasContent && shot.captureSource)
                                    shot.captureFrame();
                            }
                        }
                    }

                    // Close (touch)
                    Chip {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 10
                        width: 36
                        height: 36
                        radius: Theme.rPill
                        opacity: 0.92

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

                TapHandler {
                    onTapped: {
                        if (card.current)
                            recents.switchTo(card.index);
                        else
                            recents.focusedIndex = card.index;
                    }
                }

                // Swipe up to close. Only vertical drags; sideways ones
                // still scroll the list.
                DragHandler {
                    id: swipe
                    target: body
                    xAxis.enabled: false
                    yAxis.minimum: -card.height
                    yAxis.maximum: 0
                    enabled: !card.leaving
                    onActiveChanged: {
                        if (active)
                            return;
                        if (body.y < -90)
                            card.dismiss();
                        else
                            springBack.start();
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                y: 6 + 36 + 12 + recents.previewHeight + 10
                visible: card.current && !Controller.active && body.y === 0
                text: Theme.label("Swipe up to close")
                color: Theme.textHint
                font.family: Theme.bodyFont
                font.weight: Font.Bold
                font.pixelSize: 12
            }
        }
    }

    // Close all (touch)
    PillButton {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 46
        visible: recents.items.length > 1 && !Controller.active
        label: "Close all"
        onActivated: recents.closeAll()
    }

    HintBar {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        items: recents.items.length === 0 ? [{ key: "B", round: true, text: "Back" }] : [
            { key: "A", round: true, text: "Switch" },
            { key: "X", round: true, text: "Close" },
            { key: "Y", round: true, text: "Close all" },
            { key: "B", round: true, text: "Back" }
        ]
    }
}
