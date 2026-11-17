pragma Singleton
import QtQuick

QtObject {
    // Set from Main.qml (follows the system palette/accent).
    property color accent: "#0067c0"
    property color windowColor: "#f3f3f3"
    property color textColor: "#1a1a1a"
    readonly property bool dark: windowColor.hslLightness < 0.5

    readonly property color subtext: dark ? Qt.rgba(1, 1, 1, 0.62) : Qt.rgba(0, 0, 0, 0.58)
    readonly property color card: dark ? Qt.rgba(1, 1, 1, 0.055) : Qt.rgba(1, 1, 1, 0.75)
    readonly property color cardBorder: dark ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)
    readonly property color hover: dark ? Qt.rgba(1, 1, 1, 0.06) : Qt.rgba(0, 0, 0, 0.04)
    readonly property color track: dark ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.08)
    // Green is reserved for completion effects.
    readonly property color success: dark ? "#6ccb5f" : "#0f7b0f"
    readonly property color successSoft: dark ? "#3a6b34" : "#c8e8c3"
    readonly property color scrim: Qt.rgba(0, 0, 0, dark ? 0.55 : 0.32)

    // 8 px grid
    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s5: 20
    readonly property int s6: 24
    readonly property int radius: 8

    // Motion (150-250 ms). "off" effects = still.
    property string effects: "full"
    readonly property bool motion: effects !== "off"
    readonly property bool particles: effects === "full"
    readonly property int durFast: motion ? 150 : 0
    readonly property int durMed: motion ? 200 : 0
    readonly property int durSlow: motion ? 250 : 0

    readonly property int fontSmall: 12
    readonly property int fontBody: 14
    readonly property int fontTitle: 20
    readonly property int fontHero: 26

    // Icons: Segoe Fluent Icons ships with Windows 11; fall back to Unicode elsewhere.
    readonly property bool fluentIcons: Qt.fontFamilies().indexOf("Segoe Fluent Icons") >= 0
    readonly property string iconFont: fluentIcons ? "Segoe Fluent Icons" : ""
    readonly property var glyphs: ({
        "back":     ["", "←"],
        "play":     ["", "▶"],
        "more":     ["", "⋯"],
        "settings": ["", "⚙"],
        "add":      ["", "+"],
        "sun":      ["", "☀"],
        "calendar": ["", "\u{1F4C5}"],
        "delete":   ["", "✕"],
        "up":       ["", "↑"],
        "down":     ["", "↓"],
        "close":    ["", "✕"],
        "edit":     ["", "✎"],
        "check":    ["", "✓"],
        "skip":     ["", "↷"],
        "next":     ["", "→"],
        "chevron":  ["", "▾"],
        "chevronR": ["", "▸"],
        "folder":   ["", "\u{1F4C2}"],
        "list":     ["", "☰"],
        "restore":  ["", "↺"],
        "menu":     ["\uE700", "\u2630"],
        "pause":    ["\uE769", "\u275A\u275A"],
        "power":    ["\uE7E8", "\u23FB"],
        "timer":    ["\uE916", "\u23F1"],
        "grip":     ["\uE76F", "\u2261"],
        "print":    ["\uE749", "\u2399"]
    })
    function glyph(name) {
        var g = glyphs[name]
        if (!g) return "?"
        return fluentIcons ? g[0] : g[1]
    }

    function plural(n, word) { return n + " " + word + (n === 1 ? "" : "s") }
}
