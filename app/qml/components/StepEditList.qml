import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Editable list of a task's remaining steps: text wraps and the row grows;
// drag the grip to reorder (Alt+Up/Alt+Down while editing does the same).
// Done steps aren't shown here and never move.
ListView {
    id: list
    property string taskId
    property bool scrollable: true
    property int dragFrom: -1
    property int dropIndex: -1
    model: backend.stepModel(taskId)
    interactive: scrollable
    implicitHeight: contentHeight
    clip: scrollable
    spacing: 2
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar { visible: list.scrollable }

    function targetIndexFor(item) {
        var p = item.mapToItem(list.contentItem, 0, item.height / 2)
        var idx = list.indexAt(10, p.y)
        if (idx < 0) idx = p.y < 0 ? 0 : list.count - 1
        return idx
    }

    delegate: Item {
        id: row
        required property string itemId
        required property string text
        required property int index
        width: list.width
        height: content.height
        z: dragArea.drag.active ? 10 : 0

        // Drop indicator line (above or below this row).
        Rectangle {
            visible: list.dragFrom >= 0 && list.dropIndex === row.index && list.dropIndex !== list.dragFrom
            width: parent.width; height: 2; radius: 1
            color: Theme.accent
            y: list.dropIndex < list.dragFrom ? -2 : parent.height
        }

        Rectangle {
            id: content
            width: row.width
            height: rowLayout.implicitHeight + 6
            radius: Theme.radius
            color: dragArea.drag.active ? (Theme.dark ? "#333333" : "#ffffff") : "transparent"
            border.color: dragArea.drag.active ? Theme.cardBorder : "transparent"
            opacity: dragArea.drag.active ? 0.95 : 1

            RowLayout {
                id: rowLayout
                anchors.left: parent.left; anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.s1
                Item {
                    implicitWidth: 22
                    Layout.fillHeight: true
                    Layout.minimumHeight: 30
                    Icon {
                        anchors.centerIn: parent
                        name: "grip"; size: 14
                        color: dragArea.containsMouse || dragArea.drag.active ? Theme.textColor : Theme.subtext
                    }
                    MouseArea {
                        id: dragArea
                        objectName: "dragHandle_" + row.index
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        preventStealing: true
                        drag.target: content
                        drag.axis: Drag.YAxis
                        onPressed: { list.dragFrom = row.index; list.dropIndex = row.index }
                        onPositionChanged: if (drag.active) list.dropIndex = list.targetIndexFor(content)
                        onReleased: {
                            var to = list.dropIndex
                            content.y = 0
                            list.dragFrom = -1; list.dropIndex = -1
                            if (to >= 0 && to !== row.index) backend.moveStep(list.taskId, row.itemId, to)
                        }
                        onCanceled: { content.y = 0; list.dragFrom = -1; list.dropIndex = -1 }
                        ToolTip.visible: containsMouse && !drag.active
                        ToolTip.delay: 700
                        ToolTip.text: "Drag to reorder"
                    }
                }
                Label { text: (row.index + 1) + "."; color: Theme.subtext; Layout.preferredWidth: 20; Layout.alignment: Qt.AlignTop; Layout.topMargin: 6 }
                StepInput {
                    id: edit
                    Layout.fillWidth: true
                    text: row.text
                    function commit() {
                        var t = text.trim()
                        if (t && t !== row.text) backend.editStep(list.taskId, row.itemId, t)
                        else if (!t) text = row.text
                    }
                    onActiveFocusChanged: if (!activeFocus) commit()
                    onAccepted: { commit(); list.forceActiveFocus() }
                    Keys.onUpPressed: (e) => {
                        if (e.modifiers & Qt.AltModifier && row.index > 0) { commit(); backend.moveStep(list.taskId, row.itemId, row.index - 1) }
                        else e.accepted = false
                    }
                    Keys.onDownPressed: (e) => {
                        if (e.modifiers & Qt.AltModifier && row.index < list.count - 1) { commit(); backend.moveStep(list.taskId, row.itemId, row.index + 1) }
                        else e.accepted = false
                    }
                }
                IconButton {
                    icon_: "close"; tip: "Remove step"; iconSize: 12
                    Layout.alignment: Qt.AlignTop
                    onClicked: backend.deleteStep(list.taskId, row.itemId)
                }
            }
        }
    }
    add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durMed } }
    remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Theme.durFast } }
    move: Transition { NumberAnimation { properties: "y"; duration: Theme.durMed; easing.type: Easing.OutCubic } }
    displaced: Transition { NumberAnimation { properties: "y"; duration: Theme.durMed; easing.type: Easing.OutCubic } }
}
