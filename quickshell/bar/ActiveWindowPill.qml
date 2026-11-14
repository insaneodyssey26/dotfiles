import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../theme"
import "../services"

Rectangle {
    id: root
    implicitHeight: 24
    implicitWidth: 26
    radius: 12
    color: winHover.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        anchors.centerIn: parent
        text: "󰣇"
        font.family: "Symbols Nerd Font"
        font.pixelSize: 15
        color: Colors.colPrimary
    }

    MouseArea {
        id: winHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            quickshellLauncherProc.running = true
        }
        onWheel: (wheel) => {
            if (wheel.angleDelta.y > 0) {
                Niri.focusPrevWindow()
            } else if (wheel.angleDelta.y < 0) {
                Niri.focusNextWindow()
            }
        }

        Process {
            id: quickshellLauncherProc
            command: ["quickshell", "ipc", "-p", "/home/masum/dotfiles/quickshell/shell.qml", "call", "launcher", "toggle"]
        }
    }
}
