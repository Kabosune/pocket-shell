import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// Screenshots: Home + R1 (Controller.qml) saves the main screen to
// ~/Pictures/Screenshots with grim, then flashes and shows a small preview.
// The window sits above apps and games, takes no input, and is only mapped
// while showing.
PanelWindow {
    id: shotWindow

    property bool showing: false
    property string savedPath: ""
    property string message: ""
    property bool failed: false

    function take() {
        if (grab.running || !Device.screen)
            return;
        grab.command = ["sh", "-c", shotWindow.script, "sh", Device.screen.name];
        grab.running = true;
    }

    // $1 = output. Prints the file it saved.
    readonly property string script: `
        command -v grim >/dev/null || exit 127
        dir=""
        command -v xdg-user-dir >/dev/null && dir="$(xdg-user-dir PICTURES 2>/dev/null)"
        [ -n "$dir" ] && [ "$dir" != "$HOME" ] || dir="$HOME/Pictures"
        dir="$dir/Screenshots"
        mkdir -p "$dir" || exit 1
        file="$dir/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png"
        grim -o "$1" "$file" && echo "$file"`

    function done(ok, path, why) {
        failed = !ok;
        savedPath = ok ? path : "";
        message = ok ? "Screenshot saved" : why;
        showing = true;
        if (ok) {
            flash.opacity = 0.7;
            flashOut.restart();
        }
        hideTimer.restart();
        Sfx.play(ok ? "notice" : "error", 2);
    }

    Connections {
        target: Controller
        function onPressed(button, repeat) {
            if (button === "screenshot")
                shotWindow.take();
        }
    }

    Process {
        id: grab
        stdout: StdioCollector {
            id: out
        }
        onExited: (exitCode, exitStatus) => {
            const path = out.text.trim();
            if (exitCode === 0 && path !== "")
                shotWindow.done(true, path, "");
            else if (exitCode === 127)
                shotWindow.done(false, "", "Screenshots need grim: sudo pacman -S grim");
            else
                shotWindow.done(false, "", "Couldn't take a screenshot");
        }
    }

    screen: Device.screen
    visible: showing
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "pocket-shell-shot"
    color: "transparent"
    mask: Region {}

    Rectangle {
        id: flash
        anchors.fill: parent
        color: "white"
        opacity: 0

        NumberAnimation {
            id: flashOut
            target: flash
            property: "opacity"
            to: 0
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    Timer {
        id: hideTimer
        interval: 2600
        onTriggered: shotWindow.showing = false
    }

    Surface {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 24
        width: row.implicitWidth + 24
        height: 64
        radius: Theme.rCard
        color: Theme.surfaceStrong

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 12

            // Preview of the saved picture
            Rectangle {
                visible: shotWindow.savedPath !== ""
                anchors.verticalCenter: parent.verticalCenter
                width: 80
                height: 45
                radius: Math.min(Theme.rArt, 4)
                color: Theme.chip
                clip: true

                Image {
                    anchors.fill: parent
                    source: shotWindow.savedPath ? "file://" + shotWindow.savedPath.split("/").map(encodeURIComponent).join("/") : ""
                    sourceSize.width: 160
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    text: Theme.label(shotWindow.message)
                    color: shotWindow.failed ? Theme.accent : Theme.textStrong
                    font.family: Theme.bodyFont
                    font.weight: Font.ExtraBold
                    font.pixelSize: 15
                }

                Text {
                    visible: shotWindow.savedPath !== ""
                    text: shotWindow.savedPath.replace(Quickshell.env("HOME") || "\\u0000", "~")
                    color: Theme.textMuted
                    font.family: Theme.bodyFont
                    font.weight: Font.DemiBold
                    font.pixelSize: 11
                }
            }
        }
    }
}
