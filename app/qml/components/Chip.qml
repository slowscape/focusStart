import QtQuick
import QtQuick.Controls
import "../theme"

// Small pill. Checkable chips use the accent when on.
AbstractButton {
    id: c
    property bool tone: false        // static (non-interactive) look
    property color fill: checked ? Theme.accent : Theme.track
    property bool compact: false     // smaller badge (My Day "Done" counts)
    implicitHeight: compact ? 22 : 28
    implicitWidth: label.implicitWidth + 2 * (compact ? Theme.s2 : Theme.s3)
    hoverEnabled: !tone
    focusPolicy: tone ? Qt.NoFocus : Qt.TabFocus
    background: Rectangle {
        radius: height / 2
        color: c.fill
        opacity: c.hovered && !c.checked ? 0.8 : 1
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }
    contentItem: Label {
        id: label
        text: c.text
        font.pixelSize: c.compact ? Theme.fontSmall - 1 : Theme.fontSmall
        font.weight: Font.DemiBold
        color: c.checked ? "white" : Theme.textColor
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        verticalAlignment: Text.AlignVCenter
    }
}
