pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Small saved state: dock pins, recently played games and theme choice.
// Stored as JSON in Quickshell's per-shell state directory.
Singleton {
    id: store

    // Desktop entry ids pinned to the Home dock, in order.
    property var pinned: []
    // Recently played games, newest first:
    // { kind, system, path, title, art, entryId }
    property var recentGames: []
    // Selected theme (folder name), the favourite colour picked per theme
    // (and per mode), and the mode picked per theme ("dark", "paper"...).
    property string theme: "dusk-tide"
    property var accents: ({})
    property var modes: ({})
    // Animated tiles switched off to save power: { pipes: true, cava: true }
    property var paused: ({})
    // Fetch card picture: "" (the theme's), "handheld" or "dancer"
    property string fetchLogo: ""
    property bool sounds: true
    // Not saved: whether Quick settings is open (the volume pop-up hides then).
    property bool quickPanelOpen: false
    property bool loaded: false

    readonly property int maxPins: 5
    readonly property int maxRecent: 20

    // Used when nothing has been pinned yet: the first match of each group.
    readonly property var defaultPinGroups: [
        ["org.kde.angelfish", "firefox", "org.mozilla.firefox", "chromium", "org.kde.falkon"],
        ["org.kde.index", "org.kde.dolphin", "org.gnome.Nautilus", "thunar"],
        ["org.kde.elisa", "org.gnome.Music"],
        ["org.kde.koko", "org.kde.gwenview"]
    ]

    function isPinned(id) {
        return pinned.indexOf(id) >= 0;
    }

    // Returns false if the dock is already full.
    function togglePin(id) {
        const list = pinned.slice();
        const i = list.indexOf(id);
        if (i >= 0) {
            list.splice(i, 1);
        } else {
            if (list.length >= maxPins)
                return false;
            list.push(id);
        }
        pinned = list;
        save();
        return true;
    }

    function addRecent(game) {
        const list = recentGames.filter(g => !(g.kind === game.kind && g.path === game.path && g.entryId === game.entryId));
        list.unshift(game);
        recentGames = list.slice(0, maxRecent);
        save();
    }

    function setTheme(id) {
        theme = id;
        save();
    }

    function setAccent(themeId, color) {
        const map = Object.assign({}, accents);
        if (color)
            map[themeId] = color;
        else
            delete map[themeId];
        accents = map;
        save();
    }

    function setMode(themeId, mode) {
        const map = Object.assign({}, modes);
        if (mode)
            map[themeId] = mode;
        else
            delete map[themeId];
        modes = map;
        save();
    }

    function setPaused(name, on) {
        const map = Object.assign({}, paused);
        if (on)
            map[name] = true;
        else
            delete map[name];
        paused = map;
        save();
    }

    function setFetchLogo(kind) {
        fetchLogo = kind;
        save();
    }

    function setSounds(on) {
        sounds = on;
        save();
    }

    function save() {
        file.setText(JSON.stringify({
            pinned: pinned,
            recentGames: recentGames,
            theme: theme,
            accents: accents,
            modes: modes,
            paused: paused,
            fetchLogo: fetchLogo,
            sounds: sounds
        }, null, 2));
    }

    function defaultPins() {
        const out = [];
        for (let g = 0; g < defaultPinGroups.length; g++) {
            const group = defaultPinGroups[g];
            for (let i = 0; i < group.length; i++) {
                if (DesktopEntries.byId(group[i])) {
                    out.push(group[i]);
                    break;
                }
            }
        }
        return out;
    }

    FileView {
        id: file
        path: Quickshell.statePath("state.json")
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", Quickshell.stateDir]);
        let data = null;
        try {
            const text = file.text();
            if (text)
                data = JSON.parse(text);
        } catch (e) {
            data = null;
        }
        pinned = data && Array.isArray(data.pinned) ? data.pinned : defaultPins();
        recentGames = data && Array.isArray(data.recentGames) ? data.recentGames : [];
        theme = data && typeof data.theme === "string" ? data.theme : "dusk-tide";
        accents = data && data.accents && typeof data.accents === "object" ? data.accents : {};
        modes = data && data.modes && typeof data.modes === "object" ? data.modes : {};
        paused = data && data.paused && typeof data.paused === "object" ? data.paused : {};
        fetchLogo = data && typeof data.fetchLogo === "string" ? data.fetchLogo : "";
        sounds = data && typeof data.sounds === "boolean" ? data.sounds : true;
        loaded = true;
    }
}
