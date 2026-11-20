import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"

Rectangle {
    id: root
    implicitHeight: 26
    implicitWidth: tempRow.implicitWidth + 14
    radius: 13
    color: (tempHover.containsMouse || PopupManager.isPopupOpen("cpu")) ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

    Behavior on color { ColorAnimation { duration: 150 } }

    Process {
        id: btopProc
        command: ["kitty", "-e", "btop"]
    }

    Process {
        id: wlCopyProc
    }

    SystemMonitor {
        id: sysMon
    }

    RowLayout {
        id: tempRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: "󰔏"
            font.family: "Symbols Nerd Font"
            font.pixelSize: 13
            color: sysMon.tempC >= 75 ? Colors.colError : Colors.colPrimary
        }

        Text {
            text: (sysMon.tempC > 0 ? sysMon.tempC + "°C" : "48°C")
            font.family: "Geist"
            font.pixelSize: 12
            font.bold: true
            color: Colors.colText
        }
    }

    MouseArea {
        id: tempHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: PopupManager.openPopup("cpu")
    }

    BarPopup {
        id: sysPopup
        name: "cpu"
        target: root
        bodyWidth: 320
        bodyHeight: telemetry.implicitHeight + 36

        ColumnLayout {
            id: telemetry
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16

            RowLayout {
                Layout.fillWidth: true

                ColumnLayout {
                    spacing: 1

                    Text {
                        text: "System"
                        font.family: "Geist"
                        font.pixelSize: 15
                        font.bold: true
                        color: Colors.colText
                    }

                    Text {
                        text: sysMon.cpuModel
                        font.family: "Geist"
                        font.pixelSize: 11
                        font.bold: true
                        color: Colors.colTextMuted
                    }
                }

                Item { Layout.fillWidth: true }

                CircleButton {
                    implicitWidth: 32
                    glyph: "󰓅"
                    glyphSize: 14
                    onActivated: {
                        btopProc.running = true
                        PopupManager.closeAll()
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                spacing: 14

                StatRing {
                    Layout.fillWidth: true
                    value: sysMon.cpuUsage
                    label: "CPU"
                    detail: sysMon.tempC > 0 ? sysMon.tempC + "°C" : ""
                    tint: sysMon.tempC >= 75 ? Colors.colError : Colors.colPrimary
                }

                StatRing {
                    Layout.fillWidth: true
                    value: sysMon.memUsage
                    label: "Memory"
                    detail: sysMon.memStr.split(" / ")[0]
                    tint: Colors.colSecondary
                }

                StatRing {
                    Layout.fillWidth: true
                    value: sysMon.gpuUsage
                    label: "GPU"
                    detail: sysMon.gpuTemp > 0 ? sysMon.gpuTemp + "°C" : "Idle"
                    tint: Colors.colPrimary
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 7

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        text: "Disk"
                        font.family: "Geist"
                        font.pixelSize: 12
                        font.bold: true
                        color: Colors.colTextMuted
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: sysMon.diskDetailStr + "  ·  " + sysMon.diskUsageStr
                        font.family: "Geist"
                        font.pixelSize: 12
                        font.bold: true
                        color: Colors.colText
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 6
                    radius: 3
                    color: Qt.rgba(1, 1, 1, 0.07)

                    Rectangle {
                        height: parent.height
                        radius: 3
                        color: Colors.colOutline
                        width: Math.max(6, (sysMon.diskUsagePct / 100) * parent.width)

                        Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.OutCubic } }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: 8
                rowSpacing: 8

                InfoChip {
                    Layout.fillWidth: true
                    glyph: "󰈐"
                    label: "CPU fan"
                    value: sysMon.cpuFanRpm > 0 ? sysMon.cpuFanRpm + " rpm" : "Quiet"
                }

                InfoChip {
                    Layout.fillWidth: true
                    glyph: "󰈐"
                    label: "GPU fan"
                    value: sysMon.gpuFanRpm > 0 ? sysMon.gpuFanRpm + " rpm" : "Quiet"
                }

                InfoChip {
                    Layout.fillWidth: true
                    glyph: "󰍛"
                    label: "VRAM"
                    value: sysMon.gpuMemStr
                }

                InfoChip {
                    Layout.fillWidth: true
                    glyph: "󱐋"
                    label: "GPU power"
                    value: sysMon.gpuPower.toFixed(1) + " W"
                }

                InfoChip {
                    id: ipChip
                    property bool copied: false

                    Layout.fillWidth: true
                    Layout.columnSpan: 2
                    interactive: true
                    glyph: copied ? "󰄬" : "󰩟"
                    label: copied ? "Copied" : "IP address"
                    value: sysMon.localIp
                    tint: copied ? "#50fa7b" : Colors.colPrimary
                    onActivated: {
                        wlCopyProc.command = ["wl-copy", "" + sysMon.localIp]
                        wlCopyProc.running = true
                        copied = true
                        copyTimer.restart()
                    }

                    Timer {
                        id: copyTimer
                        interval: 1800
                        onTriggered: ipChip.copied = false
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: sysMon.uptimeStr
                font.family: "Geist"
                font.pixelSize: 11
                font.bold: true
                color: Colors.colTextMuted
            }
        }
    }
}
