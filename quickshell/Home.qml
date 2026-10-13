import QtQuick
import Quickshell

// Home page. Two built-in layouts, chosen by the theme ("style.home"):
//   classic  from Main.dc.html on the canvas (Dusk Tide)
//   panels   from Retro-Home.dc.html (Stylus): clock card with a week
//            strip, media and toggles stacked right, a wide dock with a
//            name banner
// Positions are the mockups' px values; the RP5 screen is 960x540 logical.
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
    readonly property bool panels: Theme.homeLayout === "panels"

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
        visible: !home.panels
        x: 48
        y: 70
    }

    ClockPanel {
        visible: home.panels
        x: 32
        y: 60
        width: 420
        height: 272
    }

    Loader {
        id: media
        x: home.panels ? 476 : home.width - 40 - width
        y: home.panels ? 60 : 74
        width: home.panels ? home.width - 476 - 32 : 400
        height: home.panels ? 124 : 156
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
        x: home.panels ? 476 : home.width - 40 - width
        y: home.panels ? 200 : 246
        width: home.panels ? home.width - 476 - 32 : 400
        height: home.panels ? 132 : implicitHeight
        toggleSize: home.panels ? 64 : 52
        focusedIndex: Controller.active && home.zone === "toggles" ? home.toggleIndex : -1
    }

    Dock {
        id: dock
        x: home.panels ? 32 : (home.width - width) / 2
        y: home.panels ? 352 : home.height - 48 - height
        width: home.panels ? home.width - 64 : implicitWidth
        height: home.panels ? 138 : implicitHeight
        tileSize: home.panels ? 72 : 56
        banner: home.panels
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
            { key: "SELECT", round: false, text: "Quick" },
            { key: "START", round: false, text: "Menu" },
            { key: "HOLD HOME", round: false, text: "Recents" }
        ]
    }
}
