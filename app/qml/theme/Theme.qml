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
    // look the same on Windows 10/11, macOS and Linux. Codes below are printed by that tool.
    readonly property FontLoader iconLoader: FontLoader { source: "../../assets/fonts/StepTaskIcons.ttf" }
    readonly property string iconFont: iconLoader.name
    readonly property bool fluentIcons: iconLoader.status === FontLoader.Ready
    readonly property var glyphs: ({
        "back":     "\uF15B",
        "next":     "\uF181",
        "play":     "\uF605",
        "pause":    "\uF5A1",
        "stop":     "\uF72A",
        "timer":    "\uED88",
        "more":     "\uE824",
        "settings": "\uF6A9",
        "print":    "\uF62A",
        "add":      "\uF109",
        "list":     "\uF4ED",
        "menu":     "\uF560",
        "sun":      "\uF8A1",
        "calendar": "\uE24E",
        "check":    "\uF294",
        "chevron":  "\uF2A3",
        "chevronR": "\uF2B0",
        "close":    "\uF369",
        "delete":   "\uF34C",
        "edit":     "\uF3DD",
        "grip":     "\uE9F8"
    })
    function glyph(name) {
        return glyphs[name] || "?"
    }

    function plural(n, word) { return n + " " + word + (n === 1 ? "" : "s") }
}
