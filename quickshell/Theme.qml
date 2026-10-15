pragma Singleton
import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Io

// The current theme's design tokens.
//
// A theme is a folder with a theme.json (format in the README), found in:
//   <shell>/themes/<id>                       built-in themes (this repo)
//   ~/.local/share/pocket-shell/themes/<id>   themes the user installs
// A user theme with the same folder name as a built-in one replaces it.
// Anything a theme leaves out falls back to Dusk Tide, so a theme can be
// as small as a name and an accent colour. Themes are data only: they can
// pick from built-in layouts and styles, but never run code.
//
// Sizes are logical px: the RP5 in landscape at scale 2 is 960x540.
Singleton {
    id: theme

    readonly property string builtinDir: Quickshell.shellPath("themes")
    readonly property string userDir: (Quickshell.env("HOME") || "") + "/.local/share/pocket-shell/themes"

    // Dusk Tide: the fallback for every key.
    readonly property var defaults: ({
        name: "Dusk Tide",
        colors: {
            bg: "#1A2838",
            surface: "rgba(14, 36, 40, 0.72)",
            surfaceStrong: "rgba(14, 36, 40, 0.95)",
            surfaceBorder: "rgba(207, 230, 225, 0.12)",
            chip: "#1F4447",
            chipFocused: "#2C5A5B",
            focusGap: "#0B2222",
            keyBorder: "rgba(207, 230, 225, 0.40)",
            line: "rgba(207, 230, 225, 0.22)",
            textStrong: "#EAF3F1",
            text: "#DDEBE8",
            textMuted: "#A9C4C0",
            textHint: "#C3D8D4",
            iconOnChip: "#CFE6E1",
            accent: "#F4B78E",
            inkDark: "#2B1A10",
            inkLight: "#FFFFFF",
            dim: "rgba(8, 22, 24, 0.66)",
            scrim: "rgba(6, 16, 18, 0.85)",
            ledge: "rgba(0, 0, 0, 0.25)",
            bar: "transparent",
            scanline: "rgba(0, 0, 0, 0.22)",
            barBorder: "transparent"
        },
        accentChoices: ["#F4B78E", "#9FE0C9", "#C9B6F2", "#F2D37A"],
        cardColors: ["#2F5A45", "#463A66", "#3E4650", "#5A4A2E", "#2E4A5A", "#5A2E46", "#3A5A2E", "#4A3A2E"],
        radii: { card: 6, art: 4, pill: 4, btn: 4, icon: 6, dock: 8, key: 2 },
        fonts: { display: "Archivo", body: "Manrope", files: [], displayGrid: 0, displayScale: 1 },
        focus: { gap: 2, ring: 2 },
        wallpaper: { type: "scene", scene: "dusk-tide" },
        sounds: "soft",
        style: {
            border: 1,
            bevel: false,
            squareIcons: false,
            keys: "outline",
            tabs: "segmented",
            status: "icons",
            cards: "card",
            home: "classic",
            textCase: "normal",
            titlePrefix: "",
            cursor: false,
            scanlines: false
        }
    })

    // --- Current theme
    //
    // Switching themes reads from `installed` (every theme.json, already
    // parsed by the scan below), so it's instant. FileViews are only used
    // for the very first load at startup, before the scan finishes, and to
    // notice when the current theme's file is edited (which rescans).

    readonly property string currentId: Store.theme

    readonly property var currentEntry: {
        const list = installed;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === currentId)
                return list[i];
        }
        return null;
    }

    readonly property var themeData: currentEntry ? currentEntry.data
        : (bootId === currentId && bootData ? bootData : defaults)
    readonly property string dir: currentEntry ? currentEntry.dir
        : (bootId === currentId && bootData ? bootDir : "")

    // --- Modes
    //
    // A theme can offer variants under "modes", a list such as
    // [ { "id": "dark", "label": "dark" },
    //   { "id": "paper", "colors": {...}, "wallpaper": {...} } ].
    // Each mode overrides the keys it lists (the first is usually the
    // theme as written, with nothing to override). "defaultMode" picks the
    // one used until you choose; else the first. The pick is saved per
    // theme. (A list, not an object: theme data passes through Qt maps,
    // which sort object keys, so only a list keeps the order.)
    function modesOf(data) {
        const m = data ? data.modes : null;
        if (!m || typeof m !== "object")
            return [];
        if (Array.isArray(m))
            return m.filter(e => e && typeof e === "object" && e.id);
        return Object.keys(m).map(k => Object.assign({ id: k }, m[k]));
    }

    function modeNameFor(data, id) {
        const ids = modesOf(data).map(e => e.id);
        const saved = Store.modes[id];
        return ids.indexOf(saved) >= 0 ? saved
            : ids.indexOf(data.defaultMode) >= 0 ? data.defaultMode : (ids.length > 0 ? ids[0] : "");
    }

    readonly property var modeEntries: modesOf(themeData)
    readonly property var modeList: modeEntries.map(e => e.id)
    readonly property string currentMode: modeNameFor(themeData, currentId)
    readonly property var modeData: {
        const i = modeList.indexOf(currentMode);
        return i >= 0 ? modeEntries[i] : null;
    }
    // Favourite colours are kept per mode (a light accent rarely suits
    // dark); the first mode uses the theme's own key.
    readonly property string accentKey: modeList.indexOf(currentMode) > 0 ? `${currentId}:${currentMode}` : currentId

    // A theme's data with its mode applied, for previews of other themes:
    // object keys (colors, style...) merge, everything else is replaced.
    function withMode(data, id) {
        const entries = modesOf(data);
        if (entries.length === 0)
            return data;
        const name = modeNameFor(data, id);
        const mode = entries.find(e => e.id === name) || {};
        const plain = v => v && typeof v === "object" && !Array.isArray(v);
        const out = Object.assign({}, data);
        for (const k of Object.keys(mode)) {
            if (k === "id" || k === "label")
                continue;
            const a = data[k], b = mode[k];
            out[k] = k !== "wallpaper" && plain(a) && plain(b) ? Object.assign({}, a, b) : b;
        }
        return out;
    }

    function modeLabel(id) {
        const e = modeEntries.find(m => m.id === id);
        return e && e.label ? e.label : id;
    }

    function useMode(id) {
        Store.setMode(currentId, id);
    }

    property var bootData: null
    property string bootId: ""
    property string bootDir: ""

    function parse(text) {
        if (!text)
            return null;
        try {
            const d = JSON.parse(text);
            return d && typeof d === "object" ? d : null;
        } catch (e) {
            console.warn(`Theme: a theme.json isn't valid JSON (${e})`);
            return null;
        }
    }

    // Startup only: read the saved theme directly so there's no flash of
    // the default theme while the scan runs. Paths are set once here and
    // never changed, so the reads can't return another theme's contents.
    function boot() {
        const id = currentId;
        bootUser.path = `${userDir}/${id}/theme.json`;
        bootBuiltin.path = `${builtinDir}/${id}/theme.json`;
        let d = parse(bootUser.text());
        let where = `${userDir}/${id}`;
        if (!d) {
            d = parse(bootBuiltin.text());
            where = `${builtinDir}/${id}`;
        }
        bootId = id;
        bootData = d;
        bootDir = d ? where : "";
    }

    onCurrentIdChanged: {
        if (!currentEntry)
            refresh();
    }

    Component.onCompleted: {
        boot();
        refresh();
    }

    FileView {
        id: bootUser
        blockLoading: true
        printErrors: false
    }

    FileView {
        id: bootBuiltin
        blockLoading: true
        printErrors: false
    }

    // Live editing: when the current theme's file changes, rescan.
    FileView {
        path: theme.dir ? `${theme.dir}/theme.json` : ""
        printErrors: false
        watchChanges: true
        onFileChanged: theme.refresh()
    }

    // Value at a dotted path in the current mode, else the theme, else the
    // defaults.
    function get(path) {
        const keys = path.split(".");
        let v = modeData;
        for (let i = 0; i < keys.length && v !== undefined && v !== null; i++)
            v = v[keys[i]];
        if (v !== undefined && v !== null)
            return v;
        v = themeData;
        for (let i = 0; i < keys.length && v !== undefined && v !== null; i++)
            v = v[keys[i]];
        if (v !== undefined && v !== null)
            return v;
        v = defaults;
        for (let i = 0; i < keys.length && v !== undefined && v !== null; i++)
            v = v[keys[i]];
        return v;
    }

    // Accepts "#RGB", "#RRGGBB", "#AARRGGBB", names, "rgb(r, g, b)" and "rgba(r, g, b, a)".
    function toColor(value) {
        if (typeof value !== "string")
            return value;
        const m = value.match(/^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*([\d.]+)\s*)?\)$/);
        if (m)
            return Qt.rgba(m[1] / 255, m[2] / 255, m[3] / 255, m[4] === undefined ? 1 : Number(m[4]));
        return value;
    }

    function col(path) {
        return toColor(get(path));
    }

    function luminance(c) {
        const lin = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    function mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    // --- Tokens

    readonly property string name: get("name")

    // Accent: the user's pick for this theme, else the theme's own.
    readonly property color accent: toColor(Store.accents[accentKey] || get("colors.accent"))
    readonly property color accentInk: luminance(accent) > 0.45 ? col("colors.inkDark") : col("colors.inkLight")
    readonly property color accentDeep: mix(accent, Qt.rgba(0, 0, 0, 1), 0.28)
    readonly property color accentPale: mix(accent, Qt.rgba(1, 1, 1, 1), 0.85)
    readonly property color accentGlow: Qt.rgba(accent.r, accent.g, accent.b, 0.5)
    readonly property var accentChoices: get("accentChoices")

    readonly property color bg: col("colors.bg")
    readonly property color surface: col("colors.surface")
    readonly property color surfaceStrong: col("colors.surfaceStrong")
    readonly property color surfaceBorder: col("colors.surfaceBorder")
    readonly property color chip: col("colors.chip")
    readonly property color chipFocused: col("colors.chipFocused")
    readonly property color focusGap: col("colors.focusGap")
    readonly property color keyBorder: col("colors.keyBorder")
    readonly property color line: col("colors.line")
    readonly property color textStrong: col("colors.textStrong")
    readonly property color text: col("colors.text")
    readonly property color textMuted: col("colors.textMuted")
    readonly property color textHint: col("colors.textHint")
    readonly property color iconOnChip: col("colors.iconOnChip")
    readonly property color dim: col("colors.dim")
    readonly property color scrim: col("colors.scrim")
    readonly property color ledge: col("colors.ledge")
    readonly property color bar: col("colors.bar")
    readonly property color barBorder: col("colors.barBorder")
    readonly property color scanline: col("colors.scanline")
    readonly property var cardColors: get("cardColors")

    readonly property real rCard: get("radii.card")
    readonly property real rArt: get("radii.art")
    readonly property real rPill: get("radii.pill")
    readonly property real rBtn: get("radii.btn")
    readonly property real rIcon: get("radii.icon")
    readonly property real rDock: get("radii.dock")
    readonly property real rKey: get("radii.key")

    readonly property real focusGapWidth: get("focus.gap")
    readonly property real focusRingWidth: get("focus.ring")

    readonly property string displayFont: get("fonts.display")
    readonly property string bodyFont: get("fonts.body")

    // Pixel display fonts: the font's pixel grid in px at size 1x (8 for an
    // 8x8 font), and a scale for fonts much wider than the default.
    readonly property int displayGrid: get("fonts.displayGrid") || 0
    readonly property real displayScale: get("fonts.displayScale") || 1
    readonly property bool pixelDisplay: displayGrid > 0

    // Size for display text: scaled, then snapped to whole grid steps.
    function displaySize(px) {
        const s = px * displayScale;
        if (displayGrid <= 0)
            return Math.max(1, Math.round(s));
        return Math.max(displayGrid, Math.round(s / displayGrid) * displayGrid);
    }

    readonly property var wallpaper: get("wallpaper")
    readonly property string soundPack: get("sounds")

    readonly property real borderWidth: get("style.border")
    readonly property bool bevel: get("style.bevel") === true
    readonly property bool squareIcons: get("style.squareIcons") === true
    readonly property string keyStyle: get("style.keys")        // "outline" | "filled"
    readonly property string tabStyle: get("style.tabs")        // "segmented" | "buttons" | "workspaces" | "numbers"
    readonly property string statusStyle: get("style.status")   // "icons" | "pixel" | "text" | "stats"
    readonly property string cardStyle: get("style.cards")      // "card" | "cartridge"
    readonly property string homeLayout: get("style.home")      // "classic" | "panels" | "fetch" | "tiles"
    readonly property bool lowercase: get("style.textCase") === "lower"
    readonly property string titlePrefix: get("style.titlePrefix") || ""
    readonly property bool cursor: get("style.cursor") === true          // blinking block after titles
    readonly property bool scanlines: get("style.scanlines") === true    // CRT lines over everything

    // Labels in the theme's text case (titles, tabs, buttons, hints).
    function label(text) {
        return lowercase ? String(text).toLowerCase() : text;
    }

    // Spacing
    readonly property real touchMin: 44
    readonly property real edge: 48

    // A colour for a system or collection, stable per key.
    function tintFor(key) {
        const list = cardColors;
        let h = 0;
        for (let i = 0; i < key.length; i++)
            h = (h * 31 + key.charCodeAt(i)) % 9973;
        return list[h % list.length];
    }

    // Fonts a theme ships in its folder ("fonts": { "files": [...] }).
    Instantiator {
        model: theme.dir ? (theme.get("fonts.files") || []) : []
        delegate: FontLoader {
            required property string modelData
            source: "file://" + theme.dir + "/" + modelData
        }
    }

    // --- Installed themes, for the picker

    // [{ id, dir, user, name, author, description, colors... (raw data) }]
    property var installed: []
    property bool rescanQueued: false

    function refresh() {
        if (scanner.running)
            rescanQueued = true;
        else
            scanner.running = true;
    }

    function useTheme(id) {
        Store.setTheme(id);
    }

    function setAccent(color) {
        Store.setAccent(accentKey, color);
    }

    Process {
        id: scanner
        command: ["sh", "-c",
            "for root in \"$1\" \"$2\"; do for d in \"$root\"/*/; do " +
            "[ -f \"$d/theme.json\" ] || continue; " +
            "printf '%s\\t%s\\t' \"$root\" \"${d%/}\"; tr '\\n\\t' '  ' < \"$d/theme.json\"; printf '\\n'; " +
            "done; done",
            "sh", theme.builtinDir, theme.userDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const byId = {};
                const order = [];
                const lines = text.split("\n");
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("\t");
                    if (parts.length < 3)
                        continue;
                    const root = parts[0];
                    const dir = parts[1];
                    const d = theme.parse(parts.slice(2).join("\t"));
                    if (!d)
                        continue;
                    const id = dir.substring(dir.lastIndexOf("/") + 1);
                    if (byId[id] === undefined)
                        order.push(id);
                    byId[id] = { id: id, dir: dir, user: root === theme.userDir, data: d };
                }
                const list = order.map(id => byId[id]);
                list.sort((x, y) => String(x.data.name || x.id).localeCompare(String(y.data.name || y.id)));
                theme.installed = list;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (theme.rescanQueued) {
                theme.rescanQueued = false;
                running = true;
            }
        }
    }
}
