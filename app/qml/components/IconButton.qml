import QtQuick
import QtQuick.Controls
import "../theme"

ToolButton {
    id: b
    property string icon_: ""
    property string tip: ""
    property int iconSize: 16
    property color iconColor: Theme.textColor
    focusPolicy: Qt.TabFocus
    implicitWidth: 36
    implicitHeight: 36
    contentItem: Icon { name: b.icon_; size: b.iconSize; color: b.iconColor; opacity: b.enabled ? 1 : 0.4 }
    ToolTip.visible: tip !== "" && hovered
    ToolTip.delay: 600
    ToolTip.text: tip
    Accessible.name: tip
}
