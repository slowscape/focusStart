import QtQuick
import "../theme"

// Segmented ring: one segment per step, filled segments = done.
Canvas {
    id: ring
    property int total: 0
    property int done: 0
    property real shown: done
    implicitWidth: 26
    implicitHeight: 26
    Behavior on shown { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutCubic } }
    onShownChanged: requestPaint()
    onTotalChanged: requestPaint()
    Connections { target: Theme; function onAccentChanged() { ring.requestPaint() } function onWindowColorChanged() { ring.requestPaint() } }
    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        if (total <= 0) return
        var cx = width / 2, cy = height / 2, r = Math.min(width, height) / 2 - 2.5
        var gap = total > 1 ? Math.min(0.35, 1.2 / total) : 0
        var seg = (Math.PI * 2) / total
        ctx.lineWidth = 3
        ctx.lineCap = "butt"
        for (var i = 0; i < total; i++) {
            var start = -Math.PI / 2 + i * seg + gap / 2
            var end = start + seg - gap
            var f = Math.max(0, Math.min(1, shown - i))
            ctx.strokeStyle = Theme.track
            ctx.beginPath(); ctx.arc(cx, cy, r, start, end); ctx.stroke()
            if (f > 0) {
                ctx.strokeStyle = Theme.success
                ctx.beginPath(); ctx.arc(cx, cy, r, start, start + (end - start) * f); ctx.stroke()
            }
        }
    }
}
