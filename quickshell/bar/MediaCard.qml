import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Services.Mpris
import "../theme"

Item {
    id: root

    required property var pill

    readonly property var player: pill.activePlayer
    readonly property bool playing: player !== null && player.playbackState === MprisPlaybackState.Playing
    readonly property bool hasTrack: player !== null && (player.trackTitle || "") !== ""
    readonly property real ratio: {
        if (pill.isDraggingSeek) return pill.seekDragRatio
        if (!pill.currentLen || pill.currentLen <= 0) return 0
        return Math.min(1, Math.max(0, pill.currentPos / pill.currentLen))
    }
    readonly property string artists: {
        if (!player || !player.trackArtists) return ""
        return Array.isArray(player.trackArtists) ? player.trackArtists.join(", ") : player.trackArtists.toString()
    }

    implicitWidth: 340
    implicitHeight: column.implicitHeight + 36

    ColumnLayout {
        id: column
        anchors.fill: parent
        anchors.margins: 18
        spacing: 16

        Text {
            text: root.player ? root.player.identity : ""
            font.family: "Geist"
            font.pixelSize: 11
            font.bold: true
            color: Colors.colTextMuted
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Item {
                id: art
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72
                scale: root.playing ? 1 : 0.94

                Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }

                Image {
                    id: cover
                    anchors.fill: parent
                    source: (root.player && root.player.trackArtUrl) ? root.player.trackArtUrl : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 160
                    sourceSize.height: 160
                    visible: false
                }

                Rectangle {
                    id: fallback
                    anchors.fill: parent
                    radius: 14
                    visible: cover.status !== Image.Ready
                    color: Qt.rgba(Colors.colPrimary.r, Colors.colPrimary.g, Colors.colPrimary.b, 0.14)

                    Text {
                        anchors.centerIn: parent
                        text: "󰎆"
                        font.family: "Symbols Nerd Font"
                        font.pixelSize: 28
                        color: Colors.colPrimary
                    }
                }

                MultiEffect {
                    anchors.fill: parent
                    source: cover
                    visible: cover.status === Image.Ready
                    maskEnabled: true
                    maskSource: mask
                }

                Item {
                    id: mask
                    anchors.fill: parent
                    layer.enabled: true
                    visible: false

                    Rectangle {
                        anchors.fill: parent
                        radius: 14
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: "transparent"
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.08)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 3

                Item {
                    Layout.fillWidth: true
                    implicitHeight: title.implicitHeight
                    clip: true

                    Text {
                        id: title
                        readonly property real overflow: Math.max(0, implicitWidth - parent.width)

                        text: root.hasTrack ? root.player.trackTitle : (root.player ? "Nothing playing" : "No player")
                        font.family: "Geist"
                        font.pixelSize: 16
                        font.bold: true
                        color: Colors.colText

                        SequentialAnimation on x {
                            running: title.overflow > 0
                            loops: Animation.Infinite
                            PauseAnimation { duration: 2200 }
                            NumberAnimation { to: -title.overflow; duration: Math.max(1400, title.overflow * 30); easing.type: Easing.Linear }
                            PauseAnimation { duration: 2000 }
                            NumberAnimation { to: 0; duration: 700; easing.type: Easing.OutCubic }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                    visible: text !== ""
                    text: root.artists
                    font.family: "Geist"
                    font.pixelSize: 13
                    color: Colors.colPrimary
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            visible: pill.currentLen > 0

            Item {
                id: track
                Layout.fillWidth: true
                implicitHeight: 14

                readonly property bool engaged: seek.containsMouse || pill.isDraggingSeek

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: track.engaged ? 6 : 4
                    radius: height / 2
                    color: Qt.rgba(1, 1, 1, 0.1)

                    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    Rectangle {
                        height: parent.height
                        width: Math.max(parent.height, parent.width * root.ratio)
                        radius: height / 2
                        color: Colors.colPrimary

                        Behavior on width {
                            enabled: !pill.isDraggingSeek
                            NumberAnimation { duration: 90; easing.type: Easing.Linear }
                        }
                    }
                }

                MouseArea {
                    id: seek
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor

                    function ratioAt(x) { return Math.max(0, Math.min(1, x / width)) }

                    onPressed: mouse => {
                        pill.isDraggingSeek = true
                        pill.seekDragRatio = ratioAt(mouse.x)
                        pill.currentPos = pill.seekDragRatio * pill.currentLen
                    }
                    onPositionChanged: mouse => {
                        if (!pill.isDraggingSeek) return
                        pill.seekDragRatio = ratioAt(mouse.x)
                        pill.currentPos = pill.seekDragRatio * pill.currentLen
                    }
                    onReleased: mouse => {
                        if (!pill.isDraggingSeek) return
                        pill.seekTo(ratioAt(mouse.x))
                        pill.isDraggingSeek = false
                    }
                    onCanceled: pill.isDraggingSeek = false
                }
            }

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: pill.formatTime(pill.currentPos)
                    font.family: "Geist"
                    font.pixelSize: 10
                    font.bold: true
                    color: Colors.colTextMuted
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: pill.formatTime(pill.currentLen)
                    font.family: "Geist"
                    font.pixelSize: 10
                    font.bold: true
                    color: Colors.colTextMuted
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            Rectangle {
                id: previousButton
                implicitWidth: 38
                implicitHeight: 38
                radius: 19
                opacity: root.player !== null && root.player.canGoPrevious ? 1 : 0.35
                color: previousArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                scale: previousArea.pressed ? 0.9 : 1

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                Text {
                    anchors.centerIn: parent
                    text: "󰒮"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 18
                    color: Colors.colText
                }

                MouseArea {
                    id: previousArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
                }
            }

            Rectangle {
                implicitWidth: 48
                implicitHeight: 48
                radius: 24
                color: Colors.colPrimary
                scale: playArea.pressed ? 0.93 : (playArea.containsMouse ? 1.04 : 1)

                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: root.playing ? 0 : 1
                    text: root.playing ? "󰏤" : "󰐊"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 21
                    color: Colors.colOnPrimary
                }

                MouseArea {
                    id: playArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player) root.player.togglePlaying()
                }
            }

            Rectangle {
                id: nextButton
                implicitWidth: 38
                implicitHeight: 38
                radius: 19
                opacity: root.player !== null && root.player.canGoNext ? 1 : 0.35
                color: nextArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
                scale: nextArea.pressed ? 0.9 : 1

                Behavior on color { ColorAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutQuad } }

                Text {
                    anchors.centerIn: parent
                    text: "󰒭"
                    font.family: "Symbols Nerd Font"
                    font.pixelSize: 18
                    color: Colors.colText
                }

                MouseArea {
                    id: nextArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (root.player && root.player.canGoNext) root.player.next()
                }
            }
        }
    }
}
