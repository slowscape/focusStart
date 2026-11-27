import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Notes for a task (stepId empty) or for one step. Used by Focus and the editor.
// Two modes, switched only by the Edit / Done button beside the label (owner: editing must not
// be easy to start): reading shows the formatted notes (bold, italic, links, lines, bullets,
// tickable checkboxes); editing shows the raw text with a small formatting toolbar.
// Saves shortly after typing stops, and also when focus leaves, the task/step changes,
// the screen closes, or the window closes. (Saving only on blur lost notes: icon buttons
// and Done don't take focus, so Back or Skip destroyed the field with unsaved text.)
//
// Width: the text area is pinned to the view's width and never scrolls sideways. Left to
// itself, a ScrollView can size its content from the text's first layout (before the window
// settles), which clipped the notes on the right until the window was resized.
Item {
    id: root
    property string taskId
    property string stepId: ""               // "" = the task's own notes
    property string notes                    // last saved notes for this task/step (from backend)
    property string label: "Notes"
    property string placeholder: ""
    property bool editMode: false
    readonly property bool editing: area.activeFocus
    readonly property real headerHeight: header.implicitHeight + col.spacing
    readonly property real textHeight: editMode ? area.implicitHeight + (bar.visible ? bar.implicitHeight + col.spacing : 0)
                                                : reading.implicitHeight + area.topPadding + area.bottomPadding
    // For boxes that grow with their text: start `minLines` tall, then always keep one empty line
    // below the text (Task Notes in Focus and Edit task). Includes the label row.
    readonly property real lineHeight: lineMetrics.height
    property int minLines: 5
    readonly property real growHeight: headerHeight + Math.max(minLines * lineHeight + area.topPadding + area.bottomPadding,
                                                               textHeight + lineHeight)
    FontMetrics { id: lineMetrics; font: area.font }
    signal escaped()

    property string _ownerTask: ""           // task/step the text in the field belongs to
    property string _ownerStep: ""
    property bool _dirty: false
    property bool _loading: false

    function save() {
        saveTimer.stop()
        if (_dirty && _ownerTask !== "") {
            _dirty = false
            if (_ownerStep !== "") backend.setStepNotes(_ownerTask, _ownerStep, area.text)
            else backend.setNotes(_ownerTask, area.text)
        }
    }
    function load() {
        if (_ownerTask !== taskId || _ownerStep !== stepId) { save(); editMode = false }   // never drop earlier edits
        _ownerTask = taskId
        _ownerStep = stepId
        _dirty = false
        if (area.text === notes) return       // keeps the cursor where it is
        _loading = true
        area.text = notes
        _loading = false
    }
    function startEditing() {
        editMode = true
        area.cursorPosition = area.text.length
        area.forceActiveFocus()
    }
    function finishEditing() {
        save()
        editMode = false
    }

    Component.onCompleted: load()
    Component.onDestruction: save()
    onTaskIdChanged: { save(); Qt.callLater(load) }
    onStepIdChanged: { save(); Qt.callLater(load) }
    // A newer saved value (e.g. edited on another screen) replaces the field unless
    // there are unsaved edits for the same task/step.
    onNotesChanged: if (!_dirty || taskId !== _ownerTask || stepId !== _ownerStep) load()

    Timer { id: saveTimer; interval: 600; onTriggered: root.save() }
    Connections { target: appWindow; function onFlushEdits() { root.save() } }

    ColumnLayout {
        id: col
        anchors.fill: parent
        spacing: Theme.s1

        RowLayout {
            id: header
            Layout.fillWidth: true
            Label {
                Layout.fillWidth: true
                text: root.label
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                wrapMode: Text.Wrap
            }
            EditToggle {
                editing: root.editMode
                onClicked: root.editMode ? root.finishEditing() : root.startEditing()
            }
        }

        MarkdownToolbar {
            id: bar
            visible: root.editMode
            Layout.fillWidth: true
            target: area
        }

        // Editing: the raw text.
        ScrollView {
            id: editView
            visible: root.editMode
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            MarkdownField {
                id: area
                width: editView.availableWidth
                placeholderText: root.placeholder
                onTextChanged: if (!root._loading) { root._dirty = true; saveTimer.restart() }
                onActiveFocusChanged: if (!activeFocus) root.save()
                onEscaped: { root.finishEditing(); root.escaped() }
            }
        }

        // Reading: formatted, checkboxes tick (and save) at once.
        Rectangle {
            visible: !root.editMode
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 4
            color: Theme.card
            border.color: Theme.cardBorder
            ScrollView {
                id: readView
                anchors.fill: parent
                anchors.margins: 1
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                Item {
                    width: readView.availableWidth
                    implicitHeight: reading.implicitHeight + area.topPadding + area.bottomPadding
                    MarkdownView {
                        id: reading
                        x: area.leftPadding; y: area.topPadding
                        width: parent.width - area.leftPadding - area.rightPadding
                        blocks: root.editMode ? [] : backend.mdBlocks(area.text, false)
                        onCheckToggled: (line) => backend.toggleNotesCheck(root.taskId, root.stepId, line)
                    }
                    Label {
                        visible: area.text.trim() === ""
                        x: area.leftPadding; y: area.topPadding
                        text: "No notes"
                        color: Theme.subtext
                    }
                }
            }
        }
    }
}
