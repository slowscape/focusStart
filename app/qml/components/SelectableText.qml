import QtQuick
import QtQuick.Controls
import "../theme"

// Read-only text you can select and copy (notes in reading mode): drag or double-click to
// select, Ctrl+C or right-click > Copy. Links still open on click. Never editable.
TextEdit {
    id: t
    readOnly: true
    selectByMouse: true
    textFormat: TextEdit.MarkdownText
    wrapMode: TextEdit.Wrap
    color: Theme.textColor
    selectionColor: Theme.accent
    selectedTextColor: "white"
    font.pixelSize: Theme.fontBody
    onLinkActivated: (link) => backend.openLink(link)
    // Keep the selection while the right-click menu has focus; drop it otherwise when focus leaves.
    persistentSelection: true
    property bool _menu: false
    onActiveFocusChanged: if (!activeFocus && !_menu) deselect()

    HoverHandler { cursorShape: t.hoveredLink !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: { t._menu = true; menu.popup() }
    }
    Menu {
        id: menu
        onClosed: { t._menu = false; if (!t.activeFocus) t.deselect() }
        MenuItem { text: "Copy"; enabled: t.selectedText !== ""; onTriggered: t.copy() }
        MenuItem { text: "Select all"; onTriggered: { t.forceActiveFocus(); t.selectAll() } }
    }
}
