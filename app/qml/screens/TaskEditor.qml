import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

// Edits an open task. A finished task (opened from History) shows read-only:
// its notes, its completed steps, and "Delete from history".
Item {
    id: screen
    property string taskId
    property var info: (backend.revision, backend.taskInfo(taskId))
    property bool showCompleted: false
    property var completed: (backend.revision, backend.completedSteps(taskId))
    readonly property var steps: backend.stepModel(taskId)
    readonly property bool finished: info.exists === true && info.done === true

    onInfoChanged: if (info && !info.exists) appWindow.back()

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Theme.s2
            IconButton { icon_: "back"; tip: "Back (Esc)"; onClicked: { if (!screen.finished) title.commit(); appWindow.back() } }
            Label { text: screen.finished ? "Finished task" : "Edit task"; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold; Layout.fillWidth: true }
            IconButton { icon_: "play"; tip: "Start"; iconColor: Theme.accent; visible: !screen.finished; onClicked: appWindow.openFocus(screen.taskId) }
        }

        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: col.implicitHeight + Theme.s6
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            ColumnLayout {
                id: col
                x: Theme.s4
                width: flick.width - 2 * Theme.s4
                spacing: Theme.s3

                // ---------------------------------------------- open task
                TextField {
                    id: title
                    visible: !screen.finished
                    Layout.fillWidth: true
                    text: screen.info.title || ""
                    font.pixelSize: Theme.fontBody + 2
                    placeholderText: "Task title"
                    function commit() { if (text.trim() && text !== screen.info.title) backend.setTitle(screen.taskId, text) }
                    onEditingFinished: if (!screen.finished) commit()
                }

                // ---------------------------------------------- finished task (read-only)
                ColumnLayout {
                    visible: screen.finished
                    Layout.fillWidth: true
                    spacing: 2
                    Label {
                        Layout.fillWidth: true
                        text: screen.info.title || ""
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontBody + 2
                        font.weight: Font.DemiBold
                    }
                    Label {
                        Layout.fillWidth: true
                        text: "✓ Done " + (screen.info.completedLabel || "")
                              + (screen.info.listName ? "  ·  " + screen.info.listName : "")
                        color: Theme.success
                        font.pixelSize: Theme.fontSmall
                        wrapMode: Text.Wrap
                    }
                }

                ColumnLayout {
                    visible: !screen.finished
                    Layout.fillWidth: true
                    spacing: Theme.s3
                    Label { text: "When"; color: Theme.subtext; font.pixelSize: Theme.fontSmall }
                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.s2
                        Chip { text: "Today"; checkable: false; checked: screen.info.dateChoice === "today"; onClicked: backend.setDate(screen.taskId, "today") }
                        Chip { text: "Tomorrow"; checkable: false; checked: screen.info.dateChoice === "tomorrow"; onClicked: backend.setDate(screen.taskId, "tomorrow") }
                        Chip {
                            text: screen.info.dateChoice === "date" ? screen.info.dateLabel : "Pick a date…"
                            checkable: false
                            checked: screen.info.dateChoice === "date"
                            onClicked: appWindow.pickDate(function (iso) { backend.setDate(screen.taskId, iso) })
                        }
                        Chip { text: "No date"; checkable: false; checked: screen.info.dateChoice === "none"; onClicked: backend.setDate(screen.taskId, "none") }
                    }

                    Label { text: "List"; color: Theme.subtext; font.pixelSize: Theme.fontSmall }
                    ComboBox {
                        id: listBox
                        Layout.fillWidth: true
                        model: backend.listsModel
                        textRole: "name"
                        valueRole: "itemId"
                        currentIndex: (backend.revision, backend.listsModel.indexOf(screen.info.listId || ""))
                        onActivated: backend.setList(screen.taskId, currentValue)
                    }

                    Switch {
                        text: "Pomodoro timer for this task"
                        checked: screen.info.pomodoro === true
                        onToggled: backend.setTaskPomodoro(screen.taskId, checked)
                    }
                }

                Label {
                    visible: !screen.finished || (screen.info.notes || "") !== ""
                    text: "Task Notes"; color: Theme.subtext; font.pixelSize: Theme.fontSmall
                }
                NotesArea {
                    id: notes
                    visible: !screen.finished
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(72, notes.textHeight)
                    taskId: screen.taskId
                    notes: screen.info.notes || ""
                    onEscaped: screen.forceActiveFocus()
                }
                TextEdit {   // finished task: notes are read-only, still selectable for copying
                    visible: screen.finished && (screen.info.notes || "") !== ""
                    Layout.fillWidth: true
                    text: screen.info.notes || ""
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    color: Theme.textColor
                    font.pixelSize: Theme.fontBody
                }

                ColumnLayout {
                    visible: !screen.finished
                    Layout.fillWidth: true
                    spacing: Theme.s3
                    RowLayout {
                        Layout.fillWidth: true
                        Label { text: "Steps"; color: Theme.subtext; font.pixelSize: Theme.fontSmall; Layout.fillWidth: true }
                        Button { text: "Add steps"; flat: true; onClicked: appWindow.openPlan(screen.taskId) }
                    }
                    StepEditList {
                        taskId: screen.taskId
                        scrollable: false      // the page scrolls; the list grows
                        Layout.fillWidth: true
                        Layout.preferredHeight: contentHeight
                    }
                    StepInput {
                        Layout.fillWidth: true
                        placeholderText: "+ Add a step"
                        onAccepted: { if (text.trim()) backend.addStep(screen.taskId, text.trim()); clear() }
                    }
                }

                // Completed steps: collapsed with Restore on an open task; a plain list on a finished one.
                Button {
                    visible: !screen.finished && screen.completed.length > 0
                    flat: true
                    text: (screen.showCompleted ? "▾ " : "▸ ") + "Completed steps (" + screen.completed.length + ")"
                    onClicked: screen.showCompleted = !screen.showCompleted
                }
                Label {
                    visible: screen.finished && screen.completed.length > 0
                    text: "Completed steps (" + screen.completed.length + ")"
                    color: Theme.subtext
                    font.pixelSize: Theme.fontSmall
                    Layout.topMargin: Theme.s1
                }
                Repeater {
                    model: (screen.showCompleted || screen.finished) ? screen.completed : []
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: Theme.s2
                        Icon { visible: screen.finished; name: "check"; size: 11; color: Theme.success }
                        Label { text: modelData.text; color: Theme.subtext; Layout.fillWidth: true; wrapMode: Text.Wrap }
                        Button { visible: !screen.finished; text: "Restore"; flat: true; onClicked: backend.restoreStep(screen.taskId, modelData.id) }
                    }
                }

                Item { implicitHeight: Theme.s2 }
                Button {
                    Layout.fillWidth: true
                    visible: !screen.finished
                    text: "Mark task done"
                    onClicked: { title.commit(); appWindow.completeTask(screen.taskId, this, null); appWindow.back() }
                }
                Button {
                    Layout.fillWidth: true
                    visible: !screen.finished
                    text: "Delete task"
                    flat: true
                    onClicked: appWindow.confirmDelete(screen.taskId)
                }
                Button {
                    Layout.fillWidth: true
                    visible: screen.finished
                    text: "Delete from history"
                    flat: true
                    onClicked: appWindow.confirmDelete(screen.taskId)
                }
            }
        }
    }
}
