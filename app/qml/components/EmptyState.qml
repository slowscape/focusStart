import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Calm empty state: the app's ring with all three segments done (green) over a softly
// breathing green halo, a title and an optional action.
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
            color: Theme.success
            opacity: 0.14
            SequentialAnimation on scale {
                running: Theme.motion; loops: Animation.Infinite
                NumberAnimation { from: 0.9; to: 1.06; duration: 2200; easing.type: Easing.InOutSine }
                NumberAnimation { from: 1.06; to: 0.9; duration: 2200; easing.type: Easing.InOutSine }
            }
        }
        StepRing {
            anchors.centerIn: parent
            width: 60; height: 60
            lineWidth: 6
            total: 3; done: 3
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
