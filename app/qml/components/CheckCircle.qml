import QtQuick
import QtQuick.Controls
import "../theme"

// Circular checkbox with an animated check stroke. Emits toggledOn once.
AbstractButton {
    id: cc
    property int diameter: 22
    property bool done: false
    property real drawn: done ? 1 : 0
    property bool allowUncheck: false
    signal toggledOn()
    signal toggledOff()
    implicitWidth: diameter + 8
    implicitHeight: diameter + 8
    hoverEnabled: true
    focusPolicy: Qt.TabFocus
    Accessible.role: Accessible.CheckBox
    Accessible.name: "Mark done"
    onClicked: {
        if (!done) { done = true; toggledOn() }
        else if (allowUncheck) toggledOff()
    }

    Behavior on drawn { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }
    onDrawnChanged: canvas.requestPaint()

    Rectangle {
        id: ring
        anchors.centerIn: parent
        width: cc.diameter; height: width; radius: width / 2
        color: cc.done ? Theme.success : (cc.hovered ? Theme.hover : "transparent")
        border.width: cc.done ? 0 : 1.5
        border.color: cc.hovered ? Theme.success : Theme.subtext
        scale: cc.pressed ? 0.88 : (cc.done && Theme.motion ? 1.0 : 1.0)
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
        Behavior on scale { NumberAnimation { duration: 90 } }
        SequentialAnimation on scale {
            running: cc.done && Theme.motion
            NumberAnimation { to: 1.18; duration: 110; easing.type: Easing.OutQuad }
            NumberAnimation { to: 1.0; duration: 160; easing.type: Easing.OutBack }
        }
    }
    Canvas {
        id: canvas
        x: ring.x; y: ring.y; width: ring.width; height: ring.height
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var p = cc.drawn
            var showHint = cc.hovered && !cc.done
            if (p <= 0 && !showHint) return
            var w = width, h = height
            var a = [w * 0.28, h * 0.52], b = [w * 0.44, h * 0.67], c = [w * 0.74, h * 0.36]
            ctx.lineWidth = Math.max(1.8, w * 0.1)
            ctx.lineCap = "round"; ctx.lineJoin = "round"
            ctx.strokeStyle = cc.done ? "white" : Theme.success
            ctx.globalAlpha = cc.done ? 1 : 0.55
            var l1 = Math.hypot(b[0] - a[0], b[1] - a[1]), l2 = Math.hypot(c[0] - b[0], c[1] - b[1])
            var len = (showHint && !cc.done ? 1 : p) * (l1 + l2)
            ctx.beginPath(); ctx.moveTo(a[0], a[1])
            if (len <= l1) {
                ctx.lineTo(a[0] + (b[0] - a[0]) * len / l1, a[1] + (b[1] - a[1]) * len / l1)
            } else {
                ctx.lineTo(b[0], b[1])
                var r = (len - l1) / l2
                ctx.lineTo(b[0] + (c[0] - b[0]) * r, b[1] + (c[1] - b[1]) * r)
            }
            ctx.stroke()
        }
        Connections { target: cc; function onHoveredChanged() { canvas.requestPaint() } }
    }
}
