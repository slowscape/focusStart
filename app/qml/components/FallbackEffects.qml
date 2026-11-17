import QtQuick
import "../theme"

// Used only if QtQuick.Particles can't be loaded: simple animated rectangles.
Item {
    id: fx
    readonly property var colors: ["#ff5c8a", "#ffc93c", "#2ec4b6", "#7b61ff", "#ff9f1c", "#00b4d8"]

    Component {
        id: bit
        Rectangle {
            id: r
            property real vx: 0
            property real vy: 0
            property int life: 900
            width: 8; height: 8; radius: 2
            ParallelAnimation {
                running: true
                NumberAnimation { target: r; property: "x"; to: r.x + r.vx; duration: r.life; easing.type: Easing.OutQuad }
                NumberAnimation { target: r; property: "y"; to: r.y + r.vy; duration: r.life; easing.type: Easing.InQuad }
                NumberAnimation { target: r; property: "rotation"; to: 360 * (Math.random() - 0.5) * 2; duration: r.life }
                NumberAnimation { target: r; property: "opacity"; to: 0; duration: r.life; easing.type: Easing.InQuad }
                onFinished: r.destroy()
            }
        }
    }

    function spray(x, y, w, n, spread, rise, life) {
        for (var i = 0; i < n; i++) {
            bit.createObject(fx, {
                x: x + Math.random() * w, y: y,
                vx: (Math.random() - 0.5) * spread, vy: rise * (0.4 + Math.random()),
                color: colors[Math.floor(Math.random() * colors.length)],
                radius: Math.random() < 0.5 ? 4 : 1, life: life
            })
        }
    }
    function pop(x, y, variant) { spray(x - 4, y - 4, 0, 8, 60, -40, 450) }
    function confetti(x, y, w, h, variant, big) { spray(x, y + h * 0.6, w, big ? 30 : 18, 160, 120, 1100) }
    function dayConfetti() {
        spray(0, 0, width, 40, 200, height * 0.9, 1800)
        waveTimer.n = 1; waveTimer.restart()
    }
    Timer {
        id: waveTimer; property int n: 0; interval: 420; repeat: true
        onTriggered: { fx.spray(0, 0, fx.width, 40, 200, fx.height * 0.9, 1800); if (++n >= 3) stop() }
    }
}
