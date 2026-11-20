import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import "../theme"
import "../services"

Item {
    id: root
    implicitWidth: 340
    implicitHeight: layout.implicitHeight + 32

    property string tab: "timer"
    property int selected: 1500

    readonly property bool isTimerTab: tab === "timer"
    readonly property bool engaged: TimerService.isActive && TimerService.mode === tab
    readonly property color accent: engaged && TimerService.isFinished ? Colors.colError : Colors.colPrimary
    readonly property string readout: engaged ? TimerService.displayTime : (isTimerTab ? clockText(selected) : "00:00")
    readonly property real sweep: {
        if (!engaged) return isTimerTab ? 359.9 : 0
        if (isTimerTab) return TimerService.durationSec > 0 ? 359.9 * TimerService.remainingSec / TimerService.durationSec : 0
        return 359.9 * (TimerService.elapsedSec % 60) / 60
    }
    readonly property string caption: {
        if (!engaged) return isTimerTab ? "Ready" : "Stopped"
        if (TimerService.isFinished) return "Time's up"
        return TimerService.isRunning ? "Running" : "Paused"
    }

    function clockText(total) {
        const pad = n => (n < 10 ? "0" + n : "" + n)
        const h = Math.floor(total / 3600)
        const m = Math.floor((total % 3600) / 60)
        const s = total % 60
        return h > 0 ? pad(h) + ":" + pad(m) + ":" + pad(s) : pad(m) + ":" + pad(s)
    }

    function syncTab() {
        if (TimerService.isActive) tab = TimerService.mode
    }

    function primaryAction() {
        if (engaged) TimerService.togglePause()
        else if (isTimerTab) TimerService.startTimer(selected)
        else TimerService.startStopwatch()
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 36
            radius: 18
            color: Qt.rgba(1, 1, 1, 0.06)

            Rectangle {
                width: parent.width / 2 - 4
                height: parent.height - 8
                y: 4
                x: root.isTimerTab ? 4 : parent.width / 2
                radius: 14
                color: Qt.rgba(Colors.colPrimary.r, Colors.colPrimary.g, Colors.colPrimary.b, 0.2)

                Behavior on x { NumberAnimation { duration: 280; easing.type: Easing.OutQuint } }
            }

            Row {
                anchors.fill: parent

                Repeater {
                    model: [
                        { key: "timer", label: "Timer", glyph: "󱎫" },
                        { key: "stopwatch", label: "Stopwatch", glyph: "󱫌" }
                    ]

                    delegate: Item {
                        required property var modelData
                        width: parent.width / 2
                        height: parent.height

                        Row {
                            anchors.centerIn: parent
                            spacing: 7

                            Text {
                                text: modelData.glyph
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 13
                                color: root.tab === modelData.key ? Colors.colPrimary : Colors.colTextMuted
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }

                            Text {
                                text: modelData.label
                                font.family: "Geist"
                                font.pixelSize: 12
                                font.bold: true
                                color: root.tab === modelData.key ? Colors.colText : Colors.colTextMuted
                                anchors.verticalCenter: parent.verticalCenter
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.tab = modelData.key
                        }
                    }
                }
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 172
            Layout.preferredHeight: 172

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: Qt.rgba(1, 1, 1, 0.07)
                    strokeWidth: 7
                    capStyle: ShapePath.RoundCap

                    PathAngleArc {
                        centerX: 86
                        centerY: 86
                        radiusX: 80
                        radiusY: 80
                        startAngle: 0
                        sweepAngle: 360
                    }
                }

                ShapePath {
                    fillColor: "transparent"
                    strokeColor: root.engaged ? root.accent : Qt.rgba(Colors.colPrimary.r, Colors.colPrimary.g, Colors.colPrimary.b, 0.28)
                    strokeWidth: 7
                    capStyle: ShapePath.RoundCap

                    Behavior on strokeColor { ColorAnimation { duration: 240 } }

                    PathAngleArc {
                        centerX: 86
                        centerY: 86
                        radiusX: 80
                        radiusY: 80
                        startAngle: -90
                        sweepAngle: root.sweep

                        Behavior on sweepAngle {
                            enabled: root.isTimerTab
                            NumberAnimation { duration: 700; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            Column {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.readout
                    font.family: "Geist"
                    font.pixelSize: root.readout.length > 5 ? 32 : 40
                    font.bold: true
                    color: root.engaged ? Colors.colText : Colors.colTextMuted

                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.caption
                    font.family: "Geist"
                    font.pixelSize: 11
                    font.bold: true
                    color: root.engaged ? root.accent : Colors.colTextMuted
                    opacity: 0.85

                    Behavior on color { ColorAnimation { duration: 200 } }
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 16

            CircleButton {
                glyph: "󰜉"
                opacity: root.engaged ? 1 : 0.4
                onActivated: if (root.engaged) TimerService.reset()
            }

            CircleButton {
                filled: true
                tint: root.accent
                glyph: root.engaged && TimerService.isRunning ? "󰏤" : "󰐊"
                glyphSize: 20
                onActivated: root.primaryAction()
            }

            CircleButton {
                glyph: "+1m"
                glyphSize: 12
                opacity: root.engaged && root.isTimerTab ? 1 : 0.4
                onActivated: if (root.engaged && root.isTimerTab) TimerService.adjustTime(60)
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            visible: root.isTimerTab
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: [
                        { label: "5m", sec: 300 },
                        { label: "10m", sec: 600 },
                        { label: "15m", sec: 900 },
                        { label: "25m", sec: 1500 },
                        { label: "45m", sec: 2700 }
                    ]

                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool current: root.engaged ? TimerService.durationSec === modelData.sec : root.selected === modelData.sec

                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        radius: 16
                        color: current
                            ? Qt.rgba(Colors.colPrimary.r, Colors.colPrimary.g, Colors.colPrimary.b, 0.2)
                            : (chipArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05))

                        Behavior on color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            font.family: "Geist"
                            font.pixelSize: 12
                            font.bold: true
                            color: chip.current ? Colors.colPrimary : Colors.colText
                        }

                        MouseArea {
                            id: chipArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.selected = modelData.sec
                                TimerService.startTimer(modelData.sec)
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 19
                color: Qt.rgba(1, 1, 1, 0.05)
                border.width: 1
                border.color: inputField.activeFocus ? Colors.colPrimary : "transparent"

                Behavior on border.color { ColorAnimation { duration: 160 } }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onClicked: inputField.forceActiveFocus()
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 6
                    spacing: 8

                    TextInput {
                        id: inputField
                        Layout.fillWidth: true
                        font.family: "Geist"
                        font.pixelSize: 13
                        color: Colors.colText
                        clip: true
                        selectByMouse: true

                        Text {
                            anchors.fill: parent
                            visible: !inputField.text && !inputField.inputMethodComposing
                            text: "Custom  ·  25m, 1h30m, 45s"
                            color: Qt.rgba(1, 1, 1, 0.35)
                            font.family: "Geist"
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                        }

                        onAccepted: {
                            if (TimerService.parseAndStart(text)) text = ""
                        }
                    }

                    Rectangle {
                        Layout.preferredWidth: 28
                        Layout.preferredHeight: 28
                        radius: 14
                        opacity: inputField.text.length > 0 ? 1 : 0
                        color: goArea.containsMouse ? Colors.colPrimary : Qt.rgba(Colors.colPrimary.r, Colors.colPrimary.g, Colors.colPrimary.b, 0.22)

                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        Behavior on color { ColorAnimation { duration: 140 } }

                        Text {
                            anchors.centerIn: parent
                            text: "󰁔"
                            font.family: "Symbols Nerd Font"
                            font.pixelSize: 13
                            color: goArea.containsMouse ? Colors.colOnPrimary : Colors.colPrimary
                        }

                        MouseArea {
                            id: goArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (TimerService.parseAndStart(inputField.text)) inputField.text = ""
                            }
                        }
                    }
                }
            }
        }
    }
}
