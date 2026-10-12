import QtQuick
import QtQuick.Shapes

// Dusk Tide: the layered landscape from the concept canvas, drawn on a
// 960x540 grid and scaled to cover the screen.
Item {
    id: wall
    clip: true

    readonly property real k: Math.max(width / 960, height / 540)
    readonly property color star: "#E7F1EE"

    component Layer: ShapePath {
        property alias d: svg.path
        strokeColor: "transparent"
        PathSvg { id: svg }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.bg
    }

    Shape {
        width: 960
        height: 540
        x: (wall.width - 960 * wall.k) / 2
        y: (wall.height - 540 * wall.k) / 2
        scale: wall.k
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        Layer { fillColor: "#213448"; d: "M0 150H960V540H0Z" }
        Layer { fillColor: "#2B4457"; d: "M0 236H960V540H0Z" }
        Layer { fillColor: "#3A5A68"; d: "M0 300H960V540H0Z" }

        Layer {
            fillColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
            d: Icons.circle(390, 300, 94)
        }
        Layer { fillColor: Theme.accent; d: Icons.circle(390, 300, 58) }

        Layer {
            fillColor: "#2A5257"
            d: "M0 330 C 120 300, 240 296, 360 316 S 600 350, 720 322 S 900 292, 960 306 L960 540 L0 540 Z"
        }
        Layer {
            fillColor: "#1D4144"
            d: "M0 384 C 140 352, 260 348, 400 374 S 640 410, 780 382 S 920 356, 960 364 L960 540 L0 540 Z"
        }
        Layer {
            fillColor: "#12302F"
            d: "M0 432 C 160 406, 300 410, 460 434 S 760 462, 960 422 L960 540 L0 540 Z"
        }
        Layer {
            fillColor: "#0B2222"
            d: "M0 492 C 200 472, 420 480, 600 496 S 860 506, 960 486 L960 540 L0 540 Z"
        }

        Layer { fillColor: Qt.rgba(wall.star.r, wall.star.g, wall.star.b, 0.70); d: Icons.circle(620, 60, 1.4) }
        Layer { fillColor: Qt.rgba(wall.star.r, wall.star.g, wall.star.b, 0.50); d: Icons.circle(760, 104, 1.1) }
        Layer { fillColor: Qt.rgba(wall.star.r, wall.star.g, wall.star.b, 0.55); d: Icons.circle(300, 120, 1.2) }
        Layer { fillColor: Qt.rgba(wall.star.r, wall.star.g, wall.star.b, 0.50); d: Icons.circle(880, 40, 1) }
        Layer { fillColor: Qt.rgba(wall.star.r, wall.star.g, wall.star.b, 0.45); d: Icons.circle(470, 88, 1) }
    }
}
