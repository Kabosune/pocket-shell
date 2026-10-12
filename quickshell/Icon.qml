import QtQuick
import QtQuick.Shapes

// Draws a glyph from Icons.qml at any size; strokes scale with it, like SVG.
Item {
    id: icon

    property var glyph: ({})
    readonly property string strokePath: glyph && glyph.stroke ? glyph.stroke : ""
    readonly property string fillPath: glyph && glyph.fill ? glyph.fill : ""
    property color color: Theme.text
    property real size: 24
    property real weight: 1.8

    implicitWidth: size
    implicitHeight: size

    Shape {
        width: 24
        height: 24
        scale: icon.size / 24
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: icon.strokePath ? icon.color : "transparent"
            strokeWidth: icon.weight
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.strokePath || "M0 0" }
        }

        ShapePath {
            strokeColor: "transparent"
            fillColor: icon.fillPath ? icon.color : "transparent"
            PathSvg { path: icon.fillPath || "M0 0" }
        }
    }
}
