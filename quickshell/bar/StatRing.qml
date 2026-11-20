import QtQuick
import QtQuick.Shapes
import "../theme"

Item {
    id: root

    property real value: 0
    property string label: ""
    property string valueText: Math.round(value) + "%"
    property string detail: ""
    property color tint: Colors.colPrimary

    readonly property real stroke: 6
    readonly property real radius: Math.min(width, height) / 2 - stroke

    implicitWidth: 86
    implicitHeight: 104

    Item {
        id: dial
        width: parent.width
        height: parent.width

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: "transparent"
                strokeColor: Qt.rgba(1, 1, 1, 0.07)
                strokeWidth: root.stroke
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: root.radius
                    radiusY: root.radius
                    startAngle: 0
                    sweepAngle: 360
                }
            }

            ShapePath {
                fillColor: "transparent"
                strokeColor: root.tint
                strokeWidth: root.stroke
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: root.radius
                    radiusY: root.radius
                    startAngle: -90
                    sweepAngle: Math.max(0.5, Math.min(100, root.value) * 3.599)

                    Behavior on sweepAngle {
                        NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.valueText
                font.family: "Geist"
                font.pixelSize: 16
                font.bold: true
                color: Colors.colText
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.detail.length > 0
                text: root.detail
                font.family: "Geist"
                font.pixelSize: 9
                font.bold: true
                color: Colors.colTextMuted
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: dial.bottom
        anchors.topMargin: 6
        text: root.label
        font.family: "Geist"
        font.pixelSize: 11
        font.bold: true
        color: Colors.colTextMuted
    }
}
