pragma Singleton
import QtQuick
import Quickshell

// Per-device facts the shell needs. Mirrors devices/rp5.md.
// The compositor side (mode, scale, rotation, touch) lives in hypr/hyprland.lua.
Singleton {
    id: device

    readonly property string name: "Retroid Pocket 5"

    // This device's screens and what each one is for:
    //   main   - navigation: pages, dock, toggles, keyboard. Controller focus lives here.
    //   second - display only: showcase art and ambience (dual-screen devices).
    // Screens not listed here get no shell window.
    readonly property var panels: [
        { output: "DSI-1", role: "main" }
    ]

    function roleOf(screen) {
        if (!screen)
            return "none";
        for (let i = 0; i < panels.length; i++) {
            if (panels[i].output === screen.name)
                return panels[i].role;
        }
        return "none";
    }

    // Screens that get a shell window. If none of the listed outputs exist
    // (renamed output, unknown device), the first screen is used as main so
    // the shell still shows up.
    readonly property var shellScreens: {
        const list = Quickshell.screens;
        const out = [];
        for (let i = 0; i < list.length; i++) {
            if (roleOf(list[i]) !== "none")
                out.push(list[i]);
        }
        if (out.length === 0 && list.length > 0)
            out.push(list[0]);
        return out;
    }

    // The main (navigation) screen.
    readonly property ShellScreen screen: {
        const list = shellScreens;
        for (let i = 0; i < list.length; i++) {
            if (roleOf(list[i]) === "main")
                return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }

    readonly property bool portrait: screen !== null && screen.height > screen.width
    readonly property bool dualScreen: {
        const list = shellScreens;
        for (let i = 0; i < list.length; i++) {
            if (roleOf(list[i]) === "second")
                return true;
        }
        return false;
    }
}
