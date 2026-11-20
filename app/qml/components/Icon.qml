import QtQuick
import "../theme"

// One icon from the bundled Fluent font, with its visible shape centred in a size x size square.
// Qt mis-measures this font in opposite ways per axis, so each axis uses what's reliable:
//  - horizontal: Qt's own ink box (TextMetrics), since Qt draws the glyph without its left margin;
//  - vertical: the ink centre read from the font's outlines (Theme.glyphCentre, written by
//    tools/subset_icons.py); Qt's vertical box put icons a few px high.
// Fluent glyphs fill ~70-85% of the em, so they're drawn ~30% larger.
Item {
    id: icon
    property string name
    property int size: 16
    property color color: Theme.textColor
    readonly property var centre: Theme.glyphCentre(name)
    implicitWidth: size
    implicitHeight: size

    TextMetrics { id: ink; font: label.font; text: label.text }
    Text {
        id: label
        text: Theme.glyph(icon.name)
        font.family: Theme.iconFont
        font.pixelSize: Math.round(icon.size * 1.3)
        color: icon.color
        x: icon.width / 2 - (ink.tightBoundingRect.x + ink.tightBoundingRect.width / 2)
        // Ink centre: centre[1] em above the baseline (label.baselineOffset from this Text's top).
        y: icon.height / 2 - (label.baselineOffset - icon.centre[1] * font.pixelSize)
    }
}
