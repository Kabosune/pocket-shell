pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// What the Back button does inside an app. The app in front is matched by
// its app id (Wayland) / window class (X11), and gets the key or shortcut
// listed for it; anything not listed gets Escape.
//
// Each rule: { match: /regexp on the app id/, mods: "", key: "F1" }.
// Key names are Hyprland's (xkb names: F1, Escape, Left...).
Singleton {
    id: back

    readonly property var rules: [
        // RetroArch: its menu (Quick Menu while a game runs). F1 is its
        // default "menu toggle" key.
        { match: /retroarch/i, mods: "", key: "F1" },
        // Web browsers: previous page
        { match: /angelfish|firefox|chromium|falkon/i, mods: "ALT", key: "Left" }
    ]
    readonly property var fallback: ({ mods: "", key: "Escape" })

    function appId() {
        const t = Hyprland.activeToplevel;
        if (!t)
            return "";
        if (t.wayland && t.wayland.appId)
            return t.wayland.appId;
        const ipc = t.lastIpcObject;
        return ipc && ipc["class"] ? ipc["class"] : "";
    }

    function ruleFor(id) {
        for (let i = 0; i < rules.length; i++) {
            if (rules[i].match.test(id))
                return rules[i];
        }
        return fallback;
    }

    function press() {
        const rule = ruleFor(appId());
        Wm.sendShortcut(rule.mods, rule.key);
    }
}
