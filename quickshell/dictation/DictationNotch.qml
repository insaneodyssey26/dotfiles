import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../theme"
import "../bar"

PanelWindow {
    id: root

    property bool isShown: false
    property bool isStopping: false
    property bool restartQueued: false
    property string status: "idle"
    property real level: 0

    readonly property bool isBusy: status !== "listening"
    readonly property real flare: 14
    readonly property real pillWidth: 164
    readonly property real pillHeight: 36

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "aether-dictation"
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
    }
    margins.top: 38

    implicitWidth: pillWidth + flare * 2
    implicitHeight: pillHeight + 8

    color: "transparent"
    visible: root.isShown || pill.y > -pill.height + 1
    mask: Region { item: pill }

    function start() {
        if (engine.running) return
        root.isStopping = false
        root.status = "loading"
        root.level = 0
        root.isShown = true
        engine.running = true
    }

    function stop() {
        if (!engine.running || root.isStopping) return
        root.isStopping = true
        root.status = "transcribing"
        engine.signal(15)
    }

    function toggle() {
        if (!root.isShown) {
            start()
        } else if (root.isStopping) {
            root.restartQueued = !root.restartQueued
        } else {
            stop()
        }
    }

    function handle(line) {
        const split = line.indexOf(" ")
        if (split < 0) return
        const kind = line.substring(0, split)
        const value = line.substring(split + 1).trim()
        if (kind === "level") {
            root.level = parseFloat(value) || 0
        } else if (kind === "state" && !root.isStopping) {
            root.status = value
        }
    }

    Process {
        id: engine
        command: ["/home/masum/dotfiles/scripts/voice_dictation.py"]
        stdout: SplitParser {
            onRead: data => root.handle(data)
        }
        onRunningChanged: {
            if (running) return
            root.isStopping = false
            root.level = 0
            if (root.restartQueued) {
                root.restartQueued = false
                root.start()
                return
            }
            root.isShown = false
            root.status = "idle"
        }
    }

    Item {
        id: pill
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.isShown ? 0 : -height
        width: (root.isShown ? root.pillWidth : root.pillWidth * 0.55) + root.flare * 2
        height: root.pillHeight

        Behavior on y {
            NumberAnimation {
                duration: root.isShown ? 360 : 230
                easing.type: root.isShown ? Easing.OutQuint : Easing.InCubic
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: root.isShown ? 360 : 230
                easing.type: root.isShown ? Easing.OutQuint : Easing.InCubic
            }
        }

        AttachedShape {
            anchors.fill: parent
            flare: root.flare
            corner: root.pillHeight / 2
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.stop()
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: root.flare + 14
            anchors.rightMargin: root.flare + 14
            anchors.bottomMargin: 2
            opacity: Math.min(1, Math.max(0, (pill.y + pill.height) / pill.height - 0.4) / 0.6)

            DictationVisualizer {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: 5
                anchors.bottomMargin: 5
                running: root.isShown
                level: root.level
                thinking: root.isBusy
                dotColor: root.isBusy ? Qt.rgba(1, 1, 1, 0.7) : Colors.colPrimary

                Behavior on dotColor {
                    ColorAnimation { duration: 200 }
                }
            }
        }
    }
}
