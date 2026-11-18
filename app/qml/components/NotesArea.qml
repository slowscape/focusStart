import QtQuick
import QtQuick.Controls
import "../theme"

// Notes for a task (stepId empty) or for one step. Used by Focus and the editor.
// Saves shortly after typing stops, and also when focus leaves, the task/step changes,
// the screen closes, or the window closes. (Saving only on blur lost notes: icon buttons
// and Done don't take focus, so Back or Skip destroyed the field with unsaved text.)
//
// Width: the text area is pinned to the view's width and never scrolls sideways. Left to
// itself, a ScrollView can size its content from the text's first layout (before the window
// settles), which clipped the notes on the right until the window was resized.
ScrollView {
    id: root
    property string taskId
    property string stepId: ""               // "" = the task's own notes
    property string notes                    // last saved notes for this task/step (from backend)
    property string placeholder: ""
    readonly property bool editing: area.activeFocus
    readonly property real textHeight: area.implicitHeight
    signal escaped()

    property string _ownerTask: ""           // task/step the text in the field belongs to
    property string _ownerStep: ""
    property bool _dirty: false
    property bool _loading: false

    contentWidth: availableWidth
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

    function save() {
        saveTimer.stop()
        if (_dirty && _ownerTask !== "") {
            _dirty = false
            if (_ownerStep !== "") backend.setStepNotes(_ownerTask, _ownerStep, area.text)
            else backend.setNotes(_ownerTask, area.text)
        }
    }
    function load() {
        if (_ownerTask !== taskId || _ownerStep !== stepId) save()   // never drop earlier edits
        _ownerTask = taskId
        _ownerStep = stepId
        _dirty = false
        if (area.text === notes) return       // keeps the cursor where it is
        _loading = true
        area.text = notes
        _loading = false
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

    TextArea {
        id: area
        width: root.availableWidth
        wrapMode: TextEdit.Wrap
        verticalAlignment: TextEdit.AlignTop
        placeholderText: root.placeholder
        onTextChanged: if (!root._loading) { root._dirty = true; saveTimer.restart() }
        onActiveFocusChanged: if (!activeFocus) root.save()
        Keys.onEscapePressed: { root.save(); root.escaped() }
    }
}
