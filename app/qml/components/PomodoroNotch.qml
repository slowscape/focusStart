import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Settings > "Display Pomodoro on notch": the running timer as a pill at the top centre of the
// screen (over the MacBook notch; backend.elevateNotch lifts it above the menu bar), visible over
// other apps. The window is exactly the pill's size, so it never blocks clicks around it.
//   Colour: black while focusing, green on a break, red when a break is over (waiting for you).
//   Collapsed: phase and the current step (shortened) on the left, time on the right.
//   Hover/click expands it: ring, task and step (click them to open StepTask), and buttons:
//   Continue (break over), pause/resume, stop, skip to the next step (only with 2+ steps to do).
//   Drag it anywhere (remembered); double-click puts it back at the top centre.
// Collapsing fades the text out first, then shrinks: the text never reflows while the pill
// changes size (fixed-width body, clipped), which used to look squashed.
Window {
    id: notch
    signal openRequested()
    signal continueRequested()

    readonly property bool wanted: backend.pomoNotch && backend.pomoEnabled && backend.pomoRunning
    property bool expanded: false            // what the user asked for (hover/click)
    property bool sized: false               // the pill's size: follows `expanded`, later when collapsing
    readonly property string phase: backend.pomoPhase
    readonly property bool onBreak: phase === "short" || phase === "long"
    readonly property bool breakOver: backend.pomoWaiting
    readonly property int phaseTotal: 60 * (phase === "short" ? backend.pomoShort
                                           : phase === "long" ? backend.pomoLong : backend.pomoWork)
    readonly property color fill: breakOver ? "#b3261e" : onBreak ? "#1f7a35" : "#0b0b0b"
    readonly property color ink: "#f5f5f5"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.68)
    readonly property color grey: "#8a8a8a"
    readonly property int barH: 34
    readonly property int collapsedW: 300
    readonly property int expandedW: 360

    function fmt(sec) { return Math.floor(sec / 60) + ":" + ("0" + sec % 60).slice(-2) }
    readonly property string phaseLabel: breakOver ? "Break over"
                                         : backend.pomoPaused ? "Paused"
                                         : phase === "work" ? "Focus" : phase === "short" ? "Short break" : "Long break"

    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    title: "StepTask timer"
    visible: wanted
    width: pill.width
    height: pill.height
    // Top centre unless the user dragged it somewhere (backend.pomoNotchPos, remembered).
    readonly property var savedPos: backend.pomoNotchPos
    x: savedPos.length === 2 ? savedPos[0] : (screen ? screen.virtualX + Math.round((screen.width - width) / 2) : 0)
    y: savedPos.length === 2 ? savedPos[1] : (screen ? screen.virtualY : 0)

    onVisibleChanged: {
        if (visible) backend.elevateNotch(notch)
        else { expanded = false; sized = false }
    }
    onExpandedChanged: {
        if (expanded) { shrinkTimer.stop(); sized = true }
        else shrinkTimer.restart()                 // let the text fade first
    }

    Timer { id: collapseTimer; interval: 450; onTriggered: notch.expanded = false }
    Timer { id: shrinkTimer; interval: 90; onTriggered: notch.sized = false }
    // Remember where the user dropped it (after the system move settles).
    property bool moving: false
    Timer { id: saveMoveTimer; interval: 400; onTriggered: { notch.moving = false; backend.setNotchPos(notch.x, notch.y) } }
    onXChanged: if (moving) saveMoveTimer.restart()
    onYChanged: if (moving) saveMoveTimer.restart()

    Rectangle {
        id: pill
        width: notch.sized ? notch.expandedW : notch.collapsedW
        height: notch.sized ? notch.barH + body.implicitHeight + 14 : notch.barH
        color: notch.fill
        radius: 18
        clip: true
        Behavior on width { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Theme.durSlow } }
        // Square top corners at the top of the screen (the pill hangs from the edge).
        Rectangle { width: parent.width; height: parent.radius; color: parent.color; visible: notch.savedPos.length !== 2 }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) { collapseTimer.stop(); notch.expanded = true }
                else collapseTimer.restart()
            }
        }
        TapHandler {
            onTapped: notch.expanded = !notch.expanded
            onDoubleTapped: backend.resetNotchPos()
        }
        // Drag the pill to move it (the system does the move, so it's smooth on every OS).
        DragHandler {
            target: null
            onActiveChanged: if (active) { notch.moving = true; notch.startSystemMove() }
        }

        // Top row: always visible.
        RowLayout {
            id: top
            x: 16; width: parent.width - 32; height: notch.barH
            spacing: 8
            Rectangle {
                width: 8; height: 8; radius: 4
                color: notch.breakOver || notch.onBreak ? notch.ink
                       : backend.pomoPaused ? notch.grey : Theme.accent
            }
            Label { text: notch.phaseLabel; color: notch.dim; font.pixelSize: Theme.fontSmall }
            // The current step, shortened (focus only). Hidden while expanded: the body shows it.
            Label {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: notch.phase === "work" && !notch.breakOver
                opacity: notch.expanded ? 0 : 1
                Behavior on opacity { NumberAnimation { duration: 90 } }
                text: backend.pomoStepText ? "·  " + backend.pomoStepText : ""
                color: notch.ink
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSmall
            }
            Item { Layout.fillWidth: true; visible: !(notch.phase === "work" && !notch.breakOver) }
            Label {
                text: notch.fmt(backend.pomoRemaining)
                color: notch.ink
                opacity: backend.pomoPaused ? 0.6 : 1
                font.pixelSize: 14
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }

        // Expanded body. Fixed width (the expanded size), so it never reflows mid-animation.
        ColumnLayout {
            id: body
            x: 16; y: notch.barH; width: notch.expandedW - 32
            spacing: 10
            opacity: notch.expanded && pill.width >= notch.expandedW - 6 ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: 90 } }

            RowLayout {
                Layout.fillWidth: true
                Layout.rightMargin: 4
                spacing: 12
                Canvas {
                    id: ring
                    Layout.alignment: Qt.AlignTop
                    implicitWidth: 34; implicitHeight: 34
                    readonly property real frac: notch.phaseTotal > 0 ? 1 - backend.pomoRemaining / notch.phaseTotal : 0
                    readonly property color stroke: backend.pomoPaused || notch.breakOver ? notch.ink
                                                    : notch.onBreak ? notch.ink : Theme.accent
                    onFracChanged: requestPaint()
                    onStrokeChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        var c = width / 2, r = c - 3
                        ctx.lineWidth = 4
                        ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.18)
                        ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 2); ctx.stroke()
                        ctx.strokeStyle = stroke; ctx.lineCap = "round"
                        ctx.beginPath(); ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.001, frac)); ctx.stroke()
                    }
                }
                // Task (small) and step; click to open StepTask on this task.
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        Layout.fillWidth: true
                        color: notch.dim
                        font.pixelSize: Theme.fontSmall
                        text: notch.phaseLabel + (notch.phase === "work" && !notch.breakOver
                              ? " · session " + Math.min(backend.pomoWorkDone + 1, backend.pomoLongEvery) + " of " + backend.pomoLongEvery : "")
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: text !== ""
                        color: notch.dim
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontSmall
                        text: backend.pomoTaskTitle
                    }
                    Label {
                        Layout.fillWidth: true
                        visible: text !== ""
                        color: notch.ink
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        font.pixelSize: Theme.fontBody
                        font.weight: Font.DemiBold
                        text: backend.pomoStepText
                    }
                    TapHandler { onTapped: notch.openRequested() }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                NotchButton {
                    visible: notch.breakOver
                    label: "Continue"
                    onClicked: notch.continueRequested()
                }
                NotchButton {
                    visible: !notch.breakOver
                    icon_: backend.pomoPaused ? "play" : "pause"
                    tip: backend.pomoPaused ? "Resume" : "Pause"
                    onClicked: backend.pomoTogglePause()
                }
                NotchButton { icon_: "stop"; tip: "Stop and reset"; onClicked: backend.pomoStop() }
                NotchButton {
                    visible: backend.pomoCanSkip
                    icon_: "chevronR"; tip: "Skip to the next step"
                    onClicked: backend.skipStep()
                }
            }
        }
    }

    component NotchButton: AbstractButton {
        id: nb
        property string icon_: ""
        property string label: ""
        property string tip: label
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        implicitWidth: label !== "" ? lbl.implicitWidth + 24 : 30
        implicitHeight: 30
        padding: 0
        background: Rectangle { radius: 15; color: nb.hovered ? Qt.rgba(1, 1, 1, 0.24) : Qt.rgba(1, 1, 1, 0.14) }
        contentItem: Item {
            Icon { anchors.centerIn: parent; visible: nb.icon_ !== ""; name: nb.icon_; size: 13; color: notch.ink }
            Label { id: lbl; anchors.centerIn: parent; visible: nb.label !== ""; text: nb.label; color: notch.ink; font.pixelSize: Theme.fontSmall }
        }
        Accessible.name: tip
    }
}
