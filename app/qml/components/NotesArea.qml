import QtQuick
import QtQuick.Controls
import "../theme"

// Task notes, used by Focus and the editor. Saves shortly after typing stops, and also
// when focus leaves, the task changes, the screen closes, or the window closes.
// (Saving only on blur lost notes: icon buttons and Done don't take focus, so clicking
// Back or Skip task destroyed the field while it still held unsaved text.)
ScrollView {
    id: root
    property string taskId
    property string notes                    // last saved notes for taskId (from backend)
    readonly property bool editing: area.activeFocus
    readonly property real textHeight: area.implicitHeight
    signal escaped()

    property string _owner: ""               // task the text in the field belongs to
    property bool _dirty: false
    property bool _loading: false

    function save() {
        saveTimer.stop()
        if (_dirty && _owner !== "") {
            _dirty = false
            backend.setNotes(_owner, area.text)
        }
    }
    function load() {
        if (_owner !== taskId) save()         // never drop the previous task's edits
        _owner = taskId
        _dirty = false
        if (area.text === notes) return       // keeps the cursor where it is
        _loading = true
        area.text = notes
        _loading = false
    }

    Component.onCompleted: load()
    Component.onDestruction: save()
    onTaskIdChanged: { save(); Qt.callLater(load) }
    // A newer saved value (e.g. edited on another screen) replaces the field unless
    // there are unsaved edits for the same task.
    onNotesChanged: if (!_dirty || taskId !== _owner) load()

    Timer { id: saveTimer; interval: 600; onTriggered: root.save() }
    Connections { target: appWindow; function onFlushEdits() { root.save() } }

    TextArea {
        id: area
        wrapMode: TextEdit.Wrap
        verticalAlignment: TextEdit.AlignTop
        onTextChanged: if (!root._loading) { root._dirty = true; saveTimer.restart() }
        onActiveFocusChanged: if (!activeFocus) root.save()
        Keys.onEscapePressed: { root.save(); root.escaped() }
    }
}
