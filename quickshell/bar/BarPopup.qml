import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

Scope {
    id: root

    required property string name
    required property Item target

    property real bodyWidth: 300
    property real bodyHeight: 200
    property real barHeight: 38
    property bool takesKeyboard: false
    property real anchorX: 0
    property real progress: open ? 1 : 0
    property real shownHeight: bodyHeight

    readonly property real flare: 16
    readonly property real restWidth: 0.55
    readonly property bool open: PopupManager.isPopupOpen(name)
    readonly property bool active: open || progress > 0
    readonly property var screenRef: target.QsWindow.window ? target.QsWindow.window.screen : null

    default property alias content: body.data

    signal opened()

    function place() {
        const width = bodyWidth + flare * 2
        const center = target.mapToItem(null, target.width / 2, 0).x
        const limit = (screenRef ? screenRef.width : 1920) - width - 8
        anchorX = Math.max(8, Math.min(limit, center - width / 2))
    }

    onOpenChanged: {
        if (!open) return
        place()
        opened()
    }

    Behavior on progress {
        NumberAnimation {
            duration: root.open ? 380 : 260
            easing.type: root.open ? Easing.OutQuint : Easing.InOutCubic
        }
    }

    Behavior on shownHeight {
        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
    }

    PanelWindow {
        screen: root.screenRef
        visible: root.open
        color: "transparent"
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        margins.top: root.barHeight

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "aether-popup-dismiss"
        exclusionMode: ExclusionMode.Ignore

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            onPressed: PopupManager.closeAll()
        }
    }

    PanelWindow {
        id: window
        screen: root.screenRef
        visible: root.active
        color: "transparent"
        anchors {
            top: true
            left: true
        }
        margins.top: root.barHeight
        margins.left: root.anchorX
        implicitWidth: root.bodyWidth + root.flare * 2
        implicitHeight: Math.max(root.bodyHeight, root.shownHeight)
        mask: Region { item: frame }

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: (root.open && root.takesKeyboard) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        WlrLayershell.namespace: "aether-popup"
        exclusionMode: ExclusionMode.Ignore

        Item {
            anchors.fill: parent
            clip: true

            Item {
                id: frame
                anchors.horizontalCenter: parent.horizontalCenter
                width: 2 * Math.round(parent.width * (root.restWidth + (1 - root.restWidth) * root.progress) / 2)
                height: Math.max(1, Math.round(root.shownHeight * root.progress))
                focus: root.open
                Keys.onEscapePressed: PopupManager.closeAll()

                AttachedShape {
                    anchors.fill: parent
                    flare: root.flare
                }

                Item {
                    id: viewport
                    x: root.flare
                    width: parent.width - root.flare * 2
                    height: parent.height
                    clip: true

                    Item {
                        id: body
                        x: Math.round((viewport.width - root.bodyWidth) / 2)
                        width: root.bodyWidth
                        height: root.shownHeight
                        opacity: Math.min(1, Math.max(0, (root.progress - 0.25) / 0.55))
                    }
                }
            }
        }
    }
}
