pragma Singleton
import QtQuick
import Quickshell

// UI sound effects.
//
// Sfx.play(name, priority): several things can ask for a sound during one
// input (a generic "select" for the A press and a specific "launch" from
// what it did); only the highest-priority request in that moment plays.
// Generic button sounds use priority 0, specific actions 1 or more.
//
// The sound pack comes from the theme ("sounds" in theme.json): a built-in
// pack name ("soft", "chip"), "./folder" inside the theme, or "none".
Singleton {
    id: sfx

    readonly property bool enabled: Store.sounds
    readonly property string folder: {
        const pack = Theme.soundPack;
        if (!pack || pack === "none")
            return "";
        if (pack.indexOf("./") === 0)
            return Theme.dir ? Theme.dir + pack.substring(1) : "";
        return Quickshell.shellPath("sounds/" + pack);
    }

    property var player: null
    property string pending: ""
    property int pendingPriority: -1

    function play(name, priority) {
        const p = priority === undefined ? 0 : priority;
        if (p > pendingPriority) {
            pending = name;
            pendingPriority = p;
        }
        Qt.callLater(flush);
    }

    function flush() {
        const name = pending;
        pending = "";
        pendingPriority = -1;
        if (name && enabled && player)
            player.play(name);
    }

    Component.onCompleted: {
        const component = Qt.createComponent("SfxPlayer.qml");
        if (component.status !== Component.Ready) {
            console.warn("Pocket Shell: no UI sounds (install qt6-multimedia to enable them)");
            return;
        }
        player = component.createObject(sfx);
        player.folder = Qt.binding(() => sfx.folder);
    }
}
