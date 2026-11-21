import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

// One task, one step at a time. Steps can be done in any order: click any segment
// in the bar (done steps too, to look back at them). Skip / arrow keys move through
// the to-do steps only. Nothing is ever reordered here.
Item {
    id: screen
    property string taskId
    property var info: (backend.revision, backend.taskInfo(taskId))
    property bool justFinished: false
    property string nextId: ""
    property string selectedStepId: ""
    // Messages ("Nice.", undo) sit as high as on My Day, clear of the Step Complete button.
    readonly property int bottomInset: 56
    readonly property bool finished: justFinished && info.exists && info.done
    readonly property bool editing: notes.editing || stepNotes.editing || addField.activeFocus
                                    || titleText.editing || stepEditor.visible
    readonly property var steps: info.steps || []
    readonly property var remaining: steps.filter(function (s) { return !s.done })
    // The selected step (done or not), else the first to-do step.
    readonly property var current: {
        for (var i = 0; i < steps.length; i++)
            if (steps[i].id === selectedStepId) return steps[i]
        return remaining.length ? remaining[0] : null
    }
    readonly property bool viewingDone: current !== null && current.done
    readonly property bool canSkip: remaining.length > 1 || (viewingDone && remaining.length > 0)

    // Next to-do step after `fromId` in bar order (dir 1) or before it (dir -1), wrapping.
    function neighbour(fromId, dir) {
        var n = steps.length, pos = -1
        for (var i = 0; i < n; i++) if (steps[i].id === fromId) pos = i
        for (var k = 1; k <= n; k++) {
            var s = steps[((pos + dir * k) % n + n) % n]
            if (!s.done && s.id !== fromId) return s
        }
        return null
    }

    onTaskIdChanged: {
        // Clear the "+ step" field too: text typed for one task (no Enter yet) used to stay in
        // the hidden field and get added to the next task when "+ step" was opened there.
        justFinished = false; addRow.open = false; addField.clear(); selectedStepId = ""
        appWindow.lastFocusTaskId = taskId
        backend.setFocusTask(taskId)       // the timer's play/power belong to this task
    }
    Component.onCompleted: backend.setFocusTask(taskId)
    // Share the step being worked on with the notch pill, and follow the pill's skip button.
    onCurrentChanged: backend.setFocusStep(current && !current.done ? current.id : "")
    Connections {
        target: backend
        function onFocusStepChanged(taskId, stepId) {
            if (taskId === screen.taskId && (!screen.current || screen.current.id !== stepId)) screen.select(stepId)
        }
    }

    function select(stepId) {
        if (current && stepId === current.id) return
        selectedStepId = stepId
        stepSwap.restart()
    }
    function done() {
        if (!info.exists || info.done || finished || viewingDone) return
        var res
        if (current) {
            var after = neighbour(current.id, 1)
            stepSwap.restart()
            res = appWindow.completeStep(taskId, current.id, doneButton, null)
            if (res && res.ok && after) selectedStepId = after.id
        } else {
            res = appWindow.completeTask(taskId, doneButton, null)
        }
        if (res && res.ok && res.taskDone) {
            nextId = backend.nextTaskAfter(taskId)
            justFinished = true
        }
    }
    function skipStep(dir) {
        if (!canSkip || !current) return
        var n = neighbour(current.id, dir || 1)
        if (n) select(n.id)
    }
    function fmt(sec) { return Math.floor(sec / 60) + ":" + ("0" + sec % 60).slice(-2) }

    Shortcut { sequences: ["Space", "Return", "Enter"]; enabled: !screen.editing && !screen.finished && !screen.viewingDone; onActivated: screen.done() }
    Shortcut { sequence: "Right"; enabled: !screen.editing && !screen.finished; onActivated: screen.skipStep(1) }
    Shortcut { sequence: "Left"; enabled: !screen.editing && !screen.finished; onActivated: screen.skipStep(-1) }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.s4
        anchors.topMargin: Theme.s2
        spacing: Theme.s3

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            IconButton { icon_: "back"; tip: "Back (Esc)"; onClicked: appWindow.back() }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                InlineText {
                    id: titleText
                    Layout.fillWidth: true
                    text: screen.info.title || ""
                    pixelSize: Theme.fontTitle - 2
                    weight: Font.DemiBold
                    onCommitted: (t) => backend.setTitle(screen.taskId, t)
                    MouseArea {
                        anchors.fill: parent
                        visible: !titleText.editing
                        cursorShape: Qt.IBeamCursor
                        onClicked: titleText.start()
                    }
                }
                Label { text: screen.info.listName || ""; color: Theme.subtext; font.pixelSize: Theme.fontSmall }
            }
            IconButton { icon_: "edit"; tip: "Edit task"; onClicked: appWindow.openEditor(screen.taskId) }
        }

        // ---------------- Pomodoro
        // Hidden when the timer is off in Settings or for this task (Edit task).
        PomodoroBar { Layout.fillWidth: true; visible: backend.pomoEnabled && screen.info.pomodoro === true }

        // ---------------- step bar: one segment per step, in order
        Row {
            id: segs
            Layout.fillWidth: true
            visible: screen.steps.length > 0
            spacing: screen.steps.length > 16 ? 2 : 4
            height: 16
            Repeater {
                model: screen.steps
                delegate: Item {
                    required property var modelData
                    readonly property bool isCurrent: !screen.finished && screen.current !== null && modelData.id === screen.current.id
                    width: (segs.width - segs.spacing * (screen.steps.length - 1)) / Math.max(1, screen.steps.length)
                    height: segs.height
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        // Current step = taller; colour only says done (green) or to-do (grey).
                        height: parent.isCurrent ? 12 : 6
                        radius: height / 2
                        color: modelData.done ? Theme.success : (segMouse.containsMouse ? Theme.subtext : Theme.track)
                        Behavior on height { NumberAnimation { duration: Theme.durFast } }
                        Behavior on color { ColorAnimation { duration: Theme.durSlow } }
                    }
                    MouseArea {
                        id: segMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: screen.select(modelData.id)
                    }
                    ToolTip.visible: segMouse.containsMouse
                    ToolTip.delay: 300
                    ToolTip.text: (modelData.done ? "✓ " : "") + modelData.text
                }
            }
        }

        // ---------------- current step, large. Fixed height: long text shrinks to fit
        // instead of pushing the buttons around.
        Item {
            id: stepArea
            Layout.fillWidth: true
            Layout.preferredHeight: 150
            clip: true
            Label {
                id: doneTag
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                visible: screen.viewingDone && !screen.finished
                text: "\u2713 Done"
                color: Theme.success
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
            }
            Label {
                id: stepText
                visible: !stepEditor.visible
                width: parent.width
                height: parent.height - 22
                anchors.verticalCenter: parent.verticalCenter
                opacity: screen.viewingDone ? 0.7 : 1
                text: screen.finished ? "" : (screen.current ? screen.current.text : (screen.info.title || ""))
                font.pixelSize: Theme.fontHero
                font.weight: Font.DemiBold
                fontSizeMode: Text.Fit
                minimumPixelSize: Theme.fontSmall - 1   // long steps shrink rather than get cut off
                wrapMode: Text.Wrap
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            // Click the step (or the title of a task without steps) to edit its words here.
            MouseArea {
                anchors.fill: stepText
                visible: !screen.finished && !stepEditor.visible
                cursorShape: Qt.IBeamCursor
                onClicked: {
                    stepEditor.editStepId = screen.current ? screen.current.id : ""
                    stepEditor.text = stepText.text
                    stepEditor.visible = true
                    stepEditor.forceActiveFocus()
                    stepEditor.cursorPosition = stepEditor.text.length
                }
            }
            StepInput {
                id: stepEditor
                property string editStepId: ""
                visible: false
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                font.pixelSize: Theme.fontTitle
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
                function finish(save) {
                    if (!visible) return
                    visible = false
                    var t = text.trim()
                    if (!save || t === "") return
                    if (editStepId) backend.editStep(screen.taskId, editStepId, t)
                    else backend.setTitle(screen.taskId, t)
                    screen.forceActiveFocus()
                }
                onAccepted: finish(true)
                onActiveFocusChanged: if (!activeFocus) finish(true)
                Keys.onEscapePressed: finish(false)
                Keys.onShortcutOverride: (e) => {
                    if ([Qt.Key_Escape, Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space, Qt.Key_Left, Qt.Key_Right].indexOf(e.key) >= 0)
                        e.accepted = true
                }
            }
            ParallelAnimation {
                id: stepSwap
                NumberAnimation { target: stepText; property: "opacity"; from: 0; to: 1; duration: Theme.durSlow }
                NumberAnimation { target: stepText; property: "anchors.verticalCenterOffset"; from: 24; to: 0; duration: Theme.durSlow; easing.type: Easing.OutCubic }
            }
        }

        RowLayout {
            id: addRow
            property bool open: false
            visible: open && !screen.finished
            Layout.fillWidth: true
            StepInput {
                id: addField
                Layout.fillWidth: true
                placeholderText: "A step you just discovered\u2026"
                onAccepted: { if (text.trim()) backend.addStep(screen.taskId, text.trim()); clear() }
                onCancelled: { addRow.open = false; screen.forceActiveFocus() }
            }
            IconButton { icon_: "close"; tip: "Close"; onClicked: { addField.clear(); addRow.open = false } }
        }

        // Notes: the current step's own notes fill the middle; the task's notes sit below,
        // smaller. A task without steps has only its task notes.
        readonly property bool hasStep: screen.current !== null && !screen.finished
        Label {
            visible: parent.hasStep
            text: screen.viewingDone ? "Step Notes (done step)" : "Step Notes"
            color: Theme.subtext; font.pixelSize: Theme.fontSmall
        }
        NotesArea {
            id: stepNotes
            visible: parent.hasStep
            Layout.fillWidth: true
            Layout.fillHeight: true      // absorbs spare space, so the buttons stay at the bottom
            Layout.minimumHeight: 72
            taskId: screen.taskId
            stepId: screen.current ? screen.current.id : ""
            notes: screen.current ? (screen.current.notes || "") : ""
            onEscaped: screen.forceActiveFocus()
        }
        Label { text: "Task Notes"; color: Theme.subtext; font.pixelSize: Theme.fontSmall }
        NotesArea {
            id: notes
            Layout.fillWidth: true
            Layout.fillHeight: !parent.hasStep
            // With a step showing, Task Notes grow with their text (5 lines to start, one spare
            // line below); Step Notes above take whatever space is left.
            Layout.preferredHeight: parent.hasStep ? notes.growHeight : -1
            // ...up to a quarter of the screen (then it scrolls), so Step Notes keep room.
            Layout.maximumHeight: parent.hasStep ? Math.max(screen.height / 4, 5 * notes.lineHeight + 12) : Number.POSITIVE_INFINITY
            Layout.minimumHeight: 48
            taskId: screen.taskId
            notes: screen.info.notes || ""
            onEscaped: screen.forceActiveFocus()
        }

        // ---------------- actions, pinned to the bottom
        // Buttons sized to their text: Fluent's 96 px minimum made this row 300 px, wider than the
        // 288 px a 320 px window has, which pushed the whole page into the right margin.
        RowLayout {
            Layout.fillWidth: true
            visible: !screen.finished
            spacing: Theme.s1
            ActionButton {
                text: "Skip step"
                flat: true
                focusPolicy: Qt.NoFocus
                visible: screen.canSkip && !screen.viewingDone
                onClicked: screen.skipStep(1)
            }
            ActionButton {
                text: "Mark not done"
                flat: true
                focusPolicy: Qt.NoFocus
                visible: screen.viewingDone
                onClicked: backend.restoreStep(screen.taskId, screen.current.id)
            }
            ActionButton {
                text: "Skip task"
                flat: true
                focusPolicy: Qt.NoFocus
                visible: backend.myDayModel.count > 1
                onClicked: { var n = backend.nextTaskAfter(screen.taskId); if (n) screen.taskId = n }
            }
            Item { Layout.fillWidth: true }
            ActionButton {
                text: screen.steps.length > 0 ? "+ step" : "Add steps"
                flat: true
                focusPolicy: Qt.NoFocus
                onClicked: {
                    if (screen.steps.length === 0) appWindow.openPlan(screen.taskId)
                    else { addRow.open = true; addField.forceActiveFocus() }
                }
            }
        }
        Button {
            id: doneButton
            Layout.fillWidth: true
            Layout.preferredHeight: 52
            visible: !screen.finished
            text: screen.viewingDone ? "Back to to-do steps" : (screen.steps.length > 0 ? "Step Complete" : "Task Complete")
            highlighted: !screen.viewingDone
            font.pixelSize: Theme.fontTitle - 2
            focusPolicy: Qt.NoFocus
            onClicked: {
                if (!screen.viewingDone) { screen.done(); return }
                var n = screen.neighbour(screen.current.id, 1)
                if (n) screen.select(n.id)
            }
        }
    }

    // Task finished: a full-screen moment with this task's ring, every segment green, then
    // the choice of what's next. Never auto-advances.
    Rectangle {
        anchors.fill: parent
        visible: screen.finished
        color: Theme.windowColor
        // Swallow clicks so nothing underneath reacts.
        MouseArea { anchors.fill: parent; hoverEnabled: true }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 2 * Theme.s6, 420)
            spacing: Theme.s3

            StepRing {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 88; implicitHeight: 88
                lineWidth: 7
                total: Math.max(1, screen.info.stepTotal || 0)    // a task without steps: one full ring
                done: Math.max(1, screen.info.stepTotal || 0)
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Theme.s2
                text: "Task complete"
                font.pixelSize: Theme.fontHero
                font.weight: Font.DemiBold
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: screen.info.title || ""
                color: Theme.subtext
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                visible: (screen.info.stepTotal || 0) > 0
                text: "All " + Theme.plural(screen.info.stepTotal || 0, "step") + " done"
                color: Theme.success
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
            }
            Item { implicitHeight: Theme.s3 }
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                visible: screen.nextId !== ""
                highlighted: true
                text: "Next up: " + (screen.nextId ? (backend.revision, backend.taskInfo(screen.nextId).title) : "")
                contentItem: Label {
                    text: parent.text; color: "white"; wrapMode: Text.Wrap
                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                }
                onClicked: screen.taskId = screen.nextId
            }
            Button {
                Layout.fillWidth: true
                Layout.preferredHeight: screen.nextId !== "" ? -1 : 48
                text: "Back to My Day"
                highlighted: screen.nextId === ""
                flat: screen.nextId !== ""
                onClicked: appWindow.go("myday")
            }
        }
    }

    component ActionButton: Button {
        flat: true
        focusPolicy: Qt.NoFocus
        leftPadding: 10; rightPadding: 10
        implicitWidth: implicitContentWidth + leftPadding + rightPadding
        Layout.minimumWidth: implicitWidth
    }
}
