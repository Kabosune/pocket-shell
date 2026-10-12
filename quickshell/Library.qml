import QtQuick
import Quickshell
import Quickshell.Io

// Library page: an ES-DE-style launcher (layout from Library-Landscape on the canvas).
//
// Collections row: Recent, Ports, Steam, Android, then one card per system
// that has games. LT/RT filter the row. A on a collection opens its games;
// in the game grid A plays and B goes back.
//
// Games come from pocknix's ROM folders via the pocket-games helper
// (bin/pocket-games), which also finds ES-DE box art and works out the
// emulator command for each game.
Item {
    id: page

    property var shell: null
    property bool current: false

    // "collections" or "games"
    property string view: "collections"
    property int filter: 0
    property int collectionIndex: 0
    property int gameIndex: 0

    readonly property var filters: ["All", "Steam", "Emulation", "Ports", "Android"]
    readonly property int columns: 6
    readonly property string helper: "/usr/local/bin/pocket-games"

    // Scan results
    property var systems: []
    property var systemGames: ({})
    property var ports: []
    property bool steamAvailable: false
    property bool scanned: false
    property bool scanFailed: false
    property double lastScan: 0

    readonly property var tints: ["#2F5A45", "#463A66", "#3E4650", "#5A4A2E", "#2E4A5A", "#5A2E46", "#3A5A2E", "#4A3A2E"]

    function tintFor(key) {
        let h = 0;
        for (let i = 0; i < key.length; i++)
            h = (h * 31 + key.charCodeAt(i)) % 9973;
        return tints[h % tints.length];
    }

    readonly property var androidApps: {
        const list = DesktopEntries.applications.values.filter(e => e.id.indexOf("waydroid.") === 0);
        list.sort((a, b) => a.name.localeCompare(b.name));
        return list.map(e => ({
            kind: "app",
            entryId: e.id,
            title: e.name,
            art: "",
            icon: e.icon ? Quickshell.iconPath(e.icon, true) : "",
            system: "android"
        }));
    }

    readonly property var allCollections: {
        const out = [];
        if (Store.recentGames.length > 0) {
            out.push({
                key: "recent", kind: "recent", name: "Recent", short: "RCT",
                subtitle: "Last played", color: "#3A4A5A",
                description: "The games you played last, newest first.",
                games: Store.recentGames
            });
        }
        if (ports.length > 0) {
            out.push({
                key: "ports", kind: "ports", name: "Ports", short: "PRT",
                subtitle: "Native builds", color: "#5A3E36",
                description: "Native ports built from decompilation projects. They run directly, with no emulator in between.",
                games: ports
            });
        }
        if (steamAvailable) {
            out.push({
                key: "steam", kind: "steam", name: "Steam", short: "STM",
                subtitle: "Opens Steam mode", color: "#2D4A66",
                description: "Your Steam library lives in Steam mode. Opening it switches the whole device over.",
                games: []
            });
        }
        if (androidApps.length > 0) {
            out.push({
                key: "android", kind: "android", name: "Android", short: "AND",
                subtitle: "Waydroid", color: "#3A5A3E",
                description: "Android apps and games running through Waydroid.",
                games: androidApps
            });
        }
        for (let i = 0; i < systems.length; i++) {
            const s = systems[i];
            const games = systemGames[s.key] || [];
            out.push({
                key: s.key, kind: "system", name: s.name, short: s.short,
                subtitle: s.emulator, color: tintFor(s.key),
                description: `${games.length} ${games.length === 1 ? "game" : "games"} · plays with ${s.emulator}`,
                games: games
            });
        }
        return out;
    }

    readonly property var collections: {
        const f = filters[filter];
        if (f === "All")
            return allCollections;
        const kinds = f === "Steam" ? ["steam"] : f === "Emulation" ? ["system"] : f === "Ports" ? ["ports"] : ["android"];
        return allCollections.filter(c => kinds.indexOf(c.kind) >= 0);
    }

    readonly property var currentCollection: collections.length > 0
        ? collections[Math.max(0, Math.min(collectionIndex, collections.length - 1))] : null
    readonly property var games: currentCollection ? currentCollection.games : []
    readonly property var currentGame: games.length > 0
        ? games[Math.max(0, Math.min(gameIndex, games.length - 1))] : null

    function systemName(key) {
        for (let i = 0; i < systems.length; i++) {
            if (systems[i].key === key)
                return systems[i].name;
        }
        return key === "ports" ? "Port" : key === "android" ? "Android" : key;
    }

    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function artUrl(game) {
        if (!game)
            return "";
        if (game.art)
            return fileUrl(game.art);
        return game.icon || "";
    }

    // --- Scanning

    function rescan() {
        if (scanner.running)
            return;
        scanner.running = true;
    }

    function parseScan(text) {
        const newSystems = [];
        const newGames = {};
        const newPorts = [];
        let steam = false;
        const lines = text.split("\n");
        for (let i = 0; i < lines.length; i++) {
            const f = lines[i].split("\t");
            if (f[0] === "Y" && f.length >= 6) {
                newSystems.push({ key: f[1], name: f[2], short: f[3], emulator: f[4] });
                newGames[f[1]] = [];
            } else if (f[0] === "G" && f.length >= 4) {
                if (!newGames[f[1]])
                    newGames[f[1]] = [];
                newGames[f[1]].push({ kind: "rom", system: f[1], path: f[2], title: f[3], art: f[4] || "" });
            } else if (f[0] === "P" && f.length >= 3) {
                newPorts.push({ kind: "port", system: "ports", path: f[1], title: f[2], art: f[3] || "" });
            } else if (f[0] === "S") {
                steam = true;
            }
        }
        systems = newSystems;
        systemGames = newGames;
        ports = newPorts;
        steamAvailable = steam;
        scanned = true;
        lastScan = Date.now();
        clampIndexes();
    }

    function clampIndexes() {
        collectionIndex = Math.max(0, Math.min(collectionIndex, collections.length - 1));
        gameIndex = Math.max(0, Math.min(gameIndex, games.length - 1));
    }

    Process {
        id: scanner
        command: [page.helper, "scan"]
        stdout: StdioCollector {
            id: scanOut
            onStreamFinished: page.parseScan(text)
        }
        onExited: (exitCode, exitStatus) => page.scanFailed = exitCode !== 0 && !page.scanned
    }

    onCurrentChanged: {
        if (current && Date.now() - lastScan > 30000)
            rescan();
    }

    Component.onCompleted: rescan()

    // --- Launching

    property var pendingGame: null
    property double pendingSince: 0
    property int resolveExit: -1
    property bool resolveDone: false

    function finishResolve() {
        if (resolveExit < 0 || !resolveDone || !pendingGame)
            return;
        const game = pendingGame;
        pendingGame = null;
        if (resolveExit === 0) {
            const args = resolveOut.text.split("\n").filter(a => a.length > 0);
            Wm.launchCommand(args);
            Store.addRecent(game);
        } else {
            const why = resolveErr.text.trim();
            if (shell)
                shell.toast(why ? `Can't start ${game.title}: ${why}` : `Can't start ${game.title}`);
        }
    }

    Process {
        id: resolver
        stdout: StdioCollector {
            id: resolveOut
            onStreamFinished: {
                page.resolveDone = true;
                page.finishResolve();
            }
        }
        stderr: StdioCollector {
            id: resolveErr
        }
        onExited: (exitCode, exitStatus) => {
            page.resolveExit = exitCode;
            page.finishResolve();
        }
    }

    Process {
        id: toSteam
        command: ["steamos-session-select", "gamescope"]
    }

    function play(game) {
        if (!game)
            return;
        if (game.kind === "app") {
            const entry = DesktopEntries.byId(game.entryId);
            if (entry) {
                Wm.launchEntry(entry);
                Store.addRecent(game);
            } else if (shell) {
                shell.toast(`${game.title} isn't installed anymore`);
            }
        } else if (game.kind === "port") {
            Wm.launchCommand(["bash", game.path]);
            Store.addRecent(game);
        } else if (game.kind === "rom") {
            // A stuck lookup (helper missing) shouldn't block launching forever
            if ((resolver.running || pendingGame) && Date.now() - pendingSince < 5000)
                return;
            pendingGame = game;
            pendingSince = Date.now();
            resolveExit = -1;
            resolveDone = false;
            resolver.command = [helper, "command", game.system, game.path];
            resolver.running = true;
        }
    }

    function openCollection(index) {
        const c = collections[index];
        if (!c)
            return;
        collectionIndex = index;
        if (c.kind === "steam") {
            toSteam.running = true;
            return;
        }
        if (c.games.length === 0)
            return;
        gameIndex = 0;
        view = "games";
    }

    function setFilter(i) {
        filter = (i + filters.length) % filters.length;
        collectionIndex = 0;
    }

    // --- Controller

    function handle(button) {
        if (view === "collections") {
            switch (button) {
            case "left":
                collectionIndex = Math.max(0, collectionIndex - 1);
                return true;
            case "right":
                collectionIndex = Math.min(collections.length - 1, collectionIndex + 1);
                return true;
            case "lt":
                setFilter(filter - 1);
                return true;
            case "rt":
                setFilter(filter + 1);
                return true;
            case "a":
                openCollection(collectionIndex);
                return true;
            case "x":
                rescan();
                if (shell)
                    shell.toast("Refreshing the library");
                return true;
            }
            return false;
        }

        switch (button) {
        case "left":
            gameIndex = Math.max(0, gameIndex - 1);
            return true;
        case "right":
            gameIndex = Math.min(games.length - 1, gameIndex + 1);
            return true;
        case "up":
            gameIndex = Math.max(0, gameIndex - columns);
            return true;
        case "down":
            gameIndex = Math.min(games.length - 1, gameIndex + columns);
            return true;
        case "a":
            play(currentGame);
            return true;
        case "b":
            view = "collections";
            return true;
        }
        return false;
    }

    // --- Layout

    PageBackdrop {}

    Loader {
        anchors.fill: parent
        active: page.view === "games"
        source: "ArtBackdrop.qml"
        onLoaded: item.source = Qt.binding(() => page.artUrl(page.currentGame))
    }

    // Collections view

    Item {
        anchors.fill: parent
        visible: page.view === "collections"

        PageTitle {
            text: "Library"
        }

        Row {
            anchors.right: parent.right
            anchors.rightMargin: 48
            y: 64
            spacing: 8

            KeyCap {
                anchors.verticalCenter: parent.verticalCenter
                label: "LT"
                borderAlpha: 0.45
            }

            Repeater {
                model: page.filters

                Rectangle {
                    id: chip
                    required property string modelData
                    required property int index
                    readonly property bool selected: index === page.filter

                    width: chipLabel.implicitWidth + 28
                    height: 32
                    radius: Theme.rPill
                    color: selected ? Theme.accent : "transparent"
                    border.width: selected ? 0 : 1
                    border.color: Qt.rgba(207 / 255, 230 / 255, 225 / 255, 0.22)

                    Text {
                        id: chipLabel
                        anchors.centerIn: parent
                        text: chip.modelData
                        color: chip.selected ? Theme.accentInk : Theme.text
                        font.family: Theme.bodyFont
                        font.weight: chip.selected ? Font.ExtraBold : Font.Bold
                        font.pixelSize: 13
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: page.setFilter(chip.index)
                    }
                }
            }

            KeyCap {
                anchors.verticalCenter: parent.verticalCenter
                label: "RT"
                borderAlpha: 0.45
            }
        }

        ListView {
            id: row
            x: 0
            y: 116
            width: parent.width
            height: 220
            leftMargin: 48
            rightMargin: 48
            orientation: ListView.Horizontal
            spacing: 16
            model: page.collections
            currentIndex: page.collectionIndex
            highlightFollowsCurrentItem: false
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

            delegate: Item {
                id: card
                required property var modelData
                required property int index
                readonly property bool selected: index === page.collectionIndex
                readonly property bool focused: Controller.active && selected

                width: 150
                height: 200
                y: 10
                z: focused ? 1 : 0
                scale: focused ? 1.07 : 1
                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                FocusRing {
                    visible: card.focused
                    radius: Theme.rCard
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.rCard
                    color: card.modelData.color
                    clip: true
                    opacity: tap.pressed ? 0.8 : 1

                    Text {
                        x: 12
                        y: 10
                        text: card.modelData.short
                        color: card.focused ? Theme.accent : Theme.textStrong
                        opacity: card.focused ? 0.55 : 0.22
                        font.family: Theme.displayFont
                        font.weight: Font.Black
                        font.pixelSize: 52
                    }

                    Column {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 14
                        spacing: 2

                        Text {
                            width: parent.width
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                            text: card.modelData.name
                            color: Theme.textStrong
                            font.family: Theme.bodyFont
                            font.weight: Font.ExtraBold
                            font.pixelSize: 15
                        }

                        Text {
                            width: parent.width
                            elide: Text.ElideRight
                            text: card.modelData.subtitle
                            color: Theme.textHint
                            font.family: Theme.bodyFont
                            font.weight: Font.DemiBold
                            font.pixelSize: 12
                        }
                    }
                }

                MouseArea {
                    id: tap
                    anchors.fill: parent
                    onClicked: {
                        if (page.collectionIndex === card.index)
                            page.openCollection(card.index);
                        else
                            page.collectionIndex = card.index;
                    }
                }
            }
        }

        // Selected collection
        Surface {
            visible: page.currentCollection !== null
            x: 48
            y: 350
            width: parent.width - 96
            height: 118
            color: Qt.rgba(14 / 255, 36 / 255, 40 / 255, 0.82)

            Column {
                anchors.left: parent.left
                anchors.leftMargin: 24
                anchors.right: openButton.left
                anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Text {
                    text: "COLLECTION"
                    color: Theme.textMuted
                    font.family: Theme.bodyFont
                    font.weight: Font.ExtraBold
                    font.pixelSize: 11
                    font.letterSpacing: 1.5
                }

                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: page.currentCollection ? page.currentCollection.name : ""
                    color: Theme.textStrong
                    font.family: Theme.displayFont
                    font.weight: Font.Black
                    font.pixelSize: 30
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    text: page.currentCollection ? page.currentCollection.description : ""
                    color: Theme.textMuted
                    font.family: Theme.bodyFont
                    font.weight: Font.DemiBold
                    font.pixelSize: 14
                    lineHeight: 1.2
                }
            }

            Rectangle {
                id: openButton
                anchors.right: parent.right
                anchors.rightMargin: 24
                anchors.verticalCenter: parent.verticalCenter
                width: openRow.implicitWidth + 32
                height: 44
                radius: Theme.rBtn
                color: Theme.accent
                opacity: openTap.pressed ? 0.8 : 1

                Row {
                    id: openRow
                    anchors.centerIn: parent
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 20
                        height: 20
                        radius: Theme.rPill
                        color: "transparent"
                        border.width: 1.5
                        border.color: Qt.rgba(43 / 255, 26 / 255, 16 / 255, 0.6)

                        Text {
                            anchors.centerIn: parent
                            text: "A"
                            color: Theme.accentInk
                            font.family: Theme.bodyFont
                            font.weight: Font.ExtraBold
                            font.pixelSize: 11
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: page.currentCollection && page.currentCollection.kind === "steam" ? "Switch to Steam" : "Open"
                        color: Theme.accentInk
                        font.family: Theme.bodyFont
                        font.weight: Font.ExtraBold
                        font.pixelSize: 14
                    }
                }

                MouseArea {
                    id: openTap
                    anchors.fill: parent
                    onClicked: page.openCollection(page.collectionIndex)
                }
            }
        }

        Column {
            anchors.centerIn: parent
            visible: page.collections.length === 0
            spacing: 8

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: !page.scanned ? (page.scanFailed ? "The library helper isn't installed" : "Looking for games…")
                    : page.filter === 0 ? "No games found" : `Nothing in ${page.filters[page.filter]}`
                color: Theme.textStrong
                font.family: Theme.bodyFont
                font.weight: Font.ExtraBold
                font.pixelSize: 18
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: page.scanned || page.scanFailed
                text: page.scanFailed ? "Run install.sh on the device, then come back."
                    : "Put ROMs in ~/Emulation, one folder per system (n64, gba, psx…)."
                color: Theme.textMuted
                font.family: Theme.bodyFont
                font.weight: Font.DemiBold
                font.pixelSize: 14
            }
        }

        HintBar {
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            items: [
                { key: "A", round: true, text: "Open" },
                { key: "B", round: true, text: "Home" },
                { key: "X", round: true, text: "Refresh" },
                { key: "LT RT", round: false, text: "Filter" }
            ]
        }
    }

    // Games view

    Item {
        anchors.fill: parent
        visible: page.view === "games"

        // Touch: back to the collections
        Rectangle {
            x: 48
            y: 62
            width: 40
            height: 40
            radius: Theme.rPill
            color: Theme.surface
            border.width: 1
            border.color: Theme.surfaceBorder
            opacity: backTap.pressed ? 0.7 : 1

            Icon {
                anchors.centerIn: parent
                glyph: Icons.back
                size: 20
                weight: 2
                color: Theme.text
            }

            MouseArea {
                id: backTap
                anchors.fill: parent
                anchors.margins: -6
                onClicked: page.view = "collections"
            }
        }

        PageTitle {
            x: 102
            text: page.currentCollection ? page.currentCollection.name : ""
        }

        Text {
            anchors.right: parent.right
            anchors.rightMargin: 48
            y: 72
            text: page.games.length === 1 ? "1 game" : `${page.games.length} games`
            color: Theme.textMuted
            font.family: Theme.bodyFont
            font.weight: Font.Bold
            font.pixelSize: 14
        }

        GridView {
            id: gameGrid
            x: 48
            y: 112
            width: parent.width - 96
            height: parent.height - y - 92
            cellWidth: width / page.columns
            cellHeight: 196
            clip: true
            model: page.games
            currentIndex: page.gameIndex
            highlightFollowsCurrentItem: false
            boundsBehavior: Flickable.StopAtBounds
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, GridView.Contain)

            delegate: Item {
                id: tile
                required property var modelData
                required property int index
                readonly property bool focused: Controller.active && index === page.gameIndex

                width: gameGrid.cellWidth
                height: gameGrid.cellHeight
                z: focused ? 1 : 0

                Item {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 10
                    width: 120
                    height: 160
                    scale: tile.focused ? 1.06 : 1
                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                    FocusRing {
                        visible: tile.focused
                        radius: Theme.rArt
                    }

                    GameCover {
                        anchors.fill: parent
                        art: tile.modelData.art || ""
                        title: tile.modelData.title
                        caption: page.currentCollection && page.currentCollection.kind === "recent"
                            ? page.systemName(tile.modelData.system) : ""
                        tint: page.tintFor(tile.modelData.system || "x")
                        opacity: gameTap.pressed ? 0.8 : 1
                    }

                    // Android apps: show their icon on the card
                    AppIcon {
                        visible: tile.modelData.kind === "app"
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.margins: 12
                        entry: tile.modelData.kind === "app" ? DesktopEntries.byId(tile.modelData.entryId) : null
                        size: 40
                    }
                }

                MouseArea {
                    id: gameTap
                    anchors.fill: parent
                    onClicked: {
                        page.gameIndex = tile.index;
                        page.play(tile.modelData);
                    }
                }
            }
        }

        // Focused game
        Column {
            x: 48
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 18
            width: parent.width - 420
            spacing: 2

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: page.currentGame ? page.currentGame.title : ""
                color: Theme.textStrong
                font.family: Theme.displayFont
                font.weight: Font.Black
                font.pixelSize: 22
            }

            Text {
                text: page.currentGame ? page.systemName(page.currentGame.system) : ""
                color: Theme.textMuted
                font.family: Theme.bodyFont
                font.weight: Font.Bold
                font.pixelSize: 13
            }
        }

        HintBar {
            anchors.right: parent.right
            anchors.rightMargin: 22
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 14
            items: [
                { key: "A", round: true, text: "Play" },
                { key: "B", round: true, text: "Back" }
            ]
        }

    }
}
