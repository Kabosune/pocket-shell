import QtQuick

// Home page, landscape layout from the concept canvas (Main.dc.html).
// Positions are the mockup's px values; the RP5 screen is 960x540 logical.
//
// Controller focus moves between three rows:
//   media controls  (top right)
//   quick toggles   (middle right)
//   dock            (bottom)
// Left/right moves within a row, up/down between rows, A activates.
Item {
    id: home

    property string zone: "dock"
    property int mediaIndex: 1
    property int toggleIndex: 0
    property int dockIndex: 0

    readonly property var zones: ["media", "toggles", "dock"]

    function zoneCount(z) {
        if (z === "media")
            return 3;
        if (z === "toggles")
            return toggles.count;
        return dock.apps.length;
    }

    function zoneIndex(z) {
        return z === "media" ? mediaIndex : z === "toggles" ? toggleIndex : dockIndex;
    }

    function setZoneIndex(z, i) {
        const clamped = Math.max(0, Math.min(zoneCount(z) - 1, i));
        if (z === "media")
            mediaIndex = clamped;
        else if (z === "toggles")
            toggleIndex = clamped;
        else
            dockIndex = clamped;
    }

    function moveZone(step) {
        const i = zones.indexOf(zone) + step;
        if (i >= 0 && i < zones.length)
            zone = zones[i];
    }

    function activateFocused() {
        if (zone === "media") {
            if (media.item)
                media.item.activate(mediaIndex);
        } else if (zone === "toggles") {
            toggles.activate(toggleIndex);
        } else {
            dock.activate(dockIndex);
        }
    }

    function handle(button) {
        if (sheet.open) {
            sheet.handle(button);
            return;
        }
        switch (button) {
        case "left":  setZoneIndex(zone, zoneIndex(zone) - 1); break;
        case "right": setZoneIndex(zone, zoneIndex(zone) + 1); break;
        case "up":    moveZone(-1); break;
        case "down":  moveZone(1); break;
        case "a":     activateFocused(); break;
        case "home":  zone = "dock"; break;
        case "start": sheet.show(); break;
        }
    }

    Connections {
        target: Controller
        function onPressed(button, repeat) {
            home.handle(button);
        }
    }

    Wallpaper {
        anchors.fill: parent
    }

    TopBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        page: 0
    }

    ClockBlock {
        x: 48
        y: 70
    }

    Loader {
        id: media
        x: home.width - 40 - width
        y: 74
        width: 400
        height: 156
        source: "NowPlaying.qml"
    }

    Binding {
        when: media.status === Loader.Ready
        target: media.item
        property: "focusedIndex"
        value: Controller.active && home.zone === "media" ? home.mediaIndex : -1
    }

    QuickToggles {
        id: toggles
        x: home.width - 40 - width
        y: 246
        width: 400
        focusedIndex: Controller.active && home.zone === "toggles" ? home.toggleIndex : -1
    }

    Dock {
        id: dock
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        focusedIndex: Controller.active && home.zone === "dock" ? home.dockIndex : -1
        onTapped: index => {
            home.zone = "dock";
            home.dockIndex = index;
        }
        onActivated: appId => {
            if (appId === "settings")
                sheet.show();
        }
    }

    HintBar {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
    }

    SessionSheet {
        id: sheet
        anchors.fill: parent
    }

    // Any touch switches back to touch mode, which hides the focus rings.
    // A PointHandler only watches, so taps still reach the controls below.
    Item {
        anchors.fill: parent
        z: 1000

        PointHandler {
            onActiveChanged: {
                if (active)
                    Controller.active = false;
            }
        }
    }
}
