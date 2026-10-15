import QtQuick
import QtQuick.Shapes

// The theme's background. "wallpaper" in theme.json picks the kind:
//   { "type": "scene", "scene": "dusk-tide",         drawn landscape (built-in);
//     "sky": [3 colours, top to bottom], "hills": [4, back to front],
//     "star": "..." }                                  colours optional
//   { "type": "grid", "color": "...", "line": "...", "size": 16 }   graph paper
//   { "type": "dots", "color": "...", "dot": "...", "size": 24 }    dot grid
//   { "type": "rain", "color": "...", "glyph": "...", "head": "...", "size": 16,
//     "density": 1, "speed": 1 }                     falling code (animated)
//   { "type": "collage", "color": "...", "ink": "...", "seed": 7,
//     "words": ["NO SIGNAL", ...] }                  photocopied-poster collage
//   { "type": "color", "color": "..." }
// Any type can also have light rain on top:
//   "rain": { "glyph": "...", "size": 13, "density": 0.2, "speed": 0.5 }
//   { "type": "image", "file": "wallpaper.png" }    from the theme's folder
Item {
    id: wall
    clip: true

    readonly property var spec: Theme.wallpaper || ({ type: "scene" })
    readonly property string kind: spec.type || "scene"

    Rectangle {
        anchors.fill: parent
        color: ["color", "grid", "dots", "rain", "collage"].indexOf(wall.kind) >= 0 ? Theme.toColor(wall.spec.color || Theme.bg) : Theme.bg
    }

    // Graph paper
    Item {
        id: paper
        anchors.fill: parent
        visible: wall.kind === "grid"
        readonly property real step: wall.spec.size || 16
        readonly property color lineColor: Theme.toColor(wall.spec.line || "rgba(60, 80, 110, 0.07)")

        Repeater {
            model: wall.kind === "grid" ? Math.ceil(wall.width / paper.step) : 0
            Rectangle {
                required property int index
                x: index * paper.step
                width: 1
                height: wall.height
                color: paper.lineColor
            }
        }
        Repeater {
            model: wall.kind === "grid" ? Math.ceil(wall.height / paper.step) : 0
            Rectangle {
                required property int index
                y: index * paper.step
                width: wall.width
                height: 1
                color: paper.lineColor
            }
        }
    }

    // Dot grid, drawn once
    Canvas {
        id: dots
        anchors.fill: parent
        visible: wall.kind === "dots"
        readonly property real step: wall.spec.size || 24
        readonly property color dotColor: Theme.toColor(wall.spec.dot || "rgba(200, 210, 230, 0.10)")

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (wall.kind !== "dots")
                return;
            ctx.fillStyle = dotColor;
            const r = 1.2;
            for (let y = step / 2; y < height; y += step) {
                for (let x = step / 2; x < width; x += step)
                    ctx.fillRect(x - r, y - r, r * 2, r * 2);
            }
        }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onDotColorChanged: requestPaint()
        onStepChanged: requestPaint()
        onVisibleChanged: requestPaint()
    }

    // Falling code. Paused while an app or game covers the shell.
    Loader {
        anchors.fill: parent
        active: wall.kind === "rain"
        sourceComponent: RainField {
            background: Theme.toColor(wall.spec.color || Theme.bg)
            glyphColor: wall.spec.glyph ? Theme.toColor(wall.spec.glyph) : Theme.accent
            head: wall.spec.head ? Theme.toColor(wall.spec.head) : "transparent"
            size: wall.spec.size || 16
            density: wall.spec.density || 1
            speed: wall.spec.speed || 1
            running: Wm.inShell && wall.visible
        }
    }

    // Poster collage, drawn once
    Loader {
        anchors.fill: parent
        active: wall.kind === "collage"
        sourceComponent: CollageWall {
            background: Theme.toColor(wall.spec.color || Theme.bg)
            ink: Theme.toColor(wall.spec.ink || Theme.text)
            seed: wall.spec.seed || 7
            words: wall.spec.words || ["NO SIGNAL", "ctrl", "[0]", "EOF", "/dev/null", "login:"]
        }
    }

    // Picture from the theme folder
    Image {
        anchors.fill: parent
        visible: wall.kind === "image" && status === Image.Ready
        source: wall.kind === "image" && Theme.dir && wall.spec.file
            ? "file://" + Theme.dir + "/" + wall.spec.file : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }

    // Dusk Tide scene, drawn on a 960x540 grid and scaled to cover
    Loader {
        anchors.fill: parent
        active: wall.kind === "scene"
        sourceComponent: duskTide
    }

    Component {
        id: duskTide

        Item {
            id: scene

            readonly property real k: Math.max(width / 960, height / 540)
            readonly property var sky: wall.spec.sky || ["#213448", "#2B4457", "#3A5A68"]
            readonly property var hills: wall.spec.hills || ["#2A5257", "#1D4144", "#12302F", "#0B2222"]
            readonly property color star: Theme.toColor(wall.spec.star || "#E7F1EE")

            component Layer: ShapePath {
                property alias d: svg.path
                strokeColor: "transparent"
                PathSvg { id: svg }
            }

            Shape {
                width: 960
                height: 540
                x: (scene.width - 960 * scene.k) / 2
                y: (scene.height - 540 * scene.k) / 2
                scale: scene.k
                transformOrigin: Item.TopLeft
                preferredRendererType: Shape.CurveRenderer

                Layer { fillColor: Theme.toColor(scene.sky[0]); d: "M0 150H960V540H0Z" }
                Layer { fillColor: Theme.toColor(scene.sky[1]); d: "M0 236H960V540H0Z" }
                Layer { fillColor: Theme.toColor(scene.sky[2]); d: "M0 300H960V540H0Z" }

                Layer {
                    fillColor: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.10)
                    d: Icons.circle(390, 300, 94)
                }
                Layer { fillColor: Theme.accent; d: Icons.circle(390, 300, 58) }

                Layer {
                    fillColor: Theme.toColor(scene.hills[0])
                    d: "M0 330 C 120 300, 240 296, 360 316 S 600 350, 720 322 S 900 292, 960 306 L960 540 L0 540 Z"
                }
                Layer {
                    fillColor: Theme.toColor(scene.hills[1])
                    d: "M0 384 C 140 352, 260 348, 400 374 S 640 410, 780 382 S 920 356, 960 364 L960 540 L0 540 Z"
                }
                Layer {
                    fillColor: Theme.toColor(scene.hills[2])
                    d: "M0 432 C 160 406, 300 410, 460 434 S 760 462, 960 422 L960 540 L0 540 Z"
                }
                Layer {
                    fillColor: Theme.toColor(scene.hills[3])
                    d: "M0 492 C 200 472, 420 480, 600 496 S 860 506, 960 486 L960 540 L0 540 Z"
                }

                Layer { fillColor: Qt.rgba(scene.star.r, scene.star.g, scene.star.b, 0.70); d: Icons.circle(620, 60, 1.4) }
                Layer { fillColor: Qt.rgba(scene.star.r, scene.star.g, scene.star.b, 0.50); d: Icons.circle(760, 104, 1.1) }
                Layer { fillColor: Qt.rgba(scene.star.r, scene.star.g, scene.star.b, 0.55); d: Icons.circle(300, 120, 1.2) }
                Layer { fillColor: Qt.rgba(scene.star.r, scene.star.g, scene.star.b, 0.50); d: Icons.circle(880, 40, 1) }
                Layer { fillColor: Qt.rgba(scene.star.r, scene.star.g, scene.star.b, 0.45); d: Icons.circle(470, 88, 1) }
            }
        }
    }

    // Light rain over any wallpaper ("rain" inside the wallpaper spec)
    Loader {
        anchors.fill: parent
        active: wall.kind !== "rain" && wall.spec.rain !== undefined
        sourceComponent: RainField {
            fill: false
            background: Theme.toColor(wall.spec.color || Theme.bg)
            glyphColor: wall.spec.rain.glyph ? Theme.toColor(wall.spec.rain.glyph) : Theme.accent
            head: wall.spec.rain.head ? Theme.toColor(wall.spec.rain.head) : "transparent"
            size: wall.spec.rain.size || 14
            density: wall.spec.rain.density || 0.2
            speed: wall.spec.rain.speed || 0.5
            running: Wm.inShell && wall.visible
        }
    }
}
