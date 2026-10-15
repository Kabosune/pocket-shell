pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The shell's side of bin/pocket-play: shows and hides the video of what
// it's playing, and passes the controller to mpv while the video is up
// (A pause, left/right seek, B/Back back to sound only).
//
// pocket-play runs mpv with sound only and an IPC socket; video is turned
// on by setting mpv's "vid" property, which opens its window on the
// workspace in front, so the shell moves to a free workspace first.
Singleton {
    id: pp

    readonly property string socketPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/pocket-play.sock"
    readonly property string appId: "pocket-play"
    property var queue: []

    function appIdOf(toplevel) {
        if (!toplevel)
            return "";
        if (toplevel.wayland && toplevel.wayland.appId)
            return toplevel.wayland.appId;
        const ipc = toplevel.lastIpcObject;
        return ipc && ipc["class"] ? ipc["class"] : "";
    }

    // The video window, when it's open
    readonly property var window: {
        const list = Hyprland.toplevels.values;
        for (let i = 0; i < list.length; i++) {
            if (appIdOf(list[i]) === appId)
                return list[i];
        }
        return null;
    }

    // The video is the app in front
    readonly property bool inFront: !Wm.inShell && appIdOf(Hyprland.activeToplevel) === appId

    // A media player reported by mpv (mpv-mpris names it "mpv")
    function isPlayer(player) {
        return player !== null && player !== undefined && /mpv/i.test(player.identity || "");
    }

    function send(command) {
        queue = queue.concat([JSON.stringify({ command: command })]);
        if (sock.connected)
            flushQueue();
        else
            sock.connected = true;
    }

    function flushQueue() {
        for (let i = 0; i < queue.length; i++)
            sock.write(queue[i] + "\n");
        sock.flush();
        queue = [];
    }

    function showVideo() {
        if (window) {
            Wm.focusApp(window);
            return;
        }
        Wm.focusWorkspace(Wm.freeWorkspace());
        send(["set_property", "vid", "auto"]);
        send(["set_property", "fullscreen", true]);
        Sfx.play("launch", 2);
    }

    // Back to sound only (the window closes) and to the shell
    function hideVideo() {
        send(["set_property", "vid", "no"]);
        Wm.goHome();
        Sfx.play("back", 1);
    }

    // Something to watch: PlasmaTube (KDE's YouTube app) when installed,
    // else YouTube in the default browser.
    function browse() {
        const app = DesktopEntries.byId("org.kde.plasmatube");
        if (app)
            Wm.launchEntry(app);
        else
            Wm.launchCommand(["xdg-open", "https://m.youtube.com/"]);
    }

    function togglePause() {
        send(["cycle", "pause"]);
    }

    function seek(seconds) {
        send(["seek", seconds]);
    }

    // Buttons while the video is in front. Returns true if used.
    function handle(button) {
        switch (button) {
        case "a":
            togglePause();
            return true;
        case "left":
            seek(-10);
            return true;
        case "right":
            seek(10);
            return true;
        case "b":
        case "back":
        case "home":
            hideVideo();
            return true;
        }
        return false;
    }

    Socket {
        id: sock
        path: pp.socketPath
        onConnectedChanged: {
            if (connected && pp.queue.length > 0)
                pp.flushQueue();
        }
        onError: error => {
            pp.queue = [];
            console.warn(`pocket-play: can't reach mpv (${error})`);
        }
    }

    // `pocket-play --show` and friends, from a terminal or SSH
    IpcHandler {
        target: "pocketplay"

        function show(): void {
            pp.showVideo();
        }
        function hide(): void {
            pp.hideVideo();
        }
        function pause(): void {
            pp.togglePause();
        }
    }
}
