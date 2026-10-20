pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

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

    // Window addresses, most recently used first (kept from Hyprland's
    // active window as it changes).
    property var mru: []

    // Open apps, most recently used first.
    readonly property var appsByRecent: {
        const list = apps.filter(t => t.workspace !== null && t.workspace.id > 0);
        const rank = t => {
            const i = mru.indexOf(t.address);
            return i < 0 ? mru.length : i;
        };
        list.sort((a, b) => rank(a) - rank(b));
        return list;
    }

    // Fresh window info (classes for names and icons)
    function refreshWindows() {
        Hyprland.refreshToplevels();
    }

    // The app in front (null in the shell).
    readonly property var frontApp: {
        const ws = Hyprland.focusedWorkspace;
        return ws && ws.toplevels.values.length > 0 ? ws.toplevels.values[0] : null;
    }

    // The app to jump to with a double tap on Home: the most recent one
    // whose address isn't `except` (the app you were just in, if any).
    function recentApp(except) {
        const list = appsByRecent;
        for (let i = 0; i < list.length; i++) {
            if (list[i].address !== except)
                return list[i];
        }
        return null;
    }

    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            const t = Hyprland.activeToplevel;
            if (!t || !t.address || !t.workspace || t.workspace.id === wm.homeWorkspace)
                return;
            wm.mru = [t.address].concat(wm.mru.filter(a => a !== t.address)).slice(0, 64);
        }
        // New windows: fetch their class etc. so they can be matched to apps
        function onRawEvent(event) {
            if (event.name === "openwindow")
                Hyprland.refreshToplevels();
        }
    }

    // Hyprland 0.56 can run with a Lua config, where dispatchers are Lua calls.
    function focusWorkspace(id) {
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
        else
            Hyprland.dispatch(`workspace ${id}`);
    }

    // Send a key or shortcut to the window in front (mods like "ALT",
    // "" for none; key names as in Hyprland binds).
    function sendShortcut(mods, key) {
        if (Hyprland.usingLua)
            Hyprland.dispatch(`hl.dsp.send_shortcut({ mods = "${mods}", key = "${key}" })`);
        else
            Hyprland.dispatch(`sendshortcut ${mods}, ${key}, activewindow`);
    }

    function addressOf(toplevel) {
        const a = toplevel ? toplevel.address : "";
        return !a ? "" : a.indexOf("0x") === 0 ? a : `0x${a}`;
    }

    function closeActiveWindow() {
        if (Hyprland.usingLua)
            Hyprland.dispatch("hl.dsp.window.close()");
        else
            Hyprland.dispatch("killactive");
    }

    // Lowest workspace number above home with no windows on it, and not
    // kept for an app that's still starting.
    function freeWorkspace() {
        const used = {};
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].toplevels.values.length > 0)
                used[list[i].id] = true;
        }
        for (let i = 0; i < launches.length; i++)
            used[launches[i].workspace] = true;
        let id = homeWorkspace + 1;
        while (used[id])
            id += 1;
        return id;
    }

    function goHome() {
        focusWorkspace(homeWorkspace);
    }

    // --- Launching
    //
    // Apps take a few seconds to show a window. Until then the launch is
    // "in flight": its workspace is kept for it, Main shows an "Opening…"
    // screen there, and pressing the same app again just goes back to that
    // screen instead of starting a second copy. An app that already has a
    // window is brought to the front instead of started again.
    //
    // Each in-flight launch: { key, name, entry, art, workspace, since }

    property var launches: []
    readonly property int launchTimeout: 30000

    // A window from the launch showed up while you were elsewhere.
    signal launchReady(string name)
    // Nothing showed up in time.
    signal launchTimedOut(string name, bool inFront)

    // The launch whose workspace is in front (null if none).
    readonly property var launchHere: {
        const ws = Hyprland.focusedWorkspace;
        if (!ws)
            return null;
        for (let i = 0; i < launches.length; i++) {
            if (launches[i].workspace === ws.id)
                return launches[i];
        }
        return null;
    }

    function launchFor(key) {
        for (let i = 0; i < launches.length; i++) {
            if (launches[i].key === key)
                return launches[i];
        }
        return null;
    }

    function launchEntry(entry) {
        if (!entry)
            return;
        const open = windowFor(entry);
        if (open) {
            focusApp(open);
            return;
        }
        startLaunch({ key: `entry:${entry.id}`, name: entry.name, entry: entry, art: "" }, ws => {
            if (entry.runInTerminal || !entry.command || entry.command.length === 0)
                entry.execute();
            else
                execOn(ws, entry.command, entry.workingDirectory, () => entry.execute());
        });
    }

    // info (optional): { key, name, art, track } — key defaults to the
    // command line. track: false for commands that hand off to something
    // already running (xdg-open), where no new window may ever come.
    function launchCommand(args, info) {
        if (!args || args.length === 0)
            return;
        if (info && info.track === false) {
            focusWorkspace(freeWorkspace());
            Quickshell.execDetached(args);
            Sfx.play("launch", 2);
            return;
        }
        const meta = {
            key: info && info.key ? info.key : `cmd:${args.join(" ")}`,
            name: info && info.name ? info.name : args[0].split("/").pop(),
            entry: null,
            art: info && info.art ? info.art : ""
        };
        startLaunch(meta, ws => execOn(ws, args, "", () => Quickshell.execDetached(args)));
    }

    function startLaunch(meta, run) {
        const pending = launchFor(meta.key);
        if (pending) {
            // Already starting: show its "Opening…" screen again
            focusWorkspace(pending.workspace);
            Sfx.play("page", 1);
            return;
        }
        const ws = freeWorkspace();
        const launch = Object.assign({ workspace: ws, since: Date.now() }, meta);
        launches = launches.concat([launch]);
        focusWorkspace(ws);
        run(ws);
        Sfx.play("launch", 2);
    }

    function workspaceById(id) {
        const list = Hyprland.workspaces.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === id)
                return list[i];
        }
        return null;
    }

    // Called every so often while something is starting.
    function checkLaunches() {
        const front = Hyprland.focusedWorkspace;
        const done = [];
        for (let i = 0; i < launches.length; i++) {
            const l = launches[i];
            const ws = workspaceById(l.workspace);
            const opened = (ws && ws.toplevels.values.length > 0) || (l.entry && windowFor(l.entry) !== null);
            if (opened) {
                done.push(l);
                if (!front || front.id !== l.workspace)
                    launchReady(l.name);
            } else if (Date.now() - l.since > launchTimeout) {
                done.push(l);
                const inFront = front !== null && front.id === l.workspace;
                launchTimedOut(l.name, inFront);
                if (inFront)
                    goHome();
            }
        }
        if (done.length > 0)
            launches = launches.filter(l => done.indexOf(l) < 0);
    }

    Timer {
        interval: 400
        repeat: true
        running: wm.launches.length > 0
        onTriggered: wm.checkLaunches()
    }

    // Start a command through Hyprland with a rule that puts its window on
    // `ws` (quietly), so it lands there even if you went Home meanwhile.
    // If Hyprland turns the request down, `fallback` starts it the plain way.
    function execOn(ws, args, dir, fallback) {
        // (args may be a QML list, so no .map)
        const words = [];
        for (let i = 0; i < args.length; i++)
            words.push(shellQuote(args[i]));
        let cmd = "exec " + words.join(" ");
        if (dir)
            cmd = `cd ${shellQuote(dir)} && ${cmd}`;
        const request = Hyprland.usingLua
            ? `hl.dsp.exec_cmd(${luaString(cmd)}, { workspace = "${ws} silent" })`
            : `exec [workspace ${ws} silent] ${cmd}`;
        hyprDispatch(request, fallback);
    }

    // Run a dispatcher through hyprctl so we hear whether it worked
    // (Hyprland answers "ok" or the error); on failure run `fallback`.
    function hyprDispatch(request, fallback) {
        hyprRunner.createObject(wm, { request: request, fallback: fallback });
    }

    function shellQuote(s) {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // Lua long string, so nothing inside needs escaping
    function luaString(s) {
        let eq = "";
        while (s.indexOf("]" + eq + "]") >= 0)
            eq += "=";
        return `[${eq}[${s}]${eq}]`;
    }

    Component {
        id: hyprRunner

        Process {
            id: runner
            property string request: ""
            property var fallback: null
            property int code: -1
            property bool replied: false

            // Decide once both the exit code and the full reply are in
            function decide() {
                if (code < 0 || !replied)
                    return;
                const text = reply.text.trim();
                const failed = code !== 0 || (text !== "" && text.toLowerCase().indexOf("ok") !== 0);
                if (failed) {
                    console.warn(`pocket-shell: Hyprland didn't take "${request}" (${text || code}); using the fallback`);
                    if (fallback)
                        fallback();
                }
                runner.destroy();
            }

            command: ["hyprctl", "dispatch", request]
            Component.onCompleted: running = true
            stdout: StdioCollector {
                id: reply
                onStreamFinished: {
                    runner.replied = true;
                    runner.decide();
                }
            }
            onExited: (exitCode, exitStatus) => {
                runner.code = exitCode;
                runner.decide();
            }
        }
    }

    function focusApp(toplevel) {
        if (toplevel && toplevel.workspace) {
            focusWorkspace(toplevel.workspace.id);
            Sfx.play("page", 1);
        }
    }

    // Ask an app to close, without bringing it to the front. If Hyprland
    // doesn't take the request, falls back to focusing it, closing the
    // active window and coming back to the shell.
    function closeApp(toplevel) {
        if (!toplevel || !toplevel.workspace)
            return;
        closeQuietly(toplevel);
        Sfx.play("toggle-off", 2);
    }

    function closeApps(list) {
        for (let i = 0; i < list.length; i++)
            closeQuietly(list[i]);
        if (list.length > 0)
            Sfx.play("toggle-off", 2);
    }

    function closeQuietly(toplevel) {
        const address = addressOf(toplevel);
        const ws = toplevel.workspace ? toplevel.workspace.id : -1;
        const fallback = () => {
            if (ws < 0)
                return;
            closeQueue = closeQueue.concat([ws]);
            if (!closeTimer.running && !backTimer.running)
                closeNext();
        };
        if (!address) {
            fallback();
            return;
        }
        hyprDispatch(Hyprland.usingLua
            ? `hl.dsp.window.close({ window = "address:${address}" })`
            : `closewindow address:${address}`, fallback);
    }

    // Workspaces still to close the plain way (focus, close, next)
    property var closeQueue: []

    function closeNext() {
        if (closeQueue.length === 0) {
            backTimer.restart();
            return;
        }
        focusWorkspace(closeQueue[0]);
        closeQueue = closeQueue.slice(1);
        closeTimer.restart();
    }

    // Best-effort name for a window: its desktop entry's name, else its title.
    function appName(toplevel) {
        const entry = entryFor(toplevel);
        return entry ? entry.name : (toplevel ? toplevel.title : "");
    }

    function classOf(toplevel) {
        const ipc = toplevel ? toplevel.lastIpcObject : null;
        return ipc && ipc["class"] ? ipc["class"] : "";
    }

    // Does a window class belong to this desktop entry? Tries the entry's
    // id (and its last dotted part, org.kde.plasmatube → plasmatube), its
    // StartupWMClass, then Quickshell's own guess.
    function classMatches(entry, cls) {
        if (!entry || !cls)
            return false;
        const c = cls.toLowerCase();
        const id = (entry.id || "").toLowerCase();
        const startup = (entry.startupClass || "").toLowerCase();
        if (c === id || c === id.split(".").pop() || (startup !== "" && c === startup))
            return true;
        const guess = DesktopEntries.heuristicLookup(cls);
        return guess ? guess.id === entry.id : false;
    }

    // An open window of this app, or null.
    function windowFor(entry) {
        const list = Hyprland.toplevels.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].workspace && classMatches(entry, classOf(list[i])))
                return list[i];
        }
        return null;
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
            wm.closeNext();
        }
    }

    Timer {
        id: backTimer
        interval: 150
        onTriggered: wm.goHome()
    }
}
