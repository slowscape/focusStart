import QtQuick
import QtQuick.Controls
import "../theme"

// Coloured dots for a task's tags, shown just before its title. Hover shows the names.
Row {
    id: dots
    property var colors: []
    property var names: []
    spacing: 3
    visible: colors.length > 0
    Repeater {
        model: dots.colors
        Rectangle {
            required property var modelData
            anchors.verticalCenter: parent.verticalCenter
            width: 8; height: 8; radius: 4
            color: modelData
        }
    }
    HoverHandler { id: hover }
    ToolTip.visible: hover.hovered && dots.names.length > 0
    ToolTip.delay: 400
    ToolTip.text: dots.names.join(", ")
}
