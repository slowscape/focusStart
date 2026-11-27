import QtQuick
import QtQuick.Controls
import "../theme"

// The editing box for notes (Notes tab, Task Notes, Step Notes): plain text, wraps.
// Lists continue on Enter: a line starting "- " / "* " starts the next line with the same marker,
// a checkbox line ("[ ] " or "[x] ") starts the next with "[ ] "; Enter on an empty item ends the
// list. Shift+Enter is a plain new line. Esc emits escaped().
TextArea {
    id: field
    signal escaped()
    wrapMode: TextEdit.Wrap
    verticalAlignment: TextEdit.AlignTop
    Keys.onEscapePressed: field.escaped()
    Keys.onShortcutOverride: (e) => { if (e.key === Qt.Key_Escape) e.accepted = true }
    Keys.onPressed: (e) => {
        if ((e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter) || (e.modifiers & Qt.ShiftModifier)) return
        if (field.selectedText !== "") return
        var pos = field.cursorPosition
        var start = field.text.lastIndexOf("\n", pos - 1) + 1
        var line = field.text.substring(start, pos)
        var check = line.match(/^(\s*)\[( |x|X)\] ?(.*)$/)
        var bullet = check ? null : line.match(/^(\s*)([-*]) (.*)$/)
        if (!check && !bullet) return
        e.accepted = true
        var rest = check ? check[3] : bullet[3]
        if (rest.trim() === "" && field.text.substring(pos, pos + 1).match(/^(\n|)$/)) {
            field.remove(start, pos)                  // empty item: end the list here
            return
        }
        field.insert(pos, "\n" + (check ? check[1] + "[ ] " : bullet[1] + bullet[2] + " "))
    }
}
