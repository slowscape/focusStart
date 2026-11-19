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
// "#" command: the same for tags (several allowed; new names become tags on submit).
// Chips have their own row above the field, so the field keeps its full width and never
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
    property bool allowLists: true      // "/" picks a list (off on the Lists tab)
    // Chosen list (sticky): an existing list id, or a name to create on submit.
    property string listId: ""
    property string listName: ""
    property string newListName: ""
    // Chosen tags (sticky): [{id, name, color}], id "" = create on submit.
    property var tags: []
    property string submitWhen: ""   // set only during submit(when); read it in onSubmitted
    signal submitted(string text, string listId, string newListName, var tagIds, var newTagNames)
    signal chipClicked()
    signal calendarClicked()
    function focusField() { field.forceActiveFocus() }
    function clearList() { listId = ""; listName = ""; newListName = "" }
    function removeTag(name) { tags = tags.filter(function (g) { return g.name !== name }) }
    function addTagChip(g) {
        if (tags.some(function (x) { return x.name.toLowerCase() === g.name.toLowerCase() })) return
        tags = tags.concat([g])
    }

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
        // The nearest "/" (list) or "#" (tag) before the cursor, at the start or after a space.
        var i = Math.max(t.lastIndexOf("/", cur - 1), t.lastIndexOf("#", cur - 1))
        if (i < 0 || (i > 0 && t.charAt(i - 1) !== " ")) { slashPos = -1; return }
        var tag = t.charAt(i) === "#"
        if (!tag && !allowLists) { slashPos = -1; return }
        if (i === dismissedAt && t.substring(0, i) === dismissedPrefix) { slashPos = -1; return }
        dismissedAt = -1
        var q = t.substring(i + 1, cur)
        var matches = tag ? backend.tagMatches(q) : backend.listMatches(q)
        // A space with no match means the user is typing the task, not a list/tag.
        if (q.indexOf(" ") >= 0 && matches.length === 0) { slashPos = -1; return }
        var kind = tag ? "tag" : "list"
        var opts = matches.map(function (m) { return { kind: kind, id: m.id, name: m.name, color: m.color || "", create: false } })
        var exact = matches.some(function (m) { return m.name.toLowerCase() === q.trim().toLowerCase() })
        if (q.trim() !== "" && !exact) opts.push({ kind: kind, id: "", name: q.trim(), color: "", create: true })
        slashPos = i; query = q; options = opts
        highlighted = 0
    }
    function choose(opt) {
        var t = field.text
        var end = slashPos + 1 + query.length
        field.text = (t.substring(0, slashPos) + t.substring(end)).replace(/\s{2,}/g, " ").replace(/^\s+/, "")
        field.cursorPosition = Math.min(slashPos, field.text.length)
        if (opt.kind === "tag") addTagChip({ id: opt.id, name: opt.name, color: opt.color })
        else if (opt.create) { listId = ""; newListName = opt.name; listName = opt.name }
        else { listId = opt.id; newListName = ""; listName = opt.name }
        slashPos = -1
        field.forceActiveFocus()
    }
    // "#word" and "/word" typed without picking from the suggestions.
    readonly property var _tagRe: /(^|\s)#(\S+)/g
    readonly property var _listRe: /(^|\s)\/(\S+)/
    // The task text that would be added (commands removed); "" if there's none.
    function taskText() {
        var t = field.text.replace(_tagRe, " ")
        if (allowLists) t = t.replace(_listRe, " ")
        return t.replace(/\s{2,}/g, " ").trim()
    }
    function submit(when) {
        submitWhen = when || ""
        _submit()
        submitWhen = ""
    }
    function _submit() {
        var t = field.text
        var id = listId, newName = newListName
        var chips = tags.slice()
        var m
        _tagRe.lastIndex = 0
        while ((m = _tagRe.exec(t)) !== null) {
            var g = backend.findTag(m[2])
            if (!chips.some(function (x) { return x.name.toLowerCase() === m[2].toLowerCase() }))
                chips.push(g.id ? g : { id: "", name: m[2], color: "" })
        }
        t = t.replace(_tagRe, " ")
        if (allowLists) {
            m = t.match(_listRe)
            if (m) {
                var found = backend.findList(m[2])
                if (found.id) { id = found.id; newName = "" } else { id = ""; newName = m[2] }
                t = t.replace(m[0], " ")
            }
        }
        t = t.replace(/\s{2,}/g, " ").trim()
        if (t.length === 0) return
        qa.submitted(t, id, newName,
                     chips.filter(function (x) { return x.id }).map(function (x) { return x.id }),
                     chips.filter(function (x) { return !x.id }).map(function (x) { return x.name }))
        if (newName !== "") {  // the list exists now; keep the chip pointing at it
            var made = backend.findList(newName)
            if (made.id && newName === newListName) { listId = made.id; newListName = "" }
        }
        // Tags created by this add now exist: point the chips at them.
        tags = tags.map(function (x) { if (x.id) return x; var f = backend.findTag(x.name); return f.id ? f : x })
        field.clear()
        field.forceActiveFocus()
    }

    readonly property int rowHeight: 56
    readonly property bool hasChips: listName !== "" || tags.length > 0
    implicitHeight: rowHeight + (hasChips ? listRow.height : 0)
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
                    Icon { visible: modelData.kind === "list" || modelData.create; name: modelData.create ? "add" : "list"; size: 12; color: Theme.subtext }
                    Rectangle { visible: modelData.kind === "tag" && !modelData.create; width: 9; height: 9; radius: 5; color: modelData.color || Theme.subtext }
                    Label {
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: modelData.create ? "Create " + modelData.kind + " \u201c" + modelData.name + "\u201d"
                                               : (modelData.kind === "tag" ? "#" : "") + modelData.name
                    }
                }
            }
        }
    }

    // The chosen list and tags, on their own row(s) above the field.
    Flow {
        id: listRow
        visible: qa.hasChips
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Theme.s3
        anchors.rightMargin: Theme.s3
        anchors.bottom: fieldRow.top
        topPadding: 6
        spacing: Theme.s2
        Chip {
            id: listChip
            visible: qa.listName !== ""
            compact: true
            checkable: false
            text: "List: " + (qa.newListName !== "" ? "+ " : "") + qa.listName + "  \u2715"
            width: Math.min(implicitWidth, listRow.width)
            onClicked: { qa.clearList(); field.forceActiveFocus() }
            ToolTip.visible: hovered
            ToolTip.text: "Adding to this list. Click to clear."
        }
        Repeater {
            model: qa.tags
            Chip {
                required property var modelData
                compact: true
                checkable: false
                fill: modelData.color ? Qt.rgba(Qt.color(modelData.color).r, Qt.color(modelData.color).g, Qt.color(modelData.color).b, 0.35) : Theme.track
                text: "#" + (modelData.id ? "" : "+ ") + modelData.name + "  \u2715"
                width: Math.min(implicitWidth, listRow.width)
                onClicked: { qa.removeTag(modelData.name); field.forceActiveFocus() }
                ToolTip.visible: hovered
                ToolTip.text: "Tag for new tasks. Click to remove."
            }
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
