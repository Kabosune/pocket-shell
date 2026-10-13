import QtQuick
import Quickshell.Services.Pipewire

// Volume row for Quick settings, on PipeWire's default output.
// Tap the speaker (or press A) to mute.
SettingRow {
    id: volumeRow

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool ready: sink !== null && sink.audio !== null
    readonly property bool muted: ready && sink.audio.muted

    function setVolume(v) {
        if (!ready)
            return;
        sink.audio.volume = Math.max(0, Math.min(1, v));
        if (sink.audio.muted && v > 0)
            sink.audio.muted = false;
    }

    function step(delta) {
        if (ready)
            setVolume(sink.audio.volume + delta);
    }

    function toggleMute() {
        if (!ready)
            return;
        sink.audio.muted = !sink.audio.muted;
        Sfx.play(sink.audio.muted ? "toggle-off" : "toggle-on", 2);
    }

    label: "Volume"
    glyph: muted ? Icons.volumeOff : Icons.volume
    value: ready ? sink.audio.volume : 0
    note: !ready ? "No audio output" : muted ? "Muted" : ""
    usable: ready
    onMoved: v => volumeRow.setVolume(v)
    onIconTapped: volumeRow.toggleMute()

    PwObjectTracker {
        objects: [volumeRow.sink]
    }
}
