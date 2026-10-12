import QtQuick
import Quickshell

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

    property var shell: null
    property bool current: false

    property string zone: "dock"
    property int mediaIndex: 1
    property int toggleIndex: 0
    property int dockIndex: 0

    readonly property var zones: ["media", "toggles", "dock"]

    // Pinned apps, then Settings (which opens the session sheet for now).
    readonly property var dockItems: {
        // Re-evaluate when the app list finishes loading or changes
        const apps = DesktopEntries.applications.values;
        const out = [];
        const ids = Store.pinned;
        for (let i = 0; i < ids.length; i++) {
            const entry = DesktopEntries.byId(ids[i]);
            if (entry)
                out.push({ id: ids[i], name: entry.name, entry: entry });
        }
        out.push({ id: "settings", name: "Settings", glyph: Icons.settings });
        return out;
    }

    function zoneCount(z) {
        if (z === "media")
            return 3;
        if (z === "toggles")
            return toggles.count;
        return dockItems.length;
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

    function activateDock(index) {
        const item = dockItems[index];
        if (!item)
            return;
        if (item.entry)
            Wm.launchEntry(item.entry);
        else if (item.id === "settings" && shell)
            shell.showSession();
    }

    function activateFocused() {
        if (zone === "media") {
            if (media.item)
                media.item.activate(mediaIndex);
        } else if (zone === "toggles") {
            toggles.activate(toggleIndex);
        } else {
            activateDock(dockIndex);
        }
    }

    // Returns true if the button was used here.
    function handle(button) {
        switch (button) {
        case "left":
            setZoneIndex(zone, zoneIndex(zone) - 1);
            return true;
        case "right":
            setZoneIndex(zone, zoneIndex(zone) + 1);
            return true;
        case "up":
            moveZone(-1);
            return true;
        case "down":
            moveZone(1);
            return true;
        case "a":
            activateFocused();
            return true;
        case "home":
            zone = "dock";
            return true;
        }
        return false;
    }

    onDockItemsChanged: setZoneIndex("dock", dockIndex)

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
        items: home.dockItems
        focusedIndex: Controller.active && home.zone === "dock" ? home.dockIndex : -1
        onTapped: index => {
            home.zone = "dock";
            home.dockIndex = index;
        }
        onActivated: index => home.activateDock(index)
    }

    HintBar {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        items: [
            { key: "A", round: true, text: "Open" },
            { key: "START", round: false, text: "Menu" },
            { key: "HOLD HOME", round: false, text: "Recents" }
        ]
    }
}
