import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Compact row for Upcoming and Lists. Tap opens the editor.
ItemDelegate {
    id: row
    required property string itemId
    required property string title
    required property string listId
    required property string dateLabel
    required property int stepTotal
    required property int stepDone
    required property bool inMyDay
    property bool showDate: false
    width: ListView.view ? ListView.view.width : 300
    onClicked: appWindow.openEditor(itemId)

    contentItem: RowLayout {
        spacing: Theme.s2
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Label {
                Layout.fillWidth: true
                text: row.title
                elide: Text.ElideRight
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
            visible: !row.inMyDay
            icon_: "sun"; tip: "Add to My Day"
            onClicked: backend.setDate(row.itemId, "today")
        }
        Label {
            visible: row.inMyDay
            text: "My Day"
            color: Theme.accent
            font.pixelSize: Theme.fontSmall
        }
        IconButton {
            icon_: "more"; tip: "More"
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
