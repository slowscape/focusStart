import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// One note in the Notes list: tag dots + title (wraps, never cut), a short preview, checklist
// progress and when it was last edited. Click opens it (reading mode); "..." pins or deletes.
Rectangle {
    id: row
    required property string itemId
    required property string title
    required property string preview
    required property string editedLabel
    required property bool pinned
    required property var tagColors
    required property var tagNames
    required property int checkDone
    required property int checkTotal
    property int index
    width: ListView.view ? ListView.view.width - ListView.view.leftMargin - ListView.view.rightMargin : 300
    implicitHeight: col.implicitHeight + 2 * Theme.s3
    radius: Theme.radius
    color: Theme.card
    border.color: mouse.containsMouse ? Theme.track : Theme.cardBorder

    function tagPrefix() {
        var out = ""
        for (var i = 0; i < row.tagColors.length; i++)
            out += '<font color="' + row.tagColors[i] + '">●</font>'
        return out === "" ? "" : out + "&nbsp;"
    }
    function esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: appWindow.go("note", { noteId: row.itemId })
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.s3
        anchors.rightMargin: Theme.s1
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s1
            Label {
                Layout.fillWidth: true
                textFormat: Text.StyledText
                text: row.tagPrefix() + row.esc(row.title)
                wrapMode: Text.Wrap
                font.weight: Font.DemiBold
                ToolTip.visible: tagHover.hovered && row.tagNames.length > 0
                ToolTip.delay: 600
                ToolTip.text: row.tagNames.join(", ")
                HoverHandler { id: tagHover }
            }
            Icon { visible: row.pinned; name: "pin"; size: 12; color: Theme.accent; Layout.alignment: Qt.AlignTop; Layout.topMargin: 3 }
            IconButton {
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: -8
                implicitWidth: 30; implicitHeight: 30
                icon_: "more"; tip: "More"
                onClicked: menu.popup()
                Menu {
                    id: menu
                    MenuItem { text: row.pinned ? "Unpin" : "Pin to top"; onTriggered: backend.setNotePinned(row.itemId, !row.pinned) }
                    MenuSeparator {}
                    MenuItem { text: "Delete"; onTriggered: appWindow.confirmDeleteNote(row.itemId, row.title) }
                }
            }
        }
        Label {
            Layout.fillWidth: true
            Layout.rightMargin: Theme.s2
            visible: row.preview !== ""
            text: row.preview
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: Theme.s2
            spacing: Theme.s2
            Label {
                visible: row.checkTotal > 0
                text: row.checkDone + " of " + row.checkTotal + " checked"
                color: row.checkDone === row.checkTotal ? Theme.success : Theme.subtext
                font.pixelSize: Theme.fontSmall
            }
            Item { Layout.fillWidth: true }
            Label { text: row.editedLabel; color: Theme.subtext; font.pixelSize: Theme.fontSmall }
        }
    }
}
