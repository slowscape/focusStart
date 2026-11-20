import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Settings > "Display Pomodoro on notch": the running timer as a black pill at the top centre
// of the screen (over the MacBook notch; backend.elevateNotch lifts it above the menu bar),
// visible over other apps. Collapsed: phase on the left, time on the right, the middle left
// free for the camera notch. Hover (or click) expands it: ring, task and step, pause/resume,
// stop, open StepTask. When a break ends it offers Continue, like BreakOverOverlay.
// The window is exactly the pill's size, so no transparent area ever blocks clicks.
Window {
    id: notch
    signal openRequested()
    signal continueRequested()

    readonly property bool wanted: backend.pomoNotch && backend.pomoEnabled && backend.pomoRunning
    property bool expanded: false
    readonly property string phase: backend.pomoPhase
    readonly property bool onBreak: phase === "short" || phase === "long"
    readonly property int phaseTotal: 60 * (phase === "short" ? backend.pomoShort
                                           : phase === "long" ? backend.pomoLong : backend.pomoWork)
    readonly property color ink: "#f5f5f5"
    readonly property color dim: Qt.rgba(1, 1, 1, 0.6)
    readonly property color green: "#6ccb5f"
    readonly property color grey: "#8a8a8a"
    readonly property int barH: 34

    function fmt(sec) { return Math.floor(sec / 60) + ":" + ("0" + sec % 60).slice(-2) }
    readonly property string phaseLabel: backend.pomoWaiting ? "Break done"
                                         : backend.pomoPaused ? "Paused"
                                         : phase === "work" ? "Focus" : phase === "short" ? "Short break" : "Long break"

    flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    color: "transparent"
    title: "StepTask timer"
    visible: wanted
    width: pill.width
    height: pill.height
    x: screen ? screen.virtualX + Math.round((screen.width - width) / 2) : 0
    y: screen ? screen.virtualY : 0

    onVisibleChanged: {
        if (visible) backend.elevateNotch(notch)
        else expanded = false
    }

    Timer { id: collapseTimer; interval: 450; onTriggered: notch.expanded = false }

    Rectangle {
        id: pill
        width: notch.expanded ? 340 : 250
        height: notch.expanded ? notch.barH + body.implicitHeight + 14 : notch.barH
        color: "#0b0b0b"
        radius: 18
        Behavior on width { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
        // Square top corners: the pill hangs from the screen edge.
        Rectangle { width: parent.width; height: parent.radius; color: parent.color }

        HoverHandler {
            onHoveredChanged: {
                if (hovered) { collapseTimer.stop(); notch.expanded = true }
                else collapseTimer.restart()
            }
        }
        TapHandler { onTapped: notch.expanded = !notch.expanded }

        // Top row: always visible. The middle stays empty for the camera notch.
        RowLayout {
            id: top
            x: 16; width: parent.width - 32; height: notch.barH
            spacing: 8
            Rectangle {
                width: 8; height: 8; radius: 4
                color: backend.pomoPaused || backend.pomoWaiting ? notch.grey : notch.onBreak ? notch.green : Theme.accent
            }
            Label { text: notch.phaseLabel; color: notch.dim; font.pixelSize: Theme.fontSmall }
            Item { Layout.fillWidth: true }
            Label {
                text: notch.fmt(backend.pomoRemaining)
                color: notch.ink
                opacity: backend.pomoPaused ? 0.6 : 1
                font.pixelSize: 14
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }
        }

        ColumnLayout {
            id: body
            x: 16; y: notch.barH; width: parent.width - 32
            spacing: 10
            visible: opacity > 0
            opacity: notch.expanded && pill.width > 300 ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Canvas {
                    id: ring
                    implicitWidth: 34; implicitHeight: 34
                    readonly property real frac: notch.phaseTotal > 0 ? 1 - backend.pomoRemaining / notch.phaseTotal : 0
                    readonly property color stroke: backend.pomoPaused || backend.pomoWaiting ? notch.grey
                                                    : notch.onBreak ? notch.green : Theme.accent
                    onFracChanged: requestPaint()
                    onStrokeChanged: requestPaint()
                    onPaint: {
                        var ctx = getContext("2d"); ctx.reset()
                        var c = width / 2, r = c - 3
                        ctx.lineWidth = 4
                        ctx.strokeStyle = "#2a2a2a"
                        ctx.beginPath(); ctx.arc(c, c, r, 0, Math.PI * 2); ctx.stroke()
                        ctx.strokeStyle = stroke; ctx.lineCap = "round"
                        ctx.beginPath(); ctx.arc(c, c, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * Math.max(0.001, frac)); ctx.stroke()
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Label {
                        Layout.fillWidth: true
                        color: notch.dim
                        font.pixelSize: Theme.fontSmall
                        text: notch.phaseLabel + (notch.phase === "work" && !backend.pomoWaiting
                              ? " · session " + Math.min(backend.pomoWorkDone + 1, backend.pomoLongEvery) + " of " + backend.pomoLongEvery : "")
                    }
                    Label {
                        Layout.fillWidth: true
                        color: notch.ink
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        text: backend.pomoTaskTitle + (backend.pomoStepText ? " · " + backend.pomoStepText : "")
                        visible: text !== ""
                    }
                }
                Label {
                    text: notch.fmt(backend.pomoRemaining)
                    color: notch.ink
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Item { Layout.fillWidth: true }
                NotchButton {
                    visible: backend.pomoWaiting
                    label: "Continue"
                    onClicked: notch.continueRequested()
                }
                NotchButton {
                    visible: !backend.pomoWaiting
                    icon_: backend.pomoPaused ? "play" : "pause"
                    tip: backend.pomoPaused ? "Resume" : "Pause"
                    onClicked: backend.pomoTogglePause()
                }
                NotchButton { icon_: "stop"; tip: "Stop and reset"; onClicked: backend.pomoStop() }
                NotchButton { icon_: "chevronR"; tip: "Open StepTask"; onClicked: notch.openRequested() }
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
        background: Rectangle { radius: 15; color: nb.hovered ? "#3a3a3a" : "#2a2a2a" }
        contentItem: Item {
            Icon { anchors.centerIn: parent; visible: nb.icon_ !== ""; name: nb.icon_; size: 13; color: notch.ink }
            Label { id: lbl; anchors.centerIn: parent; visible: nb.label !== ""; text: nb.label; color: notch.ink; font.pixelSize: Theme.fontSmall }
        }
        Accessible.name: tip
    }
}
