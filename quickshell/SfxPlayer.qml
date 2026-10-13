import QtQuick
import QtQml.Models
import QtMultimedia

// Plays the UI sounds. Created by Sfx.qml at runtime, so if QtMultimedia
// isn't installed the shell still works, just silently.
Item {
    id: player

    property string folder: ""
    property real volume: 0.7

    readonly property var names: ["move", "select", "back", "page", "open", "toggle-on",
        "toggle-off", "launch", "error", "notice", "theme", "boot"]

    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function play(name) {
        const i = names.indexOf(name);
        if (i < 0 || !folder)
            return;
        const fx = effects.objectAt(i);
        if (fx && fx.status === SoundEffect.Ready) {
            fx.stop();
            fx.play();
        }
    }

    Instantiator {
        id: effects
        model: player.names
        delegate: SoundEffect {
            required property string modelData
            source: player.folder ? player.fileUrl(`${player.folder}/${modelData}.wav`) : ""
            volume: player.volume
        }
    }
}
