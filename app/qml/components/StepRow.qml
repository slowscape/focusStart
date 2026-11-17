import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// One remaining step, inline in a card. Checking it: check animation + effect,
// then the row fades and collapses away (ListView remove, via delayRemove).
Item {
    id: row
    required property string itemId
    required property string text
    required property int index
    property string taskId
    property bool shown: true
    signal completed(var checkItem)

    width: ListView.view ? ListView.view.width : implicitWidth
    implicitHeight: shown ? Math.max(34, label.implicitHeight + 12) : 0
    height: implicitHeight
    visible: shown || ListView.delayRemove
    clip: true

    RowLayout {
        anchors.fill: parent
        spacing: Theme.s2
        CheckCircle {
            id: check
            diameter: 18
            Layout.alignment: Qt.AlignVCenter
            onToggledOn: row.completed(check)
        }
        Label {
            id: label
            Layout.fillWidth: true
            text: row.text
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            font.pixelSize: Theme.fontBody
        }
    }

    ListView.onRemove: { row.ListView.delayRemove = true; removeAnim.start() }
    SequentialAnimation {
        id: removeAnim
        PauseAnimation { duration: Theme.motion ? 220 : 0 }
        ParallelAnimation {
            NumberAnimation { target: row; property: "opacity"; to: 0; duration: Theme.durMed }
            NumberAnimation { target: row; property: "height"; to: 0; duration: Theme.durSlow; easing.type: Easing.InOutCubic }
        }
        PropertyAction { target: row; property: "ListView.delayRemove"; value: false }
    }
}
