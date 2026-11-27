import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

// General notes (not tied to tasks): pinned first, then newest edited. Search filters by
// title, text and tag names as you type.
Item {
    id: screen
    property real enterOffset: 0

    function newNote() { appWindow.newNote() }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: screen.enterOffset
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s3
            Layout.topMargin: Theme.s2
            Layout.bottomMargin: Theme.s2
            Label { text: "Notes"; font.pixelSize: Theme.fontHero; font.weight: Font.DemiBold; Layout.fillWidth: true }
            IconButton { icon_: "add"; tip: "New note (Ctrl+N)"; iconColor: Theme.accent; onClicked: screen.newNote() }
        }
        TextField {
            id: search
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s3
            Layout.rightMargin: Theme.s3
            Layout.bottomMargin: Theme.s2
            visible: backend.noteCount > 0
            placeholderText: "Search notes"
            text: backend.noteQuery
            leftPadding: 32
            rightPadding: clearBtn.visible ? 34 : 10
            onTextEdited: backend.noteQuery = text
            Keys.onEscapePressed: (e) => { if (text !== "") { backend.noteQuery = ""; e.accepted = true } else e.accepted = false }
            Icon { name: "search"; size: 14; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter; x: 10 }
            IconButton {
                id: clearBtn
                visible: search.text !== ""
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: 30; implicitHeight: 30
                focusPolicy: Qt.NoFocus
                icon_: "close"; iconSize: 12; tip: "Clear search"
                onClicked: backend.noteQuery = ""
            }
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.s2
            model: backend.notesModel
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            bottomMargin: Theme.s4
            leftMargin: Theme.s3          // ListView places rows at x 0, so the side gaps go here
            rightMargin: Theme.s3
            section.property: "section"
            section.delegate: Label {
                required property string section
                text: section
                font.weight: Font.DemiBold
                color: Theme.accent
                leftPadding: Theme.s1
                topPadding: Theme.s2
                bottomPadding: Theme.s1
            }
            delegate: NoteRow {}
        }
    }

    EmptyState {
        anchors.centerIn: parent
        visible: backend.noteCount === 0
        title: "No notes yet"
        actionText: "New note"
        onAction: screen.newNote()
    }
    Label {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.s6
        visible: backend.noteCount > 0 && backend.notesModel.count === 0
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: "No notes match “" + backend.noteQuery + "”"
        color: Theme.subtext
    }
}
