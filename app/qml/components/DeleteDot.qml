import QtQuick
import QtQuick.Controls
import "../theme"

// A round X that stands in for a step's circle while its words are being edited: clicking it
// deletes. Same footprint as CheckCircle (diameter + 8) so it sits exactly where the circle was.
// It never takes focus, so clicking it doesn't end the edit first.
AbstractButton {
    id: dd
    property int diameter: 22
    property string tip: "Delete"
    implicitWidth: diameter + 8
    implicitHeight: diameter + 8
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    padding: 0
    background: Item {
        Rectangle {
            anchors.centerIn: parent
            width: dd.diameter; height: dd.diameter
            radius: width / 2
            color: dd.hovered ? Theme.hover : "transparent"
            border.width: 1.5
            border.color: dd.hovered ? Theme.textColor : Theme.subtext
        }
    }
    contentItem: Item {
        Icon { anchors.centerIn: parent; name: "close"; size: Math.round(dd.diameter * 0.45); color: dd.hovered ? Theme.textColor : Theme.subtext }
    }
    ToolTip.visible: hovered
    ToolTip.delay: 500
    ToolTip.text: tip
    Accessible.name: tip
}
