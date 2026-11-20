import QtQuick
import QtQuick.Shapes

Shape {
    id: root

    property real flare: 16
    property real corner: 18
    property color fillColor: "#000000"

    readonly property real rise: Math.min(flare, height / 2)
    readonly property real round: Math.min(corner, Math.max(0, height - rise))

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: root.fillColor
        strokeColor: "transparent"
        strokeWidth: -1
        startX: 0
        startY: 0

        PathArc {
            x: root.flare
            y: root.rise
            radiusX: root.flare
            radiusY: root.rise
            direction: PathArc.Clockwise
        }
        PathLine { x: root.flare; y: root.height - root.round }
        PathArc {
            x: root.flare + root.round
            y: root.height
            radiusX: root.round
            radiusY: root.round
            direction: PathArc.Counterclockwise
        }
        PathLine { x: root.width - root.flare - root.round; y: root.height }
        PathArc {
            x: root.width - root.flare
            y: root.height - root.round
            radiusX: root.round
            radiusY: root.round
            direction: PathArc.Counterclockwise
        }
        PathLine { x: root.width - root.flare; y: root.rise }
        PathArc {
            x: root.width
            y: 0
            radiusX: root.flare
            radiusY: root.rise
            direction: PathArc.Clockwise
        }
        PathLine { x: 0; y: 0 }
    }
}
