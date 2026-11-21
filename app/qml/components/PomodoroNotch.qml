import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Settings > "Display Pomodoro on notch": the running timer as a slim bar docked to the top or
// bottom edge of the screen (top centre by default: over the MacBook notch; backend.elevateNotch
// lifts it above the menu bar), visible over other apps. It never expands: everything is on one
// line, phase + current step + time, then small buttons (Continue when a break is over,
// pause/resume, stop, skip to the next step when 2+ are left).
//   Colour: black while focusing, green on a break, red when a break is over.
//   Drag it to move it along the edge; dropping it in the upper or lower half of the screen docks
//   it to the top or the bottom (just above the taskbar/Dock). Remembered. Double-click: back to
//   top centre. Click (without dragging) the text to open StepTask on the task.
// The window is exactly the bar's size, so it never blocks clicks around it.
Window {
    id: notch
    signal openRequested()
    signal continueRequested()

    readonly property bool wanted: backend.pomoNotch && backend.pomoEnabled && backend.pomoRunning
    readonly property string phase: backend.pomoPhase
    readonly property bool onBreak: phase === "short" || phase === "long"
    readonly property bool breakOver: backend.pomoWaiting
    readonly property color fill: breakOver ? "#b3261e" : onBreak ? "#1f7a35" : "#0b0b0b"
    readonly property color ink: "#f5f5f5"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.68)
    readonly property color grey: "#8a8a8a"
    readonly property int barH: 34
    readonly property int barW: 400

    function fmt(sec) { return Math.floor(sec / 60) + ":" + ("0" + sec % 60).slice(-2) }
    readonly property string phaseLabel: breakOver ? "Break over"
                                         : backend.pomoPaused ? "Paused"
                                         : phase === "work" ? "Focus" : phase === "short" ? "Short break" : "Long break"

    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    title: "StepTask timer"
    visible: wanted
    width: barW
    height: barH

    // ---- docking: saved edge + centre (fraction of the screen width); live values while dragging
    readonly property var dock: backend.pomoNotchDock
    property bool dragging: false
    property string dragEdge: "top"
    property real dragX: 0
    readonly property string edge: dragging ? dragEdge : (dock.edge || "top")
    readonly property var area: backend.screenArea(screen ? screen.virtualX + 1 : 0, screen ? screen.virtualY + 1 : 0)
    function clampX(v) { return Math.max(area.x, Math.min(area.x + area.w - width, v)) }
    x: dragging ? dragX : clampX(Math.round(area.x + (dock.x !== undefined ? dock.x : 0.5) * area.w - width / 2))
    y: edge === "top" ? area.y : area.ay + area.ah - height

    onVisibleChanged: if (visible) backend.elevateNotch(notch)

    Rectangle {
        id: bar
        anchors.fill: parent
        color: notch.fill
        radius: 17
        Behavior on color { ColorAnimation { duration: Theme.durSlow } }
        // Square corners on the docked edge: it hangs from the top, or sits on the bottom.
        Rectangle {
            width: parent.width; height: parent.radius; color: parent.color
            y: notch.edge === "top" ? 0 : parent.height - height
        }

        // Drag to move / dock; a click without dragging opens StepTask; double-click resets.
        MouseArea {
            id: mover
            anchors.fill: parent
            property real pressGX: 0
            property real pressGY: 0
            property real startX: 0
            property bool moved: false
            cursorShape: notch.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            onPressed: (m) => { pressGX = notch.x + m.x; pressGY = notch.y + m.y; startX = notch.x; moved = false }
            onPositionChanged: (m) => {
                if (!pressed) return
                var gx = notch.x + m.x, gy = notch.y + m.y
                if (!moved && Math.abs(gx - pressGX) < 6 && Math.abs(gy - pressGY) < 6) return
                if (!moved) { moved = true; notch.dragEdge = notch.edge; notch.dragX = notch.x; notch.dragging = true }
                notch.dragX = notch.clampX(startX + gx - pressGX)
                notch.dragEdge = gy < notch.area.y + notch.area.h / 2 ? "top" : "bottom"
            }
            onReleased: {
                if (notch.dragging) {
                    backend.setNotchDock(notch.dragEdge, (notch.dragX + notch.width / 2 - notch.area.x) / notch.area.w)
                    notch.dragging = false
                } else if (!moved) {
                    notch.openRequested()
                }
            }
            onDoubleClicked: backend.resetNotchDock()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 14
            anchors.rightMargin: 6
            spacing: 8
            Rectangle {
                width: 8; height: 8; radius: 4
                color: notch.breakOver || notch.onBreak ? notch.ink
                       : backend.pomoPaused ? notch.grey : Theme.accent
            }
            Label { text: notch.phaseLabel; color: notch.dim; font.pixelSize: Theme.fontSmall }
            // The current step, shortened (while focusing).
            Label {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: notch.phase === "work" && !notch.breakOver && backend.pomoStepText
                      ? "·  " + backend.pomoStepText : ""
                color: notch.ink
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSmall
            }
            Label {
                text: notch.fmt(backend.pomoRemaining)
                color: notch.ink
                opacity: backend.pomoPaused ? 0.6 : 1
                font.pixelSize: 14
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
            Row {
                spacing: 2
                Layout.leftMargin: 2
                BarButton {
                    visible: notch.breakOver
                    label: "Continue"
                    onClicked: notch.continueRequested()
                }
                BarButton {
                    visible: !notch.breakOver
                    icon_: backend.pomoPaused ? "play" : "pause"
                    tip: backend.pomoPaused ? "Resume" : "Pause"
                    onClicked: backend.pomoTogglePause()
                }
                BarButton { icon_: "stop"; tip: "Stop and reset"; onClicked: backend.pomoStop() }
                BarButton {
                    visible: backend.pomoCanSkip && !notch.breakOver
                    icon_: "chevronR"; tip: "Skip to the next step"
                    onClicked: backend.skipStep()
                }
            }
        }
    }

    component BarButton: AbstractButton {
        id: bb
        property string icon_: ""
        property string label: ""
        property string tip: label
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        implicitWidth: label !== "" ? lbl.implicitWidth + 16 : 26
        implicitHeight: 26
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        padding: 0
        background: Rectangle { radius: 13; color: bb.hovered ? Qt.rgba(1, 1, 1, 0.22) : "transparent" }
        contentItem: Item {
            Icon { anchors.centerIn: parent; visible: bb.icon_ !== ""; name: bb.icon_; size: 12; color: notch.ink }
            Label { id: lbl; anchors.centerIn: parent; visible: bb.label !== ""; text: bb.label; color: notch.ink; font.pixelSize: Theme.fontSmall; font.weight: Font.DemiBold }
        }
        Accessible.name: tip
    }
}
