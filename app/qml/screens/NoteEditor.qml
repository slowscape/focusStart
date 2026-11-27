import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

// One note. Opens in reading mode (formatted, checkboxes tick, links open); the pencil switches
// to editing (raw text + formatting toolbar), Done or Esc switch back. A new note opens editing.
// Saves as you type (debounced), on Done, on leaving and on window close. Leaving a note
// that is completely empty deletes it, so a stray "New note" leaves nothing behind.
Item {
    id: screen
    property string noteId
    property bool startEditing: false
    property bool editMode: false
    property var info: (backend.revision, backend.noteInfo(noteId))
    property bool _dirty: false
    property bool _loading: false

    onInfoChanged: if (info && !info.exists) appWindow.back()

    function save() {
        saveTimer.stop()
        if (_dirty && info.exists) {
            _dirty = false
            backend.setNoteBody(noteId, field.text)
        }
    }
    function edit() {
        _loading = true
        field.text = info.body || ""
        _loading = false
        _dirty = false
        editMode = true
        field.cursorPosition = field.text.length
        field.forceActiveFocus()
    }
    function finishEditing() {
        save()
        editMode = false
        screen.forceActiveFocus()
    }

    Component.onCompleted: if (startEditing) edit()
    Component.onDestruction: { save(); backend.dropNoteIfEmpty(noteId) }
    Timer { id: saveTimer; interval: 600; onTriggered: screen.save() }
    Connections { target: appWindow; function onFlushEdits() { screen.save() } }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.s2
            spacing: 0
            IconButton { icon_: "back"; tip: "Back (Esc)"; onClicked: { screen.save(); appWindow.back() } }
            Label {
                Layout.fillWidth: true
                leftPadding: Theme.s1
                text: screen.info.editedLabel ? "Edited " + screen.info.editedLabel : ""
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.Wrap
            }
            IconButton {
                icon_: "pin"
                tip: screen.info.pinned ? "Unpin" : "Pin to top"
                iconColor: screen.info.pinned ? Theme.accent : Theme.subtext
                onClicked: backend.setNotePinned(screen.noteId, !screen.info.pinned)
            }
            IconButton {
                visible: !screen.editMode
                icon_: "edit"; tip: "Edit"
                onClicked: screen.edit()
            }
            EditToggle {
                visible: screen.editMode
                editing: true
                implicitHeight: 36
                onClicked: screen.finishEditing()
            }
            IconButton {
                icon_: "more"; tip: "More"
                onClicked: menu.popup()
                Menu {
                    id: menu
                    MenuItem { text: "Delete"; onTriggered: appWindow.confirmDeleteNote(screen.noteId, screen.info.title || "") }
                }
            }
        }

        // Tags: all of them (tap to add/remove) while editing; only the note's own while reading.
        Flow {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            Layout.bottomMargin: Theme.s2
            spacing: Theme.s2
            visible: screen.editMode ? backend.tagsModel.count > 0 : (screen.info.tagIds || []).length > 0
            Repeater {
                model: backend.tagsModel
                Chip {
                    required property string itemId
                    required property string name
                    required property string color
                    readonly property bool on: (screen.info.tagIds || []).indexOf(itemId) >= 0
                    visible: screen.editMode || on
                    compact: true
                    checkable: false
                    enabled: screen.editMode
                    focusPolicy: Qt.NoFocus
                    fill: on ? Qt.rgba(Qt.color(color).r, Qt.color(color).g, Qt.color(color).b, 0.45) : Theme.track
                    text: (on && screen.editMode ? "✓ " : "") + "#" + name
                    onClicked: {
                        var ids = (screen.info.tagIds || []).slice()
                        if (on) ids.splice(ids.indexOf(itemId), 1); else ids.push(itemId)
                        backend.setNoteTags(screen.noteId, ids)
                    }
                }
            }
        }

        MarkdownToolbar {
            visible: screen.editMode
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s3
            Layout.rightMargin: Theme.s3
            Layout.bottomMargin: Theme.s1
            target: field
        }

        // Editing: the raw text; the first line is the title.
        ScrollView {
            id: editView
            visible: screen.editMode
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.s3
            Layout.rightMargin: Theme.s3
            Layout.bottomMargin: Theme.s3
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            MarkdownField {
                id: field
                width: editView.availableWidth
                placeholderText: "Title on the first line, then your note"
                onTextChanged: if (!screen._loading) { screen._dirty = true; saveTimer.restart() }
                onActiveFocusChanged: if (!activeFocus) screen.save()
                onEscaped: screen.finishEditing()
            }
        }

        // Reading: formatted; ticking a box saves at once.
        ScrollView {
            id: readView
            visible: !screen.editMode
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            Item {
                width: readView.availableWidth
                implicitHeight: reading.implicitHeight + Theme.s6
                MarkdownView {
                    id: reading
                    x: Theme.s4
                    width: parent.width - 2 * Theme.s4
                    blocks: screen.info.blocks || []
                    onCheckToggled: (line) => backend.toggleNoteCheck(screen.noteId, line)
                }
                Label {
                    visible: (screen.info.body || "").trim() === ""
                    x: Theme.s4
                    width: parent.width - 2 * Theme.s4
                    wrapMode: Text.Wrap
                    text: "This note is empty. Tap the pencil to write."
                    color: Theme.subtext
                }
            }
        }
    }
}
