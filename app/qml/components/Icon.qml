import QtQuick
import "../theme"

Text {
    property string name
    property int size: 16
    text: Theme.glyph(name)
    font.family: Theme.iconFont
    font.pixelSize: size
    color: Theme.textColor
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
