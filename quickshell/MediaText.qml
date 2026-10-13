import QtQuick
import Quickshell.Services.Mpris

// What's playing, as one line of bar text: "▶ artist - title".
// Hidden when no media app is open. Loaded through a Loader so a missing
// MPRIS service only hides it.
Text {
    id: media

    readonly property var player: {
        const list = Mpris.players.values;
        for (let i = 0; i < list.length; i++) {
            if (list[i].isPlaying)
                return list[i];
        }
        return list.length > 0 ? list[0] : null;
    }

    visible: player !== null && (player.trackTitle || "") !== ""
    elide: Text.ElideRight
    textFormat: Text.StyledText
    text: {
        if (!player)
            return "";
        const artist = player.trackArtist ? `${player.trackArtist} - ` : "";
        const mark = player.isPlaying ? "▶" : "■";
        return `<font color="${Theme.accent}">${mark}</font> ${artist}${player.trackTitle || ""}`;
    }
    color: Theme.text
    font.family: Theme.bodyFont
    font.pixelSize: 12
}
