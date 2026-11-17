import QtQuick
import QtQuick.Particles
import "../theme"

// Window-wide particle layer. One ParticleSystem; it only runs while effects play.
// ImageParticle colours are fixed per painter (changing them at runtime doesn't recolour
// reliably), so each colour family x shape gets its own painter + emitter.
Item {
    id: fx
    readonly property string img: Qt.resolvedUrl("../../assets/images/")
    readonly property var shapes: ["rect", "circle", "tri", "strip", "star"]
    readonly property var families: [
        ["#ff5c8a", "#ffc93c", "#2ec4b6", "#ff9f1c", "#f15bb5"],   // warm/pop
        ["#7b61ff", "#00b4d8", "#3ddc97", "#6c63ff", "#4cc9f0"],   // cool
        ["#fee440", "#ff7f50", "#43aa8b", "#e76f51", "#90be6d"]    // sunny
    ]
    // Which shapes each task variant uses (variety so it doesn't become wallpaper).
    readonly property var variantShapes: [[0, 1], [2, 3], [1, 4], [3, 0]]
    readonly property var combos: {
        var out = []
        for (var f = 0; f < families.length; f++)
            for (var s = 0; s < shapes.length; s++)
                out.push({ fam: f, shape: s, group: "c" + f + "_" + s, color: families[f][s] })
        return out
    }

    function wake() { if (sys.paused) sys.paused = false; idle.restart() }
    function emitterFor(fam, shape) { return emitters.itemAt(fam * shapes.length + shape) }

    function pop(x, y, variant) {
        wake()
        popEm.burst(variant === 2 ? 16 : 12, x, y)
        sparkEm.burst(variant === 1 ? 6 : 3, x, y)
    }

    function confetti(x, y, w, h, variant, big) {
        wake()
        var fam = variant % families.length
        var list = variantShapes[variant % variantShapes.length].slice()
        if (big) list.push(4)
        var n = big ? 24 : 16
        for (var i = 0; i < list.length; i++) {
            var e = emitterFor(fam, list[i])
            e.x = x; e.y = y + h * 0.5; e.width = w; e.height = Math.max(4, h * 0.4)
            e.velocity = cardVelocity
            e.burst(n)
        }
    }

    function dayConfetti() {
        wake()
        wave.count = 0
        wave.restart()
    }

    Timer {
        id: wave
        property int count: 0
        interval: 450; repeat: true; triggeredOnStart: true
        onTriggered: {
            fx.wake()
            for (var i = 0; i < fx.combos.length; i++) {
                var e = emitters.itemAt(i)
                e.x = 0; e.y = fx.height - 8; e.width = fx.width; e.height = 8
                e.velocity = dayVelocity
                e.burst(Math.round(5 + fx.width / 120))
            }
            count += 1
            if (count >= 3) stop()
        }
    }
    Timer { id: idle; interval: 3500; onTriggered: sys.paused = true }

    // Each ImageParticle only colours particles after its first use, so prime every
    // painter once, off-screen, shortly after startup.
    Timer {
        id: prime
        interval: 250; running: true
        onTriggered: {
            fx.wake()
            popEm.burst(1, -60, -60)
            sparkEm.burst(1, -60, -60)
            for (var i = 0; i < emitters.count; i++) emitters.itemAt(i).burst(1, -60, -60)
        }
    }

    ParticleSystem { id: sys; anchors.fill: parent; paused: true }   // paused while idle: no CPU

    AngleDirection { id: cardVelocity; angle: 270; angleVariation: 55; magnitude: 330; magnitudeVariation: 150 }
    AngleDirection { id: dayVelocity; angle: 270; angleVariation: 22; magnitude: 760; magnitudeVariation: 240 }

    // Step pop: small green dots plus a few accent sparks.
    ImageParticle {
        system: sys; groups: ["pop"]
        source: fx.img + "p_dot.png"; color: Theme.success; colorVariation: 0.08
        alpha: 0.95; entryEffect: ImageParticle.Scale
    }
    ImageParticle {
        system: sys; groups: ["spark"]
        source: fx.img + "p_star.png"; color: Theme.accent; colorVariation: 0.1
        rotationVariation: 180; entryEffect: ImageParticle.Scale
    }
    Emitter {
        id: popEm; system: sys; group: "pop"; enabled: false
        lifeSpan: 420; lifeSpanVariation: 120
        size: 9; sizeVariation: 4; endSize: 1
        velocity: AngleDirection { angleVariation: 180; magnitude: 110; magnitudeVariation: 45 }
    }
    Emitter {
        id: sparkEm; system: sys; group: "spark"; enabled: false
        lifeSpan: 520; size: 10; endSize: 2
        velocity: AngleDirection { angleVariation: 180; magnitude: 70; magnitudeVariation: 30 }
    }

    // Confetti painters and emitters (families x shapes).
    Repeater {
        model: fx.combos
        ImageParticle {
            required property var modelData
            system: sys
            groups: [modelData.group]
            source: fx.img + "p_" + fx.shapes[modelData.shape] + ".png"
            color: modelData.color
            colorVariation: 0.12
            rotationVariation: modelData.shape === 1 ? 0 : 180
            rotationVelocityVariation: modelData.shape === 1 ? 0 : 420
        }
    }
    Repeater {
        id: emitters
        model: fx.combos
        Emitter {
            required property var modelData
            system: sys
            group: modelData.group
            enabled: false
            lifeSpan: 1700; lifeSpanVariation: 400
            size: [10, 7, 9, 12, 11][modelData.shape]
            sizeVariation: 3
        }
    }
    Gravity { system: sys; groups: fx.combos.map(function (c) { return c.group }); angle: 90; magnitude: 620 }
    Friction { system: sys; groups: fx.combos.map(function (c) { return c.group }); factor: 0.9 }
}
