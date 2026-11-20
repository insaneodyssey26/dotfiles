import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"

Rectangle {
    id: root
    implicitHeight: 26
    implicitWidth: 28
    radius: 13
    color: kbdHover.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

    Behavior on color { ColorAnimation { duration: 150 } }

    property string layoutCode: "US"

    readonly property string layoutName: Niri.keyboardLayoutName

    onLayoutNameChanged: {
        if (layoutName.includes("US")) layoutCode = "US"
        else if (layoutName.includes("IN")) layoutCode = "IN"
        else if (layoutName.includes("Bengali") || layoutName.includes("Bangla")) layoutCode = "BN"
        else if (layoutName.length >= 2) layoutCode = layoutName.substring(0, 2).toUpperCase()
    }

    Text {
        anchors.centerIn: parent
        text: root.layoutCode
        font.family: "Geist"
        font.pixelSize: 12
        font.bold: true
        color: kbdHover.containsMouse ? Colors.colPrimary : Colors.colText
    }

    MouseArea {
        id: kbdHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                switchLayoutProc.running = true
            } else {
                toggleProc.running = true
            }
        }
    }

    Process {
        id: switchLayoutProc
        command: ["niri", "msg", "action", "switch-layout", "next"]
    }

    Process {
        id: toggleProc
        command: ["/home/masum/dotfiles/quickshell/scripts/toggle-keyboard.sh"]
    }
}
