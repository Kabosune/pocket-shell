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

    component RoundControl: Rectangle {
        id: control
        property var glyph
        property bool big: false
        property bool available: true
        signal activated()

        width: big ? 52 : 44
        height: width
        radius: big ? Theme.rBtn : Theme.rPill
        color: big ? Theme.accent : "transparent"
        opacity: !available ? 0.4 : (press.pressed ? 0.75 : 1)

        Icon {
            anchors.centerIn: parent
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
        anchors.margins: 18
        spacing: 18

        Item {
            id: art
            anchors.verticalCenter: parent.verticalCenter
            width: 120
            height: 120

            // Fallback art: a small Dusk Tide scene
            Rectangle {
                anchors.fill: parent
                radius: Theme.rArt
                color: "#2F4B5A"
                clip: true
                visible: cover.status !== Image.Ready

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: Theme.accent
                        PathSvg { path: Icons.circle(74, 60, 20) }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: "#1D4144"
                        PathSvg { path: "M0 76 C 30 64, 60 68, 120 80 V120 H0 Z" }
                    }
                    ShapePath {
                        strokeColor: "transparent"
                        fillColor: "#12302F"
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
            spacing: 4

            Text {
                text: "NOW PLAYING"
                color: Theme.textMuted
                font.family: Theme.bodyFont
                font.weight: Font.ExtraBold
                font.pixelSize: 11
                font.letterSpacing: 1.5
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: card.player ? (card.player.trackTitle || card.player.identity) : "Nothing playing"
                color: Theme.textStrong
                font.family: Theme.bodyFont
                font.weight: Font.ExtraBold
                font.pixelSize: 20
            }

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: card.player ? (card.player.trackArtist || card.player.identity) : "No media app open"
                color: Theme.textMuted
                font.family: Theme.bodyFont
                font.weight: Font.DemiBold
                font.pixelSize: 13
            }

            Item { width: 1; height: 4 }

            Row {
                spacing: 10

                RoundControl {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: Icons.previous
                    available: card.player !== null && card.player.canGoPrevious
                    onActivated: card.player.previous()
                }
                RoundControl {
                    anchors.verticalCenter: parent.verticalCenter
                    big: true
                    glyph: card.player && card.player.isPlaying ? Icons.pause : Icons.play
                    available: card.player !== null && card.player.canTogglePlaying
                    onActivated: card.player.togglePlaying()
                }
                RoundControl {
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: Icons.next
                    available: card.player !== null && card.player.canGoNext
                    onActivated: card.player.next()
                }
            }
        }
    }
}
