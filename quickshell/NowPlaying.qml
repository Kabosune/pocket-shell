import QtQuick
import QtQuick.Shapes
import Quickshell.Services.Mpris

// Media card driven by MPRIS. Shows the playing player first, else the first one open.
Surface {
    id: card

    readonly property var player: {
        const list = Mpris.players.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }

    // Controller focus: 0 previous, 1 play/pause, 2 next
    property int focusedIndex: -1
    // pocket-play adds a button that shows the video full screen; the
    // last button (top right corner) opens YouTube to find something.
    readonly property bool hasVideo: PocketPlay.isPlayer(player)
    readonly property int browseIndex: hasVideo ? 4 : 3
    readonly property int count: browseIndex + 1

    function activate(index) {
        if (index === browseIndex) {
            PocketPlay.browse();
            return;
        }
        const p = player;
        if (!p)
            return;
        Sfx.play("select", 0);
        if (index === 0 && p.canGoPrevious)
            p.previous();
        else if (index === 1 && p.canTogglePlaying)
            p.togglePlaying();
        else if (index === 2 && p.canGoNext)
            p.next();
        else if (index === 3 && hasVideo)
            PocketPlay.showVideo();
    }

    // Short cards (the panels and fetch layouts) drop the label and use
    // smaller controls so everything fits.
    readonly property bool compact: height < 150

    // Media button. Bevel themes draw every button as a chunky key;
    // otherwise only play/pause has a background.
    component RoundControl: Item {
        id: control
        property var glyph
        property bool big: false
        property bool available: true
        property bool focused: false
        signal activated()

        width: Theme.bevel ? (big ? 56 : 44) : card.compact ? (big ? 44 : 38) : (big ? 52 : 44)
        height: Theme.bevel ? (card.compact ? 32 : 36) : width
        opacity: !available ? 0.4 : 1

        FocusRing {
            visible: control.focused
            radius: background.radius
        }

        Chip {
            id: background
            anchors.fill: parent
            visible: control.big || Theme.bevel
            radius: Theme.bevel ? Theme.rKey : control.big ? Theme.rBtn : Theme.rPill
            active: control.big
            pressed: press.pressed
        }

        Icon {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: Theme.bevel ? -1 : 0
            glyph: control.glyph
            size: control.big ? 22 : 20
            color: control.big ? Theme.accentInk : Theme.text
        }

        MouseArea {
            id: press
            anchors.fill: parent
            enabled: control.available
            onClicked: control.activated()
        }
    }

    Row {
        anchors.fill: parent
        anchors.margins: card.compact ? 14 : 18
        spacing: card.compact ? 14 : 18

        Item {
            id: art
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(120, card.height - (card.compact ? 28 : 36))
            height: width

            // Fallback art: a small sunset in the theme's colours
            Rectangle {
                anchors.fill: parent
                radius: Theme.rArt
                color: Theme.chipFocused
                clip: true
                visible: cover.status !== Image.Ready

                Shape {
                    width: 120
                    height: 120
                    scale: art.width / 120
                    transformOrigin: Item.TopLeft
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Theme.accent
                        PathSvg { path: Icons.circle(74, 60, 20) }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Theme.chip
                        PathSvg { path: "M0 76 C 30 64, 60 68, 120 80 V120 H0 Z" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Theme.surfaceStrong
                        PathSvg { path: "M0 96 C 40 86, 80 92, 120 98 V120 H0 Z" }
                    }
                }
            }

            Image {
                id: cover
                anchors.fill: parent
                source: card.player ? card.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 240
                sourceSize.height: 240
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - art.width - parent.spacing
            spacing: card.compact ? 2 : 4

            Text {
                visible: !card.compact
                text: Theme.label("NOW PLAYING")
                color: Theme.textMuted
                font.family: Theme.bodyFont
                font.weight: Font.ExtraBold
                font.pixelSize: 11
                font.letterSpacing: 1.5
            }

            Text {
                // Leave room for the YouTube button in the corner
                width: parent.width - browse.width - 4
                elide: Text.ElideRight
                text: card.player ? (card.player.trackTitle || card.player.identity) : Theme.label("Nothing playing")
                color: Theme.textStrong
                font.family: Theme.bodyFont
                font.weight: Font.ExtraBold
                font.pixelSize: card.compact ? 17 : 20
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: card.player ? (card.player.trackArtist || card.player.identity) : Theme.label("No media app open")
                color: Theme.textMuted
                font.family: Theme.bodyFont
                font.weight: Font.DemiBold
                font.pixelSize: 13
            }

            Item { width: 1; height: card.compact ? 2 : 4 }

            Row {
                spacing: 10

                RoundControl {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: Icons.previous
                    focused: card.focusedIndex === 0
                    available: card.player !== null && card.player.canGoPrevious
                    onActivated: card.activate(0)
                }
                RoundControl {
                    anchors.verticalCenter: parent.verticalCenter
                    big: true
                    focused: card.focusedIndex === 1
                    glyph: card.player && card.player.isPlaying ? Icons.pause : Icons.play
                    available: card.player !== null && card.player.canTogglePlaying
                    onActivated: card.activate(1)
                }
                RoundControl {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: Icons.next
                    focused: card.focusedIndex === 2
                    available: card.player !== null && card.player.canGoNext
                    onActivated: card.activate(2)
                }
                RoundControl {
                    visible: card.hasVideo
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: Icons.screen
                    focused: card.focusedIndex === 3
                    onActivated: card.activate(3)
                }
            }
        }
    }

    // Find something to watch: PlasmaTube if installed, else YouTube in
    // the browser
    RoundControl {
        id: browse
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: card.compact ? 8 : 12
        anchors.rightMargin: card.compact ? 8 : 12
        glyph: Icons.video
        focused: card.focusedIndex === card.browseIndex
        onActivated: card.activate(card.browseIndex)
    }
}
