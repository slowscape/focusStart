import QtQuick
import QtQuick.Controls
import "../theme"

// Single-paragraph text entry that wraps and grows instead of cutting text off.
// Enter submits (no newlines); Shift+Enter is ignored too, steps are one line of thought.
TextArea {
    id: input
    signal accepted()
    signal cancelled()
    wrapMode: TextEdit.Wrap
    verticalAlignment: TextEdit.AlignTop
    // Size to the text (the style's minimum makes one-line steps look like two).
    topPadding: 6
    bottomPadding: 6
    implicitHeight: Math.max(contentHeight, font.pixelSize * 1.4) + topPadding + bottomPadding
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { e.accepted = true; input.accepted() }
        else if (e.key === Qt.Key_Escape && text.length === 0) { e.accepted = false; input.cancelled() }
    }
    // Pasted text with line breaks becomes one line.
    onTextChanged: if (text.indexOf("\n") >= 0) {
        var pos = cursorPosition
        text = text.replace(/\s*\n+\s*/g, " ")
        cursorPosition = Math.min(pos, text.length)
    }
}
