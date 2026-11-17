import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Quick-add field pinned at the bottom of a screen. Focus stays after Enter.
//
// "/" command: typing "/" (at the start or after a space) suggests lists, matched
// case-insensitively. Up/Down + Enter/Tab (or click) picks one; if nothing matches,
// "Create" makes a new list named exactly as typed. "/word" typed without picking
// also works on Enter. The chosen list stays as a chip until cleared.
// The list chip has its own row above the field, so the field keeps its full width and never
// moves: the field row is pinned to the bottom and the component grows upward.
//
// Date shortcuts: when a task is typed, the screen can call submit(when) from its Tomorrow /
// calendar control to add it for that date in one click (submitWhen holds it for the handler).
Rectangle {
    id: qa
    property alias placeholder: field.placeholderText
    property alias chipText: chip.text
    property alias chipChecked: chip.checked
    property alias chipCheckable: chip.checkable
    property bool showChip: true
    property bool showCalendar: false
    // Chosen list (sticky): an existing list id, or a name to create on submit.
    property string listId: ""
    property string listName: ""
    property string newListName: ""
    property string submitWhen: ""   // set only during submit(when); read it in onSubmitted
    signal submitted(string text, string listId, string newListName)
    signal chipClicked()
    signal calendarClicked()
    function focusField() { field.forceActiveFocus() }
    function clearList() { listId = ""; listName = ""; newListName = "" }

    // ----- slash suggestions
    property int slashPos: -1
    property string query: ""
    property var options: []
    property int highlighted: 0
    property int dismissedAt: -1     // Esc hides suggestions for this "/" until the text before it changes
    property string dismissedPrefix: ""
    readonly property bool suggesting: slashPos >= 0 && options.length > 0

    function updateSlash() {
        var t = field.text, cur = field.cursorPosition
        var i = t.lastIndexOf("/", cur - 1)
        if (i < 0 || (i > 0 && t.charAt(i - 1) !== " ")) { slashPos = -1; return }
        if (i === dismissedAt && t.substring(0, i) === dismissedPrefix) { slashPos = -1; return }
        dismissedAt = -1
        var q = t.substring(i + 1, cur)
        var matches = backend.listMatches(q)
        // A space with no matching list means the user is typing the task, not a list.
        if (q.indexOf(" ") >= 0 && matches.length === 0) { slashPos = -1; return }
        var opts = matches.map(function (m) { return { id: m.id, name: m.name, create: false } })
        var exact = matches.some(function (m) { return m.name.toLowerCase() === q.trim().toLowerCase() })
        if (q.trim() !== "" && !exact) opts.push({ id: "", name: q.trim(), create: true })
        slashPos = i; query = q; options = opts
        highlighted = 0
    }
    function choose(opt) {
        var t = field.text
        var end = slashPos + 1 + query.length
        field.text = (t.substring(0, slashPos) + t.substring(end)).replace(/\s{2,}/g, " ").replace(/^\s+/, "")
        field.cursorPosition = Math.min(slashPos, field.text.length)
        if (opt.create) { listId = ""; newListName = opt.name; listName = opt.name }
        else { listId = opt.id; newListName = ""; listName = opt.name }
        slashPos = -1
        field.forceActiveFocus()
    }
    // The task text that would be added (the "/list" part removed); "" if there's none.
    function taskText() {
        return field.text.replace(/(^|\s)\/(\S+)/, " ").replace(/\s{2,}/g, " ").trim()
    }
    function submit(when) {
        submitWhen = when || ""
        _submit()
        submitWhen = ""
    }
    function _submit() {
        var t = field.text
        var id = listId, newName = newListName
        // "/word" typed without picking from the suggestions
        var m = t.match(/(^|\s)\/(\S+)/)
        if (m) {
            var found = backend.findList(m[2])
            if (found.id) { id = found.id; newName = "" } else { id = ""; newName = m[2] }
            t = t.replace(m[0], " ")
        }
        t = t.replace(/\s{2,}/g, " ").trim()
        if (t.length === 0) return
        qa.submitted(t, id, newName)
        if (newName !== "") {  // the list exists now; keep the chip pointing at it
            var made = backend.findList(newName)
            if (made.id && newName === newListName) { listId = made.id; newListName = "" }
        }
        field.clear()
        field.forceActiveFocus()
    }

    readonly property int rowHeight: 56
    readonly property bool hasListChip: listName !== ""
    implicitHeight: rowHeight + (hasListChip ? listRow.height : 0)
    z: 5
    color: Theme.windowColor
    Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: Theme.cardBorder }

    // Suggestions, shown above the field. A non-modal Popup lives in the window's overlay
    // layer, so nothing (e.g. the undo message) can cover it; it never takes focus.
    Popup {
        id: suggest
        objectName: "suggestPopup"
        visible: qa.suggesting && field.activeFocus
        focus: false
        modal: false
        closePolicy: Popup.NoAutoClose
        x: Theme.s3
        width: qa.width - 2 * Theme.s3
        // Sized from content. Every padding/inset is set explicitly: the Fluent style
        // adds its own popup padding, which otherwise squeezes the list to a sliver.
        y: -height - 4
        padding: 4
        topPadding: 4
        bottomPadding: 4
        leftPadding: 4
        rightPadding: 4
        topInset: 0
        bottomInset: 0
        leftInset: 0
        rightInset: 0
        background: Rectangle {
            radius: Theme.radius
            color: Theme.dark ? "#2b2b2b" : "#ffffff"
            border.color: Theme.cardBorder
        }
        contentItem: ListView {
            id: sugList
            clip: true
            implicitHeight: Math.min(contentHeight, 220)
            model: qa.options
            currentIndex: qa.highlighted
            delegate: ItemDelegate {
                required property var modelData
                required property int index
                width: sugList.width
                height: 32
                focusPolicy: Qt.NoFocus
                highlighted: index === qa.highlighted
                onClicked: qa.choose(modelData)
                contentItem: RowLayout {
                    spacing: Theme.s2
                    Icon { name: modelData.create ? "add" : "list"; size: 12; color: Theme.subtext }
                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: modelData.create ? "Create list \u201c" + modelData.name + "\u201d" : modelData.name
                    }
                }
            }
        }
    }

    // The chosen list, on its own row above the field.
    Row {
        id: listRow
        visible: qa.hasListChip
        anchors.left: parent.left
        anchors.leftMargin: Theme.s3
        anchors.bottom: fieldRow.top
        height: 32
        spacing: Theme.s2
        Label {
            anchors.verticalCenter: parent.verticalCenter
            text: "List"
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
        }
        Chip {
            id: listChip
            anchors.verticalCenter: parent.verticalCenter
            compact: true
            checkable: false
            text: (qa.newListName !== "" ? "+ " : "") + qa.listName + "  \u2715"
            width: Math.min(implicitWidth, qa.width - 2 * Theme.s3 - 40)
            onClicked: { qa.clearList(); field.forceActiveFocus() }
            ToolTip.visible: hovered
            ToolTip.text: "Adding to this list. Click to clear."
        }
    }

    RowLayout {
        id: fieldRow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: qa.rowHeight
        anchors.leftMargin: Theme.s3
        anchors.rightMargin: Theme.s3
        spacing: Theme.s2
        TextField {
            id: field
            objectName: "quickField"
            Layout.fillWidth: true
            placeholderText: "Add a task…"
            onTextChanged: qa.updateSlash()
            onCursorPositionChanged: qa.updateSlash()
            onActiveFocusChanged: if (!activeFocus) qa.slashPos = -1
            Keys.onPressed: (e) => {
                if (!qa.suggesting) return
                if (e.key === Qt.Key_Down) { qa.highlighted = (qa.highlighted + 1) % qa.options.length; e.accepted = true }
                else if (e.key === Qt.Key_Up) { qa.highlighted = (qa.highlighted + qa.options.length - 1) % qa.options.length; e.accepted = true }
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Tab) {
                    qa.choose(qa.options[qa.highlighted]); e.accepted = true
                } else if (e.key === Qt.Key_Escape) {
                    qa.dismissedAt = qa.slashPos
                    qa.dismissedPrefix = text.substring(0, qa.slashPos)
                    qa.slashPos = -1
                    e.accepted = true
                }
            }
            // While suggesting, these keys belong to the field, never to app shortcuts.
            Keys.onShortcutOverride: (e) => {
                if (qa.suggesting && [Qt.Key_Escape, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Up, Qt.Key_Down, Qt.Key_Tab].indexOf(e.key) >= 0)
                    e.accepted = true
            }
            onAccepted: qa.submit("")
        }
        Chip {
            id: chip
            visible: qa.showChip
            text: "Tomorrow"
            checkable: true
            onClicked: qa.chipClicked()
        }
        RoundButton {
            visible: qa.showCalendar
            implicitWidth: 32
            implicitHeight: 32
            flat: true
            focusPolicy: Qt.TabFocus
            onClicked: qa.calendarClicked()
            contentItem: Icon { name: "calendar"; size: 14 }
            ToolTip.visible: hovered
            ToolTip.delay: 500
            ToolTip.text: "Pick a date"
            background: Rectangle { radius: width / 2; color: parent.hovered ? Theme.hover : Theme.track }
        }
    }
}
