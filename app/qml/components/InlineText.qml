import QtQuick
import QtQuick.Controls
import "../theme"

// Text you can edit where it is: start() swaps the label for a wrapping field with the same
// text. Enter or clicking elsewhere saves (committed), Esc cancels. Empty text is never saved.
// `richPrefix` (styled text, e.g. tag dots) shows before the text but isn't edited.
Item {
    id: it
    property string text
    property string richPrefix: ""
    property string suffix: ""             // shown after the text (e.g. a repeat mark), not edited
    property int pixelSize: Theme.fontBody
    property int weight: Font.Normal
    property color color: Theme.textColor
    property int horizontalAlignment: Text.AlignLeft
    readonly property bool editing: _editing
    readonly property alias label: label
    signal committed(string text)
    // Enter with all the text removed (only when `deleteWhenEmptied`): the caller deletes the item.
    // Clicking away from an emptied field just cancels, so text is never lost by accident.
    property bool deleteWhenEmptied: false
    signal emptied()

    property bool _editing: false

    implicitWidth: label.implicitWidth
    // Same height while editing, so rows don't jump; the box's padding spills outside instead.
    implicitHeight: _editing ? Math.max(label.implicitHeight, editor.contentHeight) : label.implicitHeight

    function _esc(s) { return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;") }
    function start() {
        editor.text = it.text
        _editing = true
        editor.forceActiveFocus()
        editor.cursorPosition = editor.text.length
    }
    function finish(save, viaEnter) {
        if (!_editing) return
        _editing = false
        var t = editor.text.trim()
        if (save && viaEnter && t === "" && deleteWhenEmptied) { it.emptied(); return }
        if (save && t !== "" && t !== it.text) it.committed(t)
    }

    Label {
        id: label
        width: parent.width
        visible: !it._editing
        textFormat: it.richPrefix !== "" ? Text.StyledText : Text.PlainText
        text: it.richPrefix !== "" ? it.richPrefix + it._esc(it.text) + it._esc(it.suffix) : it.text + it.suffix
        wrapMode: Text.Wrap
        font.pixelSize: it.pixelSize
        font.weight: it.weight
        color: it.color
        horizontalAlignment: it.horizontalAlignment
    }
    StepInput {
        id: editor
        // Text lines up with the label: the box extends left/up/down by its own padding.
        x: -leftPadding
        y: -topPadding
        width: parent.width + leftPadding
        visible: it._editing
        font.pixelSize: it.pixelSize
        font.weight: it.weight
        horizontalAlignment: it.horizontalAlignment
        onAccepted: it.finish(true, true)
        onActiveFocusChanged: if (!activeFocus) it.finish(true)
        Keys.onEscapePressed: it.finish(false)
        // Enter/Esc belong to the field while editing, not to app shortcuts (Esc = back).
        Keys.onShortcutOverride: (e) => {
            if ([Qt.Key_Escape, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space, Qt.Key_Left, Qt.Key_Right].indexOf(e.key) >= 0)
                e.accepted = true
        }
    }
}
