import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Settings > "Display Pomodoro on notch": the running timer as a slim bar docked to a screen edge
// (top centre by default: over the MacBook notch; backend.elevateNotch lifts it above the menu
// bar), visible over other apps. It never expands: phase + current step + time, then small
// buttons: Continue (break over), pause/resume, stop, complete (the current step, or the task
// when it has none: same as Focus's main button), skip to the next step (2+ left).
//   Colour: black while focusing, green on a break, red when a break is over.
//   Docking: drag it; it follows the mouse along the nearest screen edge (top, bottom, left,
//   right) and stays there (remembered). On the left/right edges the bar stands upright: its
//   words turn 90 degrees, the buttons stay upright, stacked. Top/bottom/left/right sit inside the
//   area not covered by the taskbar/Dock, except the top, which hangs from the very top (notch).
//   Double-click: back to top centre. Click (without dragging) the words to open StepTask.
// The window is exactly the bar's size, so it never blocks clicks around it.
Window {
    id: notch
    signal openRequested()
    signal continueRequested()
    signal completeRequested()

    readonly property bool wanted: backend.pomoNotch && backend.pomoEnabled && backend.pomoRunning
    readonly property string phase: backend.pomoPhase
    readonly property bool onBreak: phase === "short" || phase === "long"
    readonly property bool breakOver: backend.pomoWaiting
    readonly property color fill: breakOver ? "#b3261e" : onBreak ? "#1f7a35" : "#0b0b0b"
    readonly property color ink: "#f5f5f5"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.68)
    readonly property color grey: "#8a8a8a"
    readonly property int thick: 34          // the bar's short side
    readonly property int long_: 440         // the bar's long side

    function fmt(sec) { return Math.floor(sec / 60) + ":" + ("0" + sec % 60).slice(-2) }
    readonly property string phaseLabel: breakOver ? "Break over"
                                         : backend.pomoPaused ? "Paused"
                                         : phase === "work" ? "Focus" : phase === "short" ? "Short break" : "Long break"

    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    title: "StepTask timer"
    visible: wanted

    // ---- docking: saved edge + centre along it (fraction); live values while dragging
    readonly property var dock: backend.pomoNotchDock
    property bool dragging: false
    property string dragEdge: "top"
    property real dragPos: 0.5
    readonly property string edge: dragging ? dragEdge : (dock.edge || "top")
    readonly property real along: dragging ? dragPos : (dock.pos !== undefined ? dock.pos : 0.5)
    readonly property bool vertical: edge === "left" || edge === "right"
    readonly property var area: backend.screenArea(screen ? screen.virtualX + 1 : 0, screen ? screen.virtualY + 1 : 0)
    width: vertical ? thick : long_
    height: vertical ? long_ : thick
    function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }
    x: vertical ? (edge === "left" ? area.ax : area.ax + area.aw - width)
                : clamp(Math.round(area.x + along * area.w - width / 2), area.x, area.x + area.w - width)
    y: vertical ? clamp(Math.round(area.ay + along * area.ah - height / 2), area.ay, area.ay + area.ah - height)
                : (edge === "top" ? area.y : area.ay + area.ah - height)

    onVisibleChanged: if (visible) backend.elevateNotch(notch)

    Rectangle {
        id: bar
        anchors.fill: parent
        color: notch.fill
        radius: 17
        Behavior on color { ColorAnimation { duration: Theme.durSlow } }
        // Square corners on the docked edge.
        Rectangle {
            color: parent.color
            width: notch.vertical ? parent.radius : parent.width
            height: notch.vertical ? parent.height : parent.radius
            x: notch.edge === "right" ? parent.width - width : 0
            y: notch.edge === "bottom" ? parent.height - height : 0
        }

        // Drag to dock anywhere along any edge; a click without dragging opens StepTask.
        MouseArea {
            id: mover
            anchors.fill: parent
            property real pressGX: 0
            property real pressGY: 0
            property bool moved: false
            cursorShape: notch.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            onPressed: (m) => { pressGX = notch.x + m.x; pressGY = notch.y + m.y; moved = false }
            onPositionChanged: (m) => {
                if (!pressed) return
                var gx = notch.x + m.x, gy = notch.y + m.y
                if (!moved && Math.abs(gx - pressGX) < 6 && Math.abs(gy - pressGY) < 6) return
                moved = true
                var a = notch.area
                // Nearest edge to the mouse; the bar centres on the mouse along that edge.
                var d = { top: gy - a.y, bottom: a.y + a.h - gy, left: gx - a.x, right: a.x + a.w - gx }
                var e = "top"
                for (var k in d) if (d[k] < d[e]) e = k
                notch.dragEdge = e
                notch.dragPos = (e === "left" || e === "right") ? (gy - a.ay) / a.ah : (gx - a.x) / a.w
                notch.dragging = true
            }
            onReleased: {
                if (notch.dragging) {
                    backend.setNotchDock(notch.dragEdge, notch.clamp(notch.dragPos, 0, 1))
                    notch.dragging = false
                } else if (!moved) {
                    notch.openRequested()
                }
            }
            onDoubleClicked: backend.resetNotchDock()
        }

        // The words: one line, turned 90 degrees on the side edges (reading top to bottom).
        Item {
            id: words
            readonly property int pad: 14
            width: (notch.vertical ? bar.height : bar.width) - pad - 6 - controls.alongSize - 6
            height: notch.thick
            transformOrigin: Item.TopLeft
            rotation: notch.vertical ? 90 : 0
            x: notch.vertical ? notch.thick : pad
            y: notch.vertical ? pad : 0
            RowLayout {
                anchors.fill: parent
                spacing: 8
                Rectangle {
                    width: 8; height: 8; radius: 4
                    color: notch.breakOver || notch.onBreak ? notch.ink
                           : backend.pomoPaused ? notch.grey : Theme.accent
                }
                Label { text: notch.phaseLabel; color: notch.dim; font.pixelSize: Theme.fontSmall }
                Label {   // the current step, shortened (while focusing)
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
            }
        }

        // The buttons: always upright; in a row on top/bottom, stacked on the sides.
        Grid {
            id: controls
            readonly property real alongSize: notch.vertical ? height : width
            columns: notch.vertical ? 1 : 6
            spacing: 2
            x: notch.vertical ? (bar.width - width) / 2 : bar.width - width - 6
            y: notch.vertical ? bar.height - height - 6 : (bar.height - height) / 2
            BarButton {   // "Continue" (a play icon on the narrow side bar)
                visible: notch.breakOver
                label: notch.vertical ? "" : "Continue"
                icon_: notch.vertical ? "play" : ""
                tip: "Continue"
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
                visible: !notch.breakOver && backend.pomoTaskId !== ""
                icon_: "check"
                tip: backend.pomoStepId ? "Step complete" : "Task complete"
                onClicked: notch.completeRequested()
            }
            BarButton {
                visible: backend.pomoCanSkip && !notch.breakOver
                icon_: "chevronR"; tip: "Skip to the next step"
                onClicked: backend.skipStep()
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
        padding: 0
        background: Rectangle { radius: 13; color: bb.hovered ? Qt.rgba(1, 1, 1, 0.22) : "transparent" }
        contentItem: Item {
            Icon { anchors.centerIn: parent; visible: bb.icon_ !== ""; name: bb.icon_; size: 12; color: notch.ink }
            Label { id: lbl; anchors.centerIn: parent; visible: bb.label !== ""; text: bb.label; color: notch.ink; font.pixelSize: Theme.fontSmall; font.weight: Font.DemiBold }
        }
        // No tooltips: they'd be clipped inside this bar-sized window.
        Accessible.name: tip
    }
}
