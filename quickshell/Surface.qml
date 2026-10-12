import QtQuick

// The card used for every panel. Themes with "bevel" get a solid ledge
// under it, like a chunky plastic button.
Rectangle {
    id: surface

    property color ledgeColor: Theme.ledge

    color: Theme.surface
    border.color: Theme.surfaceBorder
    border.width: Theme.borderWidth
    radius: Theme.rCard

    Rectangle {
        visible: Theme.bevel
        z: -1
        x: 0
        y: 4
        width: surface.width
        height: surface.height
        radius: surface.radius
        color: surface.ledgeColor
    }
}
