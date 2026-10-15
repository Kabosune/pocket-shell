import QtQuick
import Quickshell

// Home page. Three built-in layouts, chosen by the theme ("style.home"):
//   classic  from Main.dc.html on the canvas (Dusk Tide)
//   panels   from Retro-Home.dc.html (Stylus): clock card with a week
//            strip, media and toggles stacked right, a wide dock with a
//            name banner
//   fetch    Dotfiles: a terminal "fetch" card with system info on the
//            left, media and toggles on the right, a centred dock
//   tiles    Static: everything in tiled terminal windows, like a tiling
//            WM desktop: fetch and dock on the left; media, toggles,
//            pipes and an audio visualizer on the right
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
    property int tileIndex: 0

    // Tiles layout: the pipes and cava pause buttons are a row too
    readonly property var zones: home.tiles ? ["media", "toggles", "tiles", "dock"] : ["media", "toggles", "dock"]
    readonly property var animTiles: ["pipes", "cava"]
    readonly property bool panels: Theme.homeLayout === "panels"
    readonly property bool fetch: Theme.homeLayout === "fetch"
    readonly property bool tiles: Theme.homeLayout === "tiles"
    // Animated tiles only run while Home is on screen
    readonly property bool live: home.current && Wm.inShell

    // Value for the current layout
    function pick(classic, panels, fetch, tiles) {
        return home.tiles ? tiles : home.fetch ? fetch : home.panels ? panels : classic;
    }

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
            return media.item ? media.item.count : 3;
        if (z === "toggles")
            return toggles.count;
        if (z === "tiles")
            return animTiles.length;
        return dockItems.length;
    }

    function zoneIndex(z) {
        return z === "media" ? mediaIndex : z === "toggles" ? toggleIndex : z === "tiles" ? tileIndex : dockIndex;
    }

    function setZoneIndex(z, i) {
        const clamped = Math.max(0, Math.min(zoneCount(z) - 1, i));
        if (z === "media")
            mediaIndex = clamped;
        else if (z === "toggles")
            toggleIndex = clamped;
        else if (z === "tiles")
            tileIndex = clamped;
        else
            dockIndex = clamped;
    }

    function moveZone(step) {
        const i = zones.indexOf(zone) + step;
        if (i >= 0 && i < zones.length)
            zone = zones[i];
    }

    // Pause or resume an animated tile (saved, so it stays that way)
    function toggleTile(name) {
        const off = !Store.paused[name];
        Store.setPaused(name, off);
        Sfx.play(off ? "toggle-off" : "toggle-on", 2);
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
        } else if (zone === "tiles") {
            toggleTile(animTiles[tileIndex]);
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
    onTilesChanged: {
        if (!tiles && zone === "tiles")
            zone = "dock";
    }

    // --- Tile windows (tiles layout)

    TileWindow {
        id: fetchWin
        visible: home.tiles
        x: 16
        y: 52
        width: 480
        height: 308
        title: "pocketfetch"
    }

    TileWindow {
        id: dockWin
        visible: home.tiles
        x: 16
        y: 370
        width: 480
        height: 124
        title: "dock"
        status: `${home.dockItems.length} items`
        active: Controller.active && home.zone === "dock"
    }

    TileWindow {
        id: mediaWin
        visible: home.tiles
        x: 506
        y: 52
        width: home.width - 506 - 16
        height: 140
        title: "now playing"
        status: "mpris"
        active: Controller.active && home.zone === "media"
    }

    TileWindow {
        id: togglesWin
        visible: home.tiles
        x: 506
        y: 202
        width: mediaWin.width
        height: 112
        title: "toggles"
        active: Controller.active && home.zone === "toggles"
    }

    TileWindow {
        id: pipesWin
        visible: home.tiles
        x: 506
        y: 324
        width: (mediaWin.width - 10) / 2
        height: 170
        title: "pipes"
        status: Store.paused.pipes ? "paused" : ""
        hasAction: true
        running: !Store.paused.pipes
        actionFocused: Controller.active && home.zone === "tiles" && home.tileIndex === 0
        onActionTapped: home.toggleTile("pipes")

        Loader {
            active: home.tiles
            x: 8
            y: pipesWin.barHeight + 6
            width: pipesWin.width - 16
            height: pipesWin.height - pipesWin.barHeight - 12
            sourceComponent: PipesView {
                running: home.live && !Store.paused.pipes
                colors: Theme.accentChoices && Theme.accentChoices.length > 0
                    ? Theme.accentChoices.slice(0, 6).map(c => String(Theme.toColor(c)))
                    : [String(Theme.accent)]
            }
        }
    }

    TileWindow {
        id: cavaWin
        visible: home.tiles
        x: pipesWin.x + pipesWin.width + 10
        y: 324
        width: pipesWin.width
        height: 170
        title: "cava"
        status: Store.paused.cava ? "paused" : viz.status === Loader.Ready ? viz.item.mode : ""
        hasAction: true
        running: !Store.paused.cava
        actionFocused: Controller.active && home.zone === "tiles" && home.tileIndex === 1
        onActionTapped: home.toggleTile("cava")

        Loader {
            id: viz
            active: home.tiles
            x: 12
            y: cavaWin.barHeight + 12
            width: cavaWin.width - 24
            height: cavaWin.height - cavaWin.barHeight - 24
            sourceComponent: Visualizer {
                running: home.live && !Store.paused.cava
            }
        }
    }

    Loader {
        active: home.tiles
        x: fetchWin.x
        y: fetchWin.y + fetchWin.barHeight
        width: fetchWin.width
        height: fetchWin.height - fetchWin.barHeight
        sourceComponent: FetchCard {
            framed: true
            showPrompt: false
            margin: 14
            animate: home.live
        }
    }

    ClockBlock {
        visible: !home.panels && !home.fetch && !home.tiles
        x: 48
        y: 70
    }

    Loader {
        active: home.fetch
        x: 32
        y: 60
        width: 548
        height: 330
        sourceComponent: FetchCard {
            animate: home.live
        }
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
        x: home.pick(home.width - 40 - width, 476, 600, mediaWin.x)
        y: home.pick(74, 60, 60, mediaWin.y + mediaWin.barHeight)
        width: home.pick(400, home.width - 476 - 32, home.width - 600 - 32, mediaWin.width)
        height: home.pick(156, 124, 140, mediaWin.height - mediaWin.barHeight)
        source: "NowPlaying.qml"
    }

    // Inside a tile window the media card drops its own frame
    Binding {
        when: media.status === Loader.Ready && home.tiles
        target: media.item
        property: "color"
        value: "transparent"
    }
    Binding {
        when: media.status === Loader.Ready && home.tiles
        target: media.item
        property: "border.width"
        value: 0
    }

    Binding {
        when: media.status === Loader.Ready
        target: media.item
        property: "focusedIndex"
        value: Controller.active && home.zone === "media" ? home.mediaIndex : -1
    }

    QuickToggles {
        id: toggles
        x: home.pick(home.width - 40 - width, 476, 600, togglesWin.x)
        y: home.pick(246, 200, 216, togglesWin.y + togglesWin.barHeight)
        width: home.pick(400, home.width - 476 - 32, home.width - 600 - 32, togglesWin.width)
        height: home.pick(implicitHeight, 132, 174, togglesWin.height - togglesWin.barHeight)
        toggleSize: home.pick(52, 64, 52, 44)
        color: home.tiles ? "transparent" : Theme.surface
        border.width: home.tiles ? 0 : Theme.borderWidth
        focusedIndex: Controller.active && home.zone === "toggles" ? home.toggleIndex : -1
    }

    Dock {
        id: dock
        x: home.tiles ? dockWin.x + (dockWin.width - width) / 2 : home.panels ? 32 : (home.width - width) / 2
        y: home.tiles ? dockWin.y + dockWin.barHeight + (dockWin.height - dockWin.barHeight - height) / 2
            : home.panels ? 352 : home.height - 48 - height
        width: home.panels ? home.width - 64 : implicitWidth
        height: home.panels ? 138 : implicitHeight
        tileSize: home.panels ? 72 : 56
        color: home.tiles ? "transparent" : Theme.surface
        border.width: home.tiles ? 0 : Theme.borderWidth
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
