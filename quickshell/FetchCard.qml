import QtQuick
import Quickshell
import Quickshell.Io

// System info card in the style of a terminal "fetch" tool: a little
// ASCII handheld, then os, host, kernel, uptime, packages, memory and
// battery, and a row of the theme's colours. Used by the "fetch" Home
// layout. Everything is read from /proc and /etc except the package
// count, which runs pacman now and then.
Surface {
    id: card

    // In a tile window the window draws the frame and title, so the
    // card can drop its own background and the prompt line.
    property bool framed: false
    property bool showPrompt: true
    property real margin: 16
    // Animation (the dancer) only runs while this is true
    property bool animate: true
    // The picture: the handheld drawing, the dancing chibi or the
    // headphone girl portrait. Tap it to go to the next; the choice is
    // saved.
    readonly property var logoKinds: ["handheld", "dancer", "portrait"]
    readonly property string logoKind: logoKinds.indexOf(Store.fetchLogo) >= 0 ? Store.fetchLogo
        : logoKinds.indexOf(Theme.fetchLogo) >= 0 ? Theme.fetchLogo : "handheld"
    readonly property Item logoItem: logoKind === "dancer" ? dancer : logoKind === "portrait" ? portrait : handheld

    readonly property string user: Quickshell.env("USER") || "user"
    readonly property string host: hostFile.text().trim() || "pocket"

    property string os: ""
    property string kernel: ""
    property real uptime: 0
    property string packages: ""
    property string memory: ""

    readonly property var logo: [
        "┌──────────┐",
        "│┌────────┐│",
        "││ ▓▓▓▓▓▓ ││",
        "││ ▓▓▓▓▓▓ ││",
        "│└────────┘│",
        "│ ┼   ● ●  │",
        "│      ● ● │",
        "└──────────┘"
    ]

    function formatUptime(seconds) {
        const d = Math.floor(seconds / 86400);
        const h = Math.floor((seconds % 86400) / 3600);
        const m = Math.floor((seconds % 3600) / 60);
        return (d > 0 ? `${d}d ` : "") + (h > 0 || d > 0 ? `${h}h ` : "") + `${m}m`;
    }

    function gib(kb) {
        return (kb / 1048576).toFixed(1) + "G";
    }

    function readAll() {
        osFile.reload();
        kernelFile.reload();
        uptimeFile.reload();
        memFile.reload();

        const release = osFile.text();
        const m = release.match(/^PRETTY_NAME="?([^"\n]*)"?/m);
        os = m ? m[1] : "Linux";
        kernel = kernelFile.text().trim();
        uptime = Number(uptimeFile.text().split(" ")[0]) || 0;

        const info = memFile.text();
        const total = Number((info.match(/^MemTotal:\s+(\d+)/m) || [0, 0])[1]);
        const avail = Number((info.match(/^MemAvailable:\s+(\d+)/m) || [0, 0])[1]);
        memory = total > 0 ? `${gib(total - avail)} / ${gib(total)}` : "";
    }

    readonly property var lines: [
        { key: "os", value: os },
        { key: "host", value: Device.name },
        { key: "kernel", value: kernel },
        { key: "uptime", value: formatUptime(uptime) },
        { key: "packages", value: packages },
        { key: "shell", value: "pocket-shell" },
        { key: "theme", value: Theme.name.toLowerCase() },
        { key: "display", value: Device.screen
            ? `${Math.round(Device.screen.width * Device.screen.devicePixelRatio)}x${Math.round(Device.screen.height * Device.screen.devicePixelRatio)}`
            : "" },
        { key: "memory", value: memory },
        { key: "battery", value: battery.status === Loader.Ready && battery.item.ok
            ? `${Math.round(battery.item.level * 100)}%` : "" }
    ].filter(l => l.value !== "")

    FileView { id: hostFile; path: "/etc/hostname"; blockLoading: true; printErrors: false }
    FileView { id: osFile; path: "/etc/os-release"; blockLoading: true; printErrors: false }
    FileView { id: kernelFile; path: "/proc/sys/kernel/osrelease"; blockLoading: true; printErrors: false }
    FileView { id: uptimeFile; path: "/proc/uptime"; blockLoading: true; printErrors: false }
    FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true; printErrors: false }

    // Battery through UPower, isolated like everywhere else
    Loader {
        id: battery
        visible: false
        source: "BatteryText.qml"
    }

    Process {
        id: pkgCount
        command: ["sh", "-c", "command -v pacman >/dev/null && pacman -Qq | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                const n = parseInt(text.trim());
                card.packages = n > 0 ? `${n} (pacman)` : "";
            }
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: card.readAll()
    }

    Timer {
        interval: 600000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: pkgCount.running = true
    }

    component Mono: Text {
        font.family: Theme.bodyFont
        font.pixelSize: 13
        color: Theme.text
    }

    color: framed ? "transparent" : Theme.surface
    border.width: framed ? 0 : Theme.borderWidth

    Column {
        anchors.fill: parent
        anchors.margins: card.margin
        spacing: 8

        // The "command" that printed this
        Row {
            visible: card.showPrompt
            spacing: 4

            Mono {
                id: prompt
                textFormat: Text.StyledText
                text: `<font color="${Theme.accent}">${card.user}@${card.host}</font> `
                    + `<font color="${Theme.textMuted}">~</font> `
                    + `<font color="${Theme.accent}">❯</font> pocketfetch`
            }
            Rectangle {
                visible: Theme.cursor
                anchors.verticalCenter: prompt.verticalCenter
                width: 8
                height: 15
                color: Theme.accent
                BlinkCursor on opacity {}
            }
        }

        Row {
            spacing: card.logoKind === "portrait" ? 14 : 22

            Item {
                id: logoBox
                width: card.logoItem.implicitWidth
                height: card.logoItem.implicitHeight

                Column {
                    id: handheld
                    visible: card.logoKind === "handheld"
                    spacing: 0

                    Repeater {
                        model: card.logo
                        Mono {
                            required property string modelData
                            text: modelData
                            color: Theme.accent
                            lineHeight: 1.05
                        }
                    }
                }

                AsciiDancer {
                    id: dancer
                    visible: card.logoKind === "dancer"
                    running: card.animate
                }

                AsciiPortrait {
                    id: portrait
                    visible: card.logoKind === "portrait"
                    running: card.animate
                    // As big as the card's height allows
                    size: Math.max(4.5, Math.min(7, (card.height - card.margin * 2 - (card.showPrompt ? 26 : 0)) / (rowCount * 1.32)))
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        const i = card.logoKinds.indexOf(card.logoKind);
                        Store.setFetchLogo(card.logoKinds[(i + 1) % card.logoKinds.length]);
                        Sfx.play("toggle-on", 2);
                    }
                }
            }

            Column {
                spacing: 1

                Mono {
                    textFormat: Text.StyledText
                    text: `<font color="${Theme.accent}"><b>${card.user}</b></font>@<font color="${Theme.accent}"><b>${card.host}</b></font>`
                    color: Theme.textStrong
                }
                Mono {
                    text: "─".repeat(card.user.length + card.host.length + 1)
                    color: Theme.textMuted
                }

                Repeater {
                    model: card.lines
                    Row {
                        required property var modelData

                        Mono {
                            width: 76
                            text: modelData.key
                            color: Theme.accent
                            font.weight: Font.Bold
                        }
                        Mono {
                            width: Math.max(90, Math.min(270, card.width - card.margin * 2 - logoBox.width - 22 - 80))
                            elide: Text.ElideRight
                            text: modelData.value
                        }
                    }
                }

                Item { width: 1; height: 6 }

                // Colour blocks, like every fetch screenshot ever
                Row {
                    spacing: 0
                    Repeater {
                        model: (Theme.accentChoices || []).slice(0, 8)
                        Rectangle {
                            required property string modelData
                            width: 22
                            height: 14
                            color: Theme.toColor(modelData)
                        }
                    }
                }
                Row {
                    spacing: 0
                    Repeater {
                        model: (Theme.cardColors || []).slice(0, 8)
                        Rectangle {
                            required property string modelData
                            width: 22
                            height: 14
                            color: Theme.toColor(modelData)
                        }
                    }
                }
            }
        }
    }
}
