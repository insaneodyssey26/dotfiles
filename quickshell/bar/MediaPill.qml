import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../theme"
import "../services"

Item {
    id: root
    implicitHeight: 26
    implicitWidth: mediaRow.implicitWidth
    visible: activePlayer !== null && activePlayer.trackTitle !== ""

    property var activePlayer: {
        for (let key in Mpris.players.values) {
            let p = Mpris.players.values[key]
            if (p.playbackState === MprisPlaybackState.Playing) return p
        }
        return Mpris.players.values[0] || null
    }

    readonly property bool isPlaying: activePlayer !== null && activePlayer.playbackState === MprisPlaybackState.Playing

    property real currentPos: 0
    property real currentLen: activePlayer ? (activePlayer.length || 0) : 0
    property real basePos: 0
    property real baseTime: Date.now()
    property bool isDraggingSeek: false
    property real seekDragRatio: 0.0

    function syncPosition() {
        if (!activePlayer) return
        activePlayer.positionChanged()
        basePos = activePlayer.position || 0
        baseTime = Date.now()
        if (!isDraggingSeek) currentPos = basePos
    }

    function seekTo(ratio) {
        if (!activePlayer || !activePlayer.canSeek || currentLen <= 0) return
        activePlayer.position = ratio * currentLen
        basePos = ratio * currentLen
        baseTime = Date.now()
        currentPos = basePos
    }

    Timer {
        interval: 1000
        running: mediaPopup.active && root.activePlayer !== null && !root.isDraggingSeek
        repeat: true
        onTriggered: root.syncPosition()
    }

    FrameAnimation {
        running: mediaPopup.active && root.isPlaying && !root.isDraggingSeek
        onTriggered: {
            const elapsed = (Date.now() - root.baseTime) / 1000
            root.currentPos = Math.min(root.currentLen > 0 ? root.currentLen : Infinity, root.basePos + elapsed)
        }
    }

    Connections {
        target: root.activePlayer
        function onTrackChanged() { root.syncPosition() }
        function onPlaybackStateChanged() { root.syncPosition() }
        function onLengthChanged() { if (root.activePlayer) root.currentLen = root.activePlayer.length }
    }

    function formatTime(totalSeconds) {
        if (!totalSeconds || totalSeconds <= 0 || isNaN(totalSeconds)) return "0:00"
        const whole = Math.floor(totalSeconds)
        const hours = Math.floor(whole / 3600)
        const minutes = Math.floor((whole % 3600) / 60)
        const seconds = whole % 60
        const pad = n => (n < 10 ? "0" + n : "" + n)
        return hours > 0 ? hours + ":" + pad(minutes) + ":" + pad(seconds) : minutes + ":" + pad(seconds)
    }

    Process {
        id: mediaCmdProc
    }

    RowLayout {
        id: mediaRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        Rectangle {
            width: 24
            height: 24
            radius: 12
            color: playIconMouse.containsMouse ? Qt.rgba(Colors.colPrimary.r, Colors.colPrimary.g, Colors.colPrimary.b, 0.22) : "transparent"

            Behavior on color { ColorAnimation { duration: 100 } }

            Text {
                anchors.centerIn: parent
                text: (activePlayer && activePlayer.playbackState === MprisPlaybackState.Playing) ? "󰎆" : "󰏤"
                font.family: "Symbols Nerd Font"
                font.pixelSize: 14
                color: Colors.colPrimary
            }

            MouseArea {
                id: playIconMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (activePlayer) activePlayer.togglePlaying()
                }
            }
        }

        Item {
            id: titleContainer
            implicitWidth: Math.min(235, titleText.implicitWidth)
            implicitHeight: 22
            clip: true

            Text {
                id: titleText
                anchors.verticalCenter: parent.verticalCenter
                text: activePlayer ? (activePlayer.trackTitle || "") : ""
                font.family: "Geist"
                font.pixelSize: 13
                font.bold: true
                color: titleHoverArea.containsMouse ? Colors.colPrimary : Colors.colText

                Behavior on color { ColorAnimation { duration: 120 } }

                readonly property real overflowDist: Math.max(0, implicitWidth - titleContainer.width)
                x: 0

                SequentialAnimation on x {
                    id: marqueeAnim
                    running: titleText.overflowDist > 0 && titleHoverArea.containsMouse
                    loops: Animation.Infinite
                    PauseAnimation { duration: 600 }
                    NumberAnimation {
                        to: -titleText.overflowDist
                        duration: Math.max(1200, titleText.overflowDist * 28)
                        easing.type: Easing.Linear
                    }
                    PauseAnimation { duration: 1200 }
                    NumberAnimation {
                        to: 0
                        duration: Math.max(1200, titleText.overflowDist * 28)
                        easing.type: Easing.Linear
                    }
                    PauseAnimation { duration: 1000 }
                }

                states: State {
                    when: !titleHoverArea.containsMouse
                    PropertyChanges {
                        target: titleText
                        x: 0
                    }
                }

                transitions: Transition {
                    NumberAnimation {
                        property: "x"
                        to: 0
                        duration: 250
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                id: titleHoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: PopupManager.openPopup("media")
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) {
                        mediaCmdProc.command = ["playerctl", "next"]
                        mediaCmdProc.running = true
                    } else if (wheel.angleDelta.y < 0) {
                        mediaCmdProc.command = ["playerctl", "previous"]
                        mediaCmdProc.running = true
                    }
                }
            }
        }

        Rectangle {
            id: visualizerPill
            property bool isPlaying: activePlayer !== null && activePlayer.playbackState === MprisPlaybackState.Playing
            visible: opacity > 0
            opacity: isPlaying ? 1.0 : 0.0
            implicitHeight: 26
            implicitWidth: isPlaying ? (visualizer.implicitWidth + 16) : 0
            radius: 13
            clip: true
            color: (vizHoverArea.containsMouse || PopupManager.isPopupOpen("media")) ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.10)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1

            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.InOutQuad } }
            Behavior on implicitWidth { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 150 } }

            AudioVisualizer {
                id: visualizer
                anchors.centerIn: parent
                isPlaying: visualizerPill.isPlaying
                barColor: (vizHoverArea.containsMouse || PopupManager.isPopupOpen("media")) ? Colors.colPrimary : Colors.colSecondary
            }

            MouseArea {
                id: vizHoverArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: PopupManager.openPopup("media")
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y > 0) {
                        mediaCmdProc.command = ["playerctl", "next"]
                        mediaCmdProc.running = true
                    } else if (wheel.angleDelta.y < 0) {
                        mediaCmdProc.command = ["playerctl", "previous"]
                        mediaCmdProc.running = true
                    }
                }
            }
        }
    }

    BarPopup {
        id: mediaPopup
        name: "media"
        target: root
        bodyWidth: 340
        bodyHeight: mediaCard.implicitHeight
        onOpened: {
            root.syncPosition()
            if (root.activePlayer) root.currentLen = root.activePlayer.length
        }

        MediaCard {
            id: mediaCard
            anchors.fill: parent
            pill: root
        }
    }
}
