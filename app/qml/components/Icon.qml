import QtQuick
import "../theme"

Text {
    property string name
    property int size: 16
    text: Theme.glyph(name)
    font.family: Theme.iconFont
    font.pixelSize: Theme.fluentIcons ? size : size + 2
    color: Theme.textColor
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
