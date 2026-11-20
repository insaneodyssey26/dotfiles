import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../theme"
import "../services"

Rectangle {
    id: root
    implicitHeight: 26
    implicitWidth: volRow.implicitWidth + 14
    radius: 13
    color: (volHover.containsMouse || PopupManager.isPopupOpen("volume")) ? Qt.rgba(1, 1, 1, 0.12) : "transparent"

    property real vol: 40.0
    property bool isMuted: false
    property var audioSinks: []
    property var audioSources: []
    property real micVol: 50.0
    property bool isMicMuted: false
    property bool outputExpanded: false
    property bool inputExpanded: false

    function refreshLevels() {
        getVolProcess.running = true
        getMicVolProcess.running = true
    }

    function refreshAll() {
        refreshLevels()
        getDevicesProcess.running = true
    }

    Component.onCompleted: refreshLevels()

    Timer {
        id: settleTimer
        interval: 150
        onTriggered: {
            root.refreshLevels()
            if (volPopup.open) getDevicesProcess.running = true
        }
    }

    Connections {
        target: AudioSignalHub
        function onVolumeChanged() {
            root.refreshAll()
        }
    }

    Process {
        id: pactlSubProc
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                if (/on (sink|source) #|on server/.test(data)) settleTimer.restart()
            }
        }
    }

    Process {
        id: getVolProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                let str = text.trim()
                root.isMuted = str.includes("[MUTED]")
                let match = str.match(/Volume:\s+([0-9.]+)/)
                if (match && match[1]) {
                    root.vol = Math.round(parseFloat(match[1]) * 100)
                }
            }
        }
    }

    Process {
        id: getMicVolProcess
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector {
            onStreamFinished: {
                let str = text.trim()
                root.isMicMuted = str.includes("[MUTED]")
                let match = str.match(/Volume:\s+([0-9.]+)/)
                if (match && match[1]) {
                    root.micVol = Math.round(parseFloat(match[1]) * 100)
                }
            }
        }
    }

    Process {
        id: getDevicesProcess
        command: ["/home/masum/dotfiles/scripts/audio-devices.py"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let parsed = JSON.parse(text.trim())
                    if (parsed) {
                        if (Array.isArray(parsed.sinks)) root.audioSinks = parsed.sinks
                        if (Array.isArray(parsed.sources)) root.audioSources = parsed.sources
                    }
                } catch(e) {}
            }
        }
    }

    Process { id: setVolProc }
    Process { id: setMicVolProc }
    Process {
        id: setMuteProc
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]
        onExited: root.refreshAll()
    }
    Process {
        id: setMicMuteProc
        command: ["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]
        onExited: root.refreshAll()
    }
    Process {
        id: setSinkPortProc
        onExited: root.refreshAll()
    }
    Process {
        id: setSourcePortProc
        onExited: root.refreshAll()
    }
    Process {
        id: pavuProc
        command: ["pavucontrol"]
    }

    function setVolumePercent(val) {
        let clamped = Math.max(0, Math.min(100, Math.round(val)))
        root.vol = clamped
        root.isMuted = false
        setVolProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (clamped / 100).toFixed(2)]
        setVolProc.running = true
    }

    function setMicVolumePercent(val) {
        let clamped = Math.max(0, Math.min(100, Math.round(val)))
        root.micVol = clamped
        root.isMicMuted = false
        setMicVolProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SOURCE@", (clamped / 100).toFixed(2)]
        setMicVolProc.running = true
    }

    function toggleMute() {
        root.isMuted = !root.isMuted
        setMuteProc.running = true
    }

    function toggleMicMute() {
        root.isMicMuted = !root.isMicMuted
        setMicMuteProc.running = true
    }

    function setSinkPort(target, port) {
        setSinkPortProc.command = ["pactl", "set-sink-port", target, port]
        setSinkPortProc.running = true
    }

    function setSourcePort(target, port) {
        setSourcePortProc.command = ["pactl", "set-source-port", target, port]
        setSourcePortProc.running = true
    }

    RowLayout {
        id: volRow
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: root.isMuted ? "󰝟" : (root.vol > 50 ? "󰕾" : (root.vol > 0 ? "󰖀" : "󰕿"))
            font.family: "Symbols Nerd Font"
            font.pixelSize: 13
            color: root.isMuted ? Colors.colError : Colors.colPrimary
        }

        Text {
            text: root.isMuted ? "Muted" : (Math.round(root.vol) + "%")
            font.family: "Geist"
            font.pixelSize: 12
            font.bold: true
            color: Colors.colText
        }
    }

    MouseArea {
        id: volHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            root.refreshAll()
            PopupManager.openPopup("volume")
        }
        onWheel: (wheel) => {
            let delta = wheel.angleDelta.y > 0 ? 5 : -5
            root.setVolumePercent(root.vol + delta)
        }
    }

    BarPopup {
        id: volPopup
        name: "volume"
        target: root
        bodyWidth: 330
        bodyHeight: mainCol.implicitHeight + 28
        onOpened: root.refreshAll()

        ColumnLayout {
            id: mainCol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 26
                Layout.leftMargin: 4
                Layout.rightMargin: 4
                spacing: 8

                Text {
                    text: "Audio Control"
                    font.family: "Geist"
                    font.pixelSize: 14
                    font.bold: true
                    color: Colors.colText
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 26
                    height: 26
                    radius: 13
                    color: pavuHover.containsMouse ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08)
                    Text {
                        anchors.centerIn: parent
                        text: "󰓃"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 13
                        color: Colors.colPrimary
                    }
                    MouseArea {
                        id: pavuHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            pavuProc.running = true
                            PopupManager.closeAll()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: outVolCol.implicitHeight + 20
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1

                ColumnLayout {
                    id: outVolCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: muteHover.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                            Text {
                                anchors.centerIn: parent
                                text: root.isMuted ? "󰝟" : "󰕾"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 13
                                color: root.isMuted ? Colors.colError : Colors.colPrimary
                            }
                            MouseArea {
                                id: muteHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleMute()
                            }
                        }

                        Text {
                            text: "Speaker Volume"
                            font.family: "Geist"
                            font.pixelSize: 12
                            font.bold: true
                            color: Colors.colText
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.isMuted ? "Muted" : (Math.round(root.vol) + "%")
                            font.family: "Geist"
                            font.pixelSize: 12
                            font.bold: true
                            color: root.isMuted ? Colors.colError : Colors.colPrimary
                        }
                    }

                    Rectangle {
                        id: sliderTrack
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        radius: 9
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            height: parent.height
                            radius: 9
                            color: root.isMuted ? Colors.colError : Colors.colPrimary
                            width: Math.min(sliderTrack.width, Math.max(0, (root.vol / 100) * sliderTrack.width))
                        }

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(sliderTrack.width - 14, (root.vol / 100) * sliderTrack.width - 7))
                            color: "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onClicked: (mouse) => {
                                let ratio = Math.max(0, Math.min(1, mouse.x / sliderTrack.width))
                                root.setVolumePercent(ratio * 100)
                            }
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    let ratio = Math.max(0, Math.min(1, mouse.x / sliderTrack.width))
                                    root.setVolumePercent(ratio * 100)
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: inMicCol.implicitHeight + 20
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1

                ColumnLayout {
                    id: inMicCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: micMuteHover.containsMouse ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.08)
                            Text {
                                anchors.centerIn: parent
                                text: root.isMicMuted ? "󰍭" : "󰍬"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 13
                                color: root.isMicMuted ? Colors.colError : Colors.colPrimary
                            }
                            MouseArea {
                                id: micMuteHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.toggleMicMute()
                            }
                        }

                        Text {
                            text: "Microphone Gain"
                            font.family: "Geist"
                            font.pixelSize: 12
                            font.bold: true
                            color: Colors.colText
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            text: root.isMicMuted ? "Muted" : (Math.round(root.micVol) + "%")
                            font.family: "Geist"
                            font.pixelSize: 12
                            font.bold: true
                            color: root.isMicMuted ? Colors.colError : Colors.colPrimary
                        }
                    }

                    Rectangle {
                        id: micSliderTrack
                        Layout.fillWidth: true
                        Layout.preferredHeight: 18
                        radius: 9
                        color: Qt.rgba(1, 1, 1, 0.08)

                        Rectangle {
                            height: parent.height
                            radius: 9
                            color: root.isMicMuted ? Colors.colError : Colors.colPrimary
                            width: Math.min(micSliderTrack.width, Math.max(0, (root.micVol / 100) * micSliderTrack.width))
                        }

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 7
                            anchors.verticalCenter: parent.verticalCenter
                            x: Math.max(0, Math.min(micSliderTrack.width - 14, (root.micVol / 100) * micSliderTrack.width - 7))
                            color: "#ffffff"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            preventStealing: true
                            onClicked: (mouse) => {
                                let ratio = Math.max(0, Math.min(1, mouse.x / micSliderTrack.width))
                                root.setMicVolumePercent(ratio * 100)
                            }
                            onPositionChanged: (mouse) => {
                                if (pressed) {
                                    let ratio = Math.max(0, Math.min(1, mouse.x / micSliderTrack.width))
                                    root.setMicVolumePercent(ratio * 100)
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: outHeaderRow.implicitHeight + (root.outputExpanded ? (outAccordionContent.implicitHeight + 12) : 0) + 16
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                clip: true

                Behavior on implicitHeight {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Item {
                        id: outHeaderRowWrap
                        Layout.fillWidth: true
                        implicitHeight: outHeaderRow.implicitHeight

                        RowLayout {
                            id: outHeaderRow
                            anchors.fill: parent
                            spacing: 8

                            Text {
                                text: "󰓃"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 13
                                color: Colors.colPrimary
                            }

                            Text {
                                text: "Output Route"
                                font.family: "Geist"
                                font.pixelSize: 12
                                font.bold: true
                                color: Colors.colText
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: {
                                    for (let i = 0; i < root.audioSinks.length; i++) {
                                        if (root.audioSinks[i].active) return root.audioSinks[i].displayName
                                    }
                                    return "Default"
                                }
                                font.family: "Geist"
                                font.pixelSize: 11
                                color: Colors.colTextMuted
                                visible: !root.outputExpanded
                            }

                            Text {
                                text: root.outputExpanded ? "󰅃" : "󰅀"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 12
                                color: Colors.colTextMuted
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.outputExpanded = !root.outputExpanded
                        }
                    }

                    ColumnLayout {
                        id: outAccordionContent
                        Layout.fillWidth: true
                        spacing: 4
                        opacity: root.outputExpanded ? 1.0 : 0.0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                        }

                        Repeater {
                            model: root.audioSinks

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                radius: 7
                                color: modelData.active ? Qt.rgba(Colors.colPrimary.r, Colors.colPrimary.g, Colors.colPrimary.b, 0.16)
                                                        : (sinkHover.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
                                border.color: modelData.active ? Colors.colPrimary : "transparent"
                                border.width: modelData.active ? 1 : 0

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Text {
                                        text: modelData.icon || "󰕾"
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 13
                                        color: modelData.active ? Colors.colPrimary : Colors.colTextMuted
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.displayName
                                        font.family: "Geist"
                                        font.pixelSize: 12
                                        font.bold: modelData.active
                                        color: modelData.active ? Colors.colPrimary : Colors.colText
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: modelData.active
                                        text: ""
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 12
                                        color: Colors.colPrimary
                                    }
                                }

                                MouseArea {
                                    id: sinkHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.setSinkPort(modelData.target, modelData.port)
                                        root.outputExpanded = false
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: inHeaderRow.implicitHeight + (root.inputExpanded ? (inAccordionContent.implicitHeight + 12) : 0) + 16
                radius: 12
                color: Qt.rgba(1, 1, 1, 0.04)
                border.color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                clip: true

                Behavior on implicitHeight {
                    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    Item {
                        id: inHeaderRowWrap
                        Layout.fillWidth: true
                        implicitHeight: inHeaderRow.implicitHeight

                        RowLayout {
                            id: inHeaderRow
                            anchors.fill: parent
                            spacing: 8

                            Text {
                                text: "󰍬"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 13
                                color: Colors.colPrimary
                            }

                            Text {
                                text: "Input Route"
                                font.family: "Geist"
                                font.pixelSize: 12
                                font.bold: true
                                color: Colors.colText
                            }

                            Item { Layout.fillWidth: true }

                            Text {
                                text: {
                                    for (let i = 0; i < root.audioSources.length; i++) {
                                        if (root.audioSources[i].active) return root.audioSources[i].displayName
                                    }
                                    return "Default"
                                }
                                font.family: "Geist"
                                font.pixelSize: 11
                                color: Colors.colTextMuted
                                visible: !root.inputExpanded
                            }

                            Text {
                                text: root.inputExpanded ? "󰅃" : "󰅀"
                                font.family: "Symbols Nerd Font"
                                font.pixelSize: 12
                                color: Colors.colTextMuted
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.inputExpanded = !root.inputExpanded
                        }
                    }

                    ColumnLayout {
                        id: inAccordionContent
                        Layout.fillWidth: true
                        spacing: 4
                        opacity: root.inputExpanded ? 1.0 : 0.0
                        visible: opacity > 0

                        Behavior on opacity {
                            NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
                        }

                        Repeater {
                            model: root.audioSources

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 32
                                radius: 7
                                color: modelData.active ? Qt.rgba(Colors.colPrimary.r, Colors.colPrimary.g, Colors.colPrimary.b, 0.16)
                                                        : (sourceHover.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(1, 1, 1, 0.03))
                                border.color: modelData.active ? Colors.colPrimary : "transparent"
                                border.width: modelData.active ? 1 : 0

                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    Text {
                                        text: modelData.icon || "󰍬"
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 13
                                        color: modelData.active ? Colors.colPrimary : Colors.colTextMuted
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.displayName
                                        font.family: "Geist"
                                        font.pixelSize: 12
                                        font.bold: modelData.active
                                        color: modelData.active ? Colors.colPrimary : Colors.colText
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: modelData.active
                                        text: ""
                                        font.family: "Symbols Nerd Font"
                                        font.pixelSize: 12
                                        color: Colors.colPrimary
                                    }
                                }

                                MouseArea {
                                    id: sourceHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.setSourcePort(modelData.target, modelData.port)
                                        root.inputExpanded = false
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
