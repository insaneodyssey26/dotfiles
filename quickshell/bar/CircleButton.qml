import QtQuick
import "../theme"

Rectangle {
    id: button
    property string glyph
    property bool filled: false
    property color tint: Colors.colText
    property real glyphSize: 15
    signal activated()

    implicitWidth: filled ? 56 : 42
    implicitHeight: implicitWidth
    radius: width / 2
    color: filled
        ? (area.containsMouse ? Qt.lighter(tint, 1.12) : tint)
        : (area.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : Qt.rgba(1, 1, 1, 0.07))
    scale: area.pressed ? 0.92 : 1.0

    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

    Text {
        anchors.centerIn: parent
        text: button.glyph
        font.family: "Symbols Nerd Font"
        font.pixelSize: button.glyphSize
        color: button.filled ? Colors.colOnPrimary : Colors.colText
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.activated()
    }
}
