import QtQuick
import Quickshell
import Quickshell.Io

// Glance page: the device at a glance. Time and date, battery, storage,
// Wi-Fi, open apps, and media controls (left/right + A).
Item {
    id: page

    property var shell: null
    property bool current: false
    property int mediaIndex: 1

    // Storage for the home folder, from df
    property double diskSize: 0
    property double diskFree: 0

    function gb(bytes) {
        const g = bytes / 1e9;
        return g >= 100 ? `${Math.round(g)} GB` : `${g.toFixed(1)} GB`;
    }

    function handle(button) {
        switch (button) {
        case "left":
            mediaIndex = Math.max(0, mediaIndex - 1);
            return true;
        case "right":
            mediaIndex = Math.min(2, mediaIndex + 1);
            return true;
        case "a":
            if (media.item)
                media.item.activate(mediaIndex);
            return true;
        }
        return false;
    }

    onCurrentChanged: {
        if (current)
            df.running = true;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=size,avail", Quickshell.env("HOME") || "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                const parts = lines[lines.length - 1].trim().split(/\s+/);
                if (parts.length >= 2) {
                    page.diskSize = Number(parts[0]) || 0;
                    page.diskFree = Number(parts[1]) || 0;
                }
            }
        }
    }

    Component.onCompleted: df.running = true

    PageBackdrop {}

    PageTitle {
        text: "Glance"
    }

    // Time and date
    Surface {
        x: 48
        y: 116
        width: 400
        height: 196

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 24
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Row {
                Text {
                    text: Qt.formatTime(clock.date, "HH")
                    color: Theme.textStrong
                    font.family: Theme.displayFont
                    font.weight: Font.Black
                    font.pixelSize: 96
                    font.letterSpacing: -3
                }
                Text {
                    text: ":"
                    color: Theme.textMuted
                    font.family: Theme.displayFont
                    font.weight: Font.Black
                    font.pixelSize: 96
                }
                Text {
                    text: Qt.formatTime(clock.date, "mm")
                    color: Theme.accent
                    font.family: Theme.displayFont
                    font.weight: Font.Black
                    font.pixelSize: 96
                    font.letterSpacing: -3
                }
            }

            Text {
                text: Qt.formatDate(clock.date, "dddd, MMMM d")
                color: Theme.textStrong
                font.family: Theme.bodyFont
                font.weight: Font.ExtraBold
                font.pixelSize: 18
            }
        }
    }

    // Media
    Loader {
        id: media
        x: 48
        y: 328
        width: 400
        height: 156
        source: "NowPlaying.qml"
    }

    Binding {
        when: media.status === Loader.Ready
        target: media.item
        property: "focusedIndex"
        value: Controller.active && page.current ? page.mediaIndex : -1
    }

    // Small cards, 2 x 2
    Grid {
        x: 472
        y: 116
        columns: 2
        spacing: 16

        Loader {
            width: 212
            height: 176
            source: "BatteryCard.qml"
        }

        GlanceCard {
            width: 212
            height: 176
            label: "Storage"
            glyph: Icons.storage
            value: page.diskSize > 0 ? page.gb(page.diskFree) : "—"
            fill: page.diskSize > 0 ? 1 - page.diskFree / page.diskSize : -1
            detail: page.diskSize > 0 ? `free of ${page.gb(page.diskSize)}` : "Checking…"
        }

        Loader {
            width: 212
            height: 176
            source: "WifiCard.qml"
        }

        GlanceCard {
            width: 212
            height: 176
            label: "Open apps"
            glyph: Icons.apps
            value: `${Wm.apps.length}`
            detail: Wm.apps.length === 0 ? "Nothing running" : "Hold Home to see them"
        }
    }

    HintBar {
        anchors.right: parent.right
        anchors.rightMargin: 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        items: [
            { key: "A", round: true, text: "Media" },
            { key: "B", round: true, text: "Home" }
        ]
    }
}
