import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"

Rectangle {
    id: root
    readonly property color powerRed: "#e63946"
    readonly property color powerRedHover: "#ff4d5e"

    implicitHeight: 26
    implicitWidth: 32
    radius: 13
    color: (pwrHover.containsMouse || PopupManager.isPopupOpen("power")) ? Qt.rgba(powerRed.r, powerRed.g, powerRed.b, 0.25) : "transparent"

    Behavior on color { ColorAnimation { duration: 150 } }

    Text {
        anchors.centerIn: parent
        text: "󰐥"
        font.family: "Symbols Nerd Font"
        font.pixelSize: 16
        color: pwrHover.containsMouse ? root.powerRedHover : root.powerRed
    }

    MouseArea {
        id: pwrHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupManager.openPopup("power")
    }

    Process {
        id: powerActionProc
    }

    function runPowerAction(cmd) {
        powerActionProc.command = cmd
        powerActionProc.running = true
        PopupManager.closeAll()
    }

    BarPopup {
        id: pwrPopup
        name: "power"
        target: root
        bodyWidth: 244
        bodyHeight: 188

        GridLayout {
            anchors.fill: parent
            anchors.margins: 14
            columns: 2
            columnSpacing: 10
            rowSpacing: 10

            ActionTile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                glyph: "󰌾"
                label: "Lock"
                onActivated: root.runPowerAction(["/home/masum/dotfiles/scripts/lock.sh"])
            }

            ActionTile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                glyph: "󰤄"
                label: "Suspend"
                onActivated: root.runPowerAction(["systemctl", "suspend"])
            }

            ActionTile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                glyph: "󰜉"
                label: "Restart"
                onActivated: root.runPowerAction(["systemctl", "reboot"])
            }

            ActionTile {
                Layout.fillWidth: true
                Layout.fillHeight: true
                glyph: "󰐥"
                label: "Power Off"
                tint: root.powerRed
                danger: true
                onActivated: root.runPowerAction(["systemctl", "poweroff"])
            }
        }
    }
}
