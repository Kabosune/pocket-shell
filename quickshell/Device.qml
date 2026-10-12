pragma Singleton
import QtQuick
import Quickshell

// Per-device facts the shell needs. Mirrors devices/rp5.md.
// The compositor side (mode, scale, rotation, touch) lives in hypr/hyprland.lua.
Singleton {
    readonly property string name: "Retroid Pocket 5"
    readonly property string outputName: "DSI-1"

    // The built-in panel, or the first screen if it isn't found.
    readonly property ShellScreen screen: {
        const list = Quickshell.screens;
        for (let i = 0; i < list.length; i++) {
            if (list[i].name === outputName)
                return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }

    readonly property bool portrait: screen !== null && screen.height > screen.width
}
