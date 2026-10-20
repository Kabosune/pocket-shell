pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Gamepad input. Runs the pocket-input helper (input/pocket-input.c) and
// turns its lines into signals. D-pad and stick directions auto-repeat.
// The Home button sends "home" on a tap and "recents" when held.
// Home + R1 sends "screenshot" (and neither press counts on its own).
//
// Back button: handhelds run through InputPlumber with an Xbox 360-style
// pad have no Back button on that pad. While Pocket Shell runs, its
// InputPlumber profile turns the device's Back into F20, which Hyprland
// catches and sends here (`qs ipc call controller back`), so apps never
// see it. Without that profile, InputPlumber sends Back as Guide, then A
// 80 ms later; a Home press followed by A within `chordWindow` is still
// read as "back", and neither the Home nor the A goes to the shell.
Singleton {
    id: controller

    // True after controller input, false after a touch. Focus rings only
    // show while this is true, like a console UI.
    property bool active: false
    property int padCount: 0
    property string padName: ""
    readonly property bool connected: padCount > 0

    // `repeat` is true for auto-repeated direction presses.
    signal pressed(string button, bool repeat)
    signal released(string button)

    readonly property var directions: ["up", "down", "left", "right"]
    property string held: ""

    readonly property int chordWindow: 160
    property real homeDownAt: 0
    property bool backChord: false
    property bool homeDown: false
    property bool shotChord: false

    function handle(line) {
        const space = line.indexOf(" ");
        const kind = space < 0 ? line : line.slice(0, space);
        const arg = space < 0 ? "" : line.slice(space + 1);

        if (kind === "down" && arg === "home") {
            // Home is decided on release: a tap is "home", holding is "recents".
            homeDownAt = Date.now();
            backChord = false;
            homeDown = true;
            homeHold.restart();
            return;
        }
        if (kind === "down" && arg === "r1" && homeDown) {
            // Screenshot. Stopping the hold timer also means releasing Home
            // won't count as a tap.
            shotChord = true;
            homeHold.stop();
            pressed("screenshot", false);
            return;
        }
        if (kind === "up" && arg === "r1" && shotChord) {
            shotChord = false;
            return;
        }
        if (kind === "down" && arg === "a" && homeHold.running && Date.now() - homeDownAt <= chordWindow) {
            backChord = true;
            homeHold.stop();
            return;
        }
        if (kind === "up" && arg === "a" && backChord)
            return;
        if (kind === "up" && arg === "home")
            homeDown = false;
        if (kind === "up" && arg === "home" && backChord) {
            // Fires on release, like a phone's back button
            backChord = false;
            active = true;
            pressed("back", false);
            released("back");
            return;
        }
        if (kind === "up" && arg === "home") {
            if (homeHold.running) {
                homeHold.stop();
                pressed("home", false);
            }
            released(arg);
            return;
        }

        if (kind === "down") {
            const isDirection = directions.indexOf(arg) >= 0;
            // The first direction or A press after touch only reveals focus
            // (in the shell; in an app every press counts).
            const revealOnly = !active && Wm.inShell && (isDirection || arg === "a");
            active = true;
            if (revealOnly)
                return;
            if (isDirection) {
                held = arg;
                repeatTimer.interval = 380;
                repeatTimer.restart();
            }
            pressed(arg, false);
        } else if (kind === "up") {
            if (held === arg) {
                held = "";
                repeatTimer.stop();
            }
            released(arg);
        } else if (kind === "connected") {
            padCount += 1;
            padName = arg;
        } else if (kind === "disconnected") {
            padCount = Math.max(0, padCount - 1);
        }
    }

    Timer {
        id: homeHold
        interval: 450
        onTriggered: controller.pressed("recents", false)
    }

    Timer {
        id: repeatTimer
        repeat: true
        onTriggered: {
            interval = 90;
            if (controller.held !== "")
                controller.pressed(controller.held, true);
        }
    }

    Process {
        id: helper
        command: ["/usr/local/bin/pocket-input"]
        running: true
        stdout: SplitParser {
            onRead: data => controller.handle(data.trim())
        }
        stderr: SplitParser {
            onRead: data => console.warn(`pocket-input: ${data}`)
        }
        onExited: (exitCode, exitStatus) => {
            controller.padCount = 0;
            controller.held = "";
            repeatTimer.stop();
            restartTimer.start();
        }
    }

    // The Back button as a key, from Hyprland (see the top of this file)
    IpcHandler {
        target: "controller"

        function back(): void {
            controller.active = true;
            controller.pressed("back", false);
            controller.released("back");
        }
    }

    // If the helper is missing or crashes, try again every few seconds.
    Timer {
        id: restartTimer
        interval: 5000
        onTriggered: helper.running = true
    }
}
