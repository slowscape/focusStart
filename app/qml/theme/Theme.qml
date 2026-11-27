pragma Singleton
import QtQuick

QtObject {
    // Set from Main.qml (follows the system palette/accent).
    property color accent: "#0067c0"
    property color windowColor: "#f3f3f3"
    property color textColor: "#1a1a1a"
    readonly property bool dark: windowColor.hslLightness < 0.5

    readonly property color subtext: dark ? Qt.rgba(1, 1, 1, 0.62) : Qt.rgba(0, 0, 0, 0.58)
    // Cards are solid everywhere. Only My Day's cards are very slightly see-through (like
    // Microsoft To Do over its background picture); on hover they turn fully solid.
    readonly property color card: dark ? "#2b2b2b" : "#ffffff"
    readonly property color cardSoft: dark ? Qt.rgba(0.169, 0.169, 0.169, 0.93) : Qt.rgba(1, 1, 1, 0.93)
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

    // Icons: Microsoft's Fluent UI System Icons (MIT), bundled as a small font holding only the
    // icons we use (app/assets/fonts/StepTaskIcons.ttf, built by tools/subset_icons.py), so they
    // look the same on Windows 10/11, macOS and Linux. The table below is printed by that tool.
    readonly property FontLoader iconLoader: FontLoader { source: "../../assets/fonts/StepTaskIcons.ttf" }
    readonly property string iconFont: iconLoader.name
    readonly property bool fluentIcons: iconLoader.status === FontLoader.Ready
    readonly property var glyphs: ({
        "back":     ["\uF15B", 0.499, 0.500],
        "next":     ["\uF181", 0.500, 0.500],
        "play":     ["\uF605", 0.575, 0.500],
        "pause":    ["\uF5A1", 0.500, 0.500],
        "stop":     ["\uF72A", 0.500, 0.500],
        "timer":    ["\uED88", 0.482, 0.500],
        "more":     ["\uE824", 0.500, 0.500],
        "settings": ["\uF6A9", 0.500, 0.500],
        "print":    ["\uF62A", 0.500, 0.500],
        "add":      ["\uF109", 0.501, 0.501],
        "list":     ["\uF4ED", 0.500, 0.525],
        "menu":     ["\uF560", 0.500, 0.525],
        "sun":      ["\uF8A1", 0.499, 0.500],
        "calendar": ["\uE24E", 0.500, 0.500],
        "check":    ["\uF294", 0.512, 0.512],
        "chevron":  ["\uF2A3", 0.498, 0.464],
        "chevronR": ["\uF2B0", 0.537, 0.500],
        "close":    ["\uF369", 0.500, 0.500],
        "delete":   ["\uF34C", 0.500, 0.513],
        "edit":     ["\uF3DD", 0.499, 0.499],
        "grip":     ["\uE9F8", 0.500, 0.500],
        "history":  ["\uF47E", 0.503, 0.499],
        "search":   ["\uF68F", 0.520, 0.480],
        "pin":      ["\uF601", 0.525, 0.526],
        "pinOff":   ["\uF603", 0.500, 0.500],
        "bold":     ["\uF7A4", 0.513, 0.500],
        "italic":   ["\uF7F4", 0.501, 0.500],
        "link":     ["\uF4E4", 0.500, 0.500],
        "rule":     ["\uF4E0", 0.500, 0.525],
        "bullets":  ["\uECD9", 0.500, 0.526],
        "checkbox": ["\uF291", 0.500, 0.500]
    })
    // [character, ink centre x, ink centre y up from the baseline] per icon (fractions of the em).
    function glyph(name) {
        return glyphs[name] ? glyphs[name][0] : "?"
    }
    function glyphCentre(name) {
        return glyphs[name] ? [glyphs[name][1], glyphs[name][2]] : [0.5, 0.5]
    }

    function plural(n, word) { return n + " " + word + (n === 1 ? "" : "s") }
}
