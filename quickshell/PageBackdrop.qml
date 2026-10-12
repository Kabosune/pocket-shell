import QtQuick

// Dims the wallpaper behind every page except Home. Light themes can set
// "dim" to transparent.
Rectangle {
    anchors.fill: parent
    color: Theme.dim
}
