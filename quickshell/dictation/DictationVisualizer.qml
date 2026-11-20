import QtQuick
import "../theme"

Item {
    id: root

    property real level: 0
    property bool running: false
    property bool thinking: false
    property color dotColor: Colors.colPrimary

    readonly property int barCount: 15
    readonly property real barWidth: 3.5
    readonly property real barGap: 4.5
    readonly property int centerIndex: (barCount - 1) / 2
    readonly property int trailLength: 24
    readonly property real stiffness: 240
    readonly property real damping: 2 * Math.sqrt(stiffness) * 0.82

    property real clock: 0
    property real smoothed: 0
    property var trail: new Array(trailLength).fill(0)
    property var positions: new Array(barCount).fill(0)
    property var velocities: new Array(barCount).fill(0)

    function reach(index) {
        const distance = Math.abs(index - centerIndex) / centerIndex
        return Math.exp(-distance * distance * 2.1)
    }

    function goal(index) {
        const distance = Math.abs(index - centerIndex)
        if (thinking) {
            return 0.1 + 0.34 * reach(index) * (0.5 + 0.5 * Math.sin(clock * 4.4 - distance * 0.7))
        }
        const lagged = trail[Math.min(trailLength - 1, Math.round(distance * 1.6))]
        const shimmer = 0.82 + 0.18 * Math.sin(clock * 6.2 + index * 1.7)
        const idle = 0.035 + 0.035 * Math.sin(clock * 1.9 - distance * 0.55) * reach(index)
        return Math.max(idle, lagged * reach(index) * shimmer)
    }

    function step(rawDt) {
        const dt = Math.min(rawDt, 0.033)
        const heard = Math.pow(level, 0.78)
        smoothed += (heard - smoothed) * (1 - Math.exp(-(heard > smoothed ? 22 : 8) * dt))
        trail = [smoothed].concat(trail.slice(0, trailLength - 1))

        const nextPositions = positions.slice()
        const nextVelocities = velocities.slice()
        for (let i = 0; i < barCount; i++) {
            const force = stiffness * (goal(i) - nextPositions[i]) - damping * nextVelocities[i]
            nextVelocities[i] += force * dt
            nextPositions[i] = Math.max(0, nextPositions[i] + nextVelocities[i] * dt)
        }
        positions = nextPositions
        velocities = nextVelocities
    }

    function settle() {
        smoothed = 0
        trail = new Array(trailLength).fill(0)
        positions = new Array(barCount).fill(0)
        velocities = new Array(barCount).fill(0)
    }

    onRunningChanged: if (!running) settle()

    FrameAnimation {
        running: root.running
        onTriggered: {
            root.clock += frameTime
            root.step(frameTime)
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: root.barGap

        Repeater {
            model: root.barCount

            delegate: Rectangle {
                required property int index

                anchors.verticalCenter: parent.verticalCenter
                width: root.barWidth
                height: Math.min(root.height, root.barWidth + root.positions[index] * (root.height - root.barWidth))
                radius: width / 2
                color: root.dotColor
                opacity: (0.35 + 0.65 * root.reach(index)) * (0.7 + 0.3 * Math.min(1, root.positions[index] * 2))
            }
        }
    }
}
