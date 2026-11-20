import QtQuick
import "../theme"

Rectangle {
    id: root

    property string glyph
    property string label
    property string value
    property color tint: Colors.colPrimary
    property bool interactive: false
    signal activated()

    implicitHeight: 40
    radius: 14
    color: (interactive && area.containsMouse) ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.055)

    Behavior on color { ColorAnimation { duration: 150 } }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 12
        spacing: 9

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            font.family: "Symbols Nerd Font"
            font.pixelSize: 15
            color: root.tint
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            Text {
                text: root.label
                font.family: "Geist"
                font.pixelSize: 9
                font.bold: true
                color: Colors.colTextMuted
            }

            Text {
                text: root.value
                font.family: "Geist"
                font.pixelSize: 12
                font.bold: true
                color: Colors.colText
            }
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: root.interactive
        enabled: root.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
