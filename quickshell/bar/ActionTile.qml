import QtQuick
import "../theme"

Rectangle {
    id: root

    property string glyph
    property string label
    property color tint: Colors.colPrimary
    property bool danger: false
    signal activated()

    implicitHeight: 76
    radius: 16
    color: area.containsMouse
        ? (danger ? Qt.rgba(tint.r, tint.g, tint.b, 0.26) : Qt.rgba(1, 1, 1, 0.12))
        : Qt.rgba(1, 1, 1, 0.055)
    scale: area.pressed ? 0.95 : 1.0

    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

    Column {
        anchors.centerIn: parent
        spacing: 7

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.glyph
            font.family: "Symbols Nerd Font"
            font.pixelSize: 20
            color: root.tint
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.label
            font.family: "Geist"
            font.pixelSize: 11
            font.bold: true
            color: root.danger ? root.tint : Colors.colText
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
