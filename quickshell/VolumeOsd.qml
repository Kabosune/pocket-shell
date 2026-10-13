import QtQuick
import Quickshell.Services.Pipewire

// On-screen volume level. Appears when the volume changes (hardware
// buttons, Quick settings or another app) and fades after a moment.
Item {
    id: osd

    property bool showing: false
    property bool primed: false

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property real volume: ready ? sink.audio.volume : 0
    readonly property bool muted: ready && sink.audio.muted

    function poke() {
        if (!primed || !ready)
            return;
        showing = true;
        hideTimer.restart();
        if (!muted)
            Sfx.play("move", 0);
    }

    onVolumeChanged: poke()
    onMutedChanged: poke()

    PwObjectTracker {
        objects: [osd.sink]
    }

    // Don't pop up for the values read at start-up
    Timer {
        interval: 2000
        running: true
        onTriggered: osd.primed = true
    }

    Timer {
        id: hideTimer
        interval: 1400
        onTriggered: osd.showing = false
    }

    Surface {
        anchors.fill: parent
        radius: Theme.rPill > 20 ? height / 2 : Theme.rCard
        color: Theme.surfaceStrong

        Row {
            anchors.centerIn: parent
            spacing: 14

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                glyph: osd.muted ? Icons.volumeOff : Icons.volume
                size: 24
                color: Theme.textStrong
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 160
                height: Theme.bevel ? 12 : 8
                radius: Theme.bevel ? Theme.rKey : height / 2
                color: Theme.chip

                Rectangle {
                    width: parent.width * (osd.muted ? 0 : Math.max(0, Math.min(1, osd.volume)))
                    height: parent.height
                    radius: parent.radius
                    color: Theme.accent
                    Behavior on width { NumberAnimation { duration: 80 } }
                }
            }

            DisplayText {
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                horizontalAlignment: Text.AlignRight
                text: osd.muted ? "Mute" : `${Math.round(osd.volume * 100)}`
                color: Theme.textStrong
                weight: Font.Bold
                size: 16
            }
        }
    }
}
