pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Window management through Hyprland.
//
// The shell sits on the bottom layer, under app windows. Workspace 1 is
// kept empty as "home": when it's focused, the shell is what you see.
// Every app or game launched from the shell gets its own empty workspace,
// so switching apps is just switching workspaces.
Singleton {
    id: wm

    readonly property int homeWorkspace: 1

    // True when no app window covers the shell on the focused workspace.
    readonly property bool inShell: {
        const ws = Hyprland.focusedWorkspace;
        return ws === null || ws.toplevels.values.length === 0;
    }

    // Open app windows, for Recents.
    readonly property var apps: Hyprland.toplevels.values

    // Hyprland 0.56 can run with a Lua config, where dispatchers are Lua calls.
    function focusWorkspace(id) {
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
        else
            Hyprland.dispatch(`workspace ${id}`);
    }

    function closeActiveWindow() {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.window.close()");
        else
            Hyprland.dispatch("killactive");
    }

    // Lowest workspace number above home with no windows on it.
    function freeWorkspace() {
        const used = {};
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].toplevels.values.length > 0)
                used[list[i].id] = true;
        }
        let id = homeWorkspace + 1;
        while (used[id])
            id += 1;
        return id;
    }

    function goHome() {
        focusWorkspace(homeWorkspace);
    }

    function launchEntry(entry) {
        if (!entry)
            return;
        focusWorkspace(freeWorkspace());
        entry.execute();
    }

    function launchCommand(args) {
        if (!args || args.length === 0)
            return;
        focusWorkspace(freeWorkspace());
        Quickshell.execDetached(args);
    }

    function focusApp(toplevel) {
        if (toplevel && toplevel.workspace)
            focusWorkspace(toplevel.workspace.id);
    }

    // Focus the app, close it, then come back to the shell.
    function closeApp(toplevel) {
        if (!toplevel || !toplevel.workspace)
            return;
        focusWorkspace(toplevel.workspace.id);
        closeTimer.restart();
    }

    // Best-effort name for a window: its desktop entry's name, else its title.
    function appName(toplevel) {
        const entry = entryFor(toplevel);
        return entry ? entry.name : (toplevel ? toplevel.title : "");
    }

    function entryFor(toplevel) {
        if (!toplevel)
            return null;
        const ipc = toplevel.lastIpcObject;
        const cls = ipc && ipc["class"] ? ipc["class"] : "";
        return cls ? DesktopEntries.heuristicLookup(cls) : null;
    }

    Timer {
        id: closeTimer
        interval: 150
        onTriggered: {
            wm.closeActiveWindow();
            backTimer.restart();
        }
    }

    Timer {
        id: backTimer
        interval: 150
        onTriggered: wm.goHome()
    }
}
