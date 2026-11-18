import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Compact row for Upcoming. Click opens the editor; drag the title to move the task
// (within a day, or onto another day's tasks to change its date). Titles wrap, never cut.
ItemDelegate {
    id: row
    required property string itemId
    required property string title
    required property string listId
    required property string dateLabel
    required property string plannedDate
    required property int stepTotal
    required property int stepDone
    required property bool inMyDay
    required property var tagColors
    required property var tagNames
    required property string repeat
    required property int index
    property bool showDate: false
    signal reorder(int from, int to)
    width: ListView.view ? ListView.view.width : 300
    z: drag.dragging ? 10 : 0
    transform: Translate { y: drag.offset }
    background: Rectangle {
        color: drag.dragging ? Theme.card : (drag.containsMouse || row.hovered ? Theme.hover : "transparent")
        border.color: drag.dragging ? Theme.accent : "transparent"
        radius: 6
    }

    // Drag/click area over the text (not the buttons on the right).
    ReorderArea {
        id: drag
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(0, row.width - row.rightPadding - (addBtn.visible ? addBtn.width : myDayTag.width)
                                     - moreBtn.width - 2 * Theme.s2)
        z: 2
        row: row
        view: row.ListView.view
        index: row.index
        indicator: row.ListView.view ? (row.ListView.view.dropLine || null) : null
        onTapped: appWindow.openEditor(row.itemId)
        onDropped: (from, to) => row.reorder(from, to)
    }

    contentItem: RowLayout {
        spacing: Theme.s2
        TagDots {
            colors: row.tagColors
            names: row.tagNames
            Layout.alignment: Qt.AlignTop
            Layout.topMargin: 6
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: row.title + (row.repeat !== "" ? "  ↻" : "")
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontBody
            }
            Label {
                property var bits: [
                    row.showDate && row.dateLabel ? row.dateLabel : "",
                    row.stepTotal > 0 ? (row.stepTotal - row.stepDone) + " of " + Theme.plural(row.stepTotal, "step") + " left" : ""
                ].filter(function (s) { return s !== "" })
                visible: bits.length > 0
                text: bits.join(" · ")
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
            }
        }
        IconButton {
            id: addBtn
            visible: !row.inMyDay
            icon_: "sun"; tip: "Add to My Day"
            Layout.alignment: Qt.AlignTop
            onClicked: backend.setDate(row.itemId, "today")
        }
        Label {
            id: myDayTag
            visible: row.inMyDay
            text: "My Day"
            color: Theme.accent
            font.pixelSize: Theme.fontSmall
        }
        IconButton {
            id: moreBtn
            icon_: "more"; tip: "More"
            Layout.alignment: Qt.AlignTop
            onClicked: menu.popup()
            TaskMenu { id: menu; taskId: row.itemId; listId: row.listId }
        }
    }

    ListView.onRemove: { row.ListView.delayRemove = true; removeAnim.start() }
    SequentialAnimation {
        id: removeAnim
        ParallelAnimation {
            NumberAnimation { target: row; property: "opacity"; to: 0; duration: Theme.durMed }
            NumberAnimation { target: row; property: "height"; to: 0; duration: Theme.durSlow; easing.type: Easing.InOutCubic }
        }
        PropertyAction { target: row; property: "ListView.delayRemove"; value: false }
    }
}
