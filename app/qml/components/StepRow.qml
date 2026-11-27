import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// One remaining step, inline in a card. Checking it: check animation + effect,
// then the row fades and collapses away (ListView remove, via delayRemove).
// The whole step text is shown (wraps, never cut short). Click the text to edit it in
// place; drag it to reorder.
Item {
    id: row
    required property string itemId
    required property string text
    required property int index
    property string taskId
    signal completed(var checkItem)
    signal reorder(int from, int to)

    width: ListView.view ? ListView.view.width : implicitWidth
    implicitHeight: Math.max(34, label.implicitHeight + 12)
    height: implicitHeight
    clip: true
    transform: Translate { y: drag.offset }

    RowLayout {
        anchors.fill: parent
        spacing: Theme.s2
        CheckCircle {
            id: check
            visible: !label.editing
            diameter: 18
            Layout.alignment: Qt.AlignVCenter
            onToggledOn: row.completed(check)
        }
        // While editing, the circle turns into an X: click it to delete the step.
        DeleteDot {
            visible: label.editing
            diameter: 18
            tip: "Delete step"
            Layout.alignment: Qt.AlignVCenter
            onClicked: backend.deleteStep(row.taskId, row.itemId)
        }
        InlineText {
            id: label
            Layout.fillWidth: true
            text: row.text
            pixelSize: Theme.fontBody
            color: drag.dragging ? Theme.accent : Theme.textColor
            onCommitted: (t) => backend.editStep(row.taskId, row.itemId, t)
            deleteWhenEmptied: true
            onEmptied: backend.deleteStep(row.taskId, row.itemId)
            ReorderArea {
                id: drag
                anchors.fill: parent
                enabled: !label.editing
                cursorShape: dragging ? Qt.ClosedHandCursor : Qt.IBeamCursor
                onTapped: label.start()
                row: row
                view: row.ListView.view
                index: row.index
                indicator: row.ListView.view ? row.ListView.view.dropLine || null : null
                onDropped: (from, to) => row.reorder(from, to)
            }
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
