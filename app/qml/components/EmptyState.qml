import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Calm empty state: a softly breathing check, a title and an optional action.
ColumnLayout {
    id: es
    property string title: "All clear"
    property string actionText: ""
    signal action()
    spacing: Theme.s2

    Item {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: 96; implicitHeight: 96
        Rectangle {
            id: halo
            anchors.centerIn: parent
            width: 88; height: 88; radius: 44
            color: Theme.accent
            opacity: 0.10
            SequentialAnimation on scale {
                running: Theme.motion; loops: Animation.Infinite
                NumberAnimation { from: 0.9; to: 1.06; duration: 2200; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.06; to: 0.9; duration: 2200; easing.type: Easing.InOutSine }
            }
        }
        Rectangle {
            anchors.centerIn: parent
            width: 56; height: 56; radius: 28
            color: Theme.accent
            opacity: 0.9
            Icon { anchors.centerIn: parent; name: "check"; size: 24; color: "white" }
        }
    }
    Label {
        Layout.alignment: Qt.AlignHCenter
        text: es.title
        font.pixelSize: Theme.fontTitle
        font.weight: Font.DemiBold
    }
    Button {
        Layout.alignment: Qt.AlignHCenter
        visible: es.actionText !== ""
        text: es.actionText
        flat: true
        onClicked: es.action()
    }
}
