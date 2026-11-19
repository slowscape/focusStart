import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

Item {
    id: screen
    readonly property int bottomInset: quick.height
    property real enterOffset: 0      // page-enter slide for header and list (not the add bar)   // undo/info messages sit above the add box
    property string addDate: ""          // ISO; empty = tomorrow
    property bool focusQuickAdd: false
    readonly property string addLabel: addDate === "" ? "Tomorrow" : backend.dateLabel(addDate)
    Component.onCompleted: if (focusQuickAdd) Qt.callLater(quick.focusField)

    function moveTask(from, to) {
        var m = backend.upcomingModel
        var moved = m.get(from), target = m.get(to)
        if (!moved.id || !target.id) return
        var ids = appWindow.reorderedIds(m, from, to)
        // Order only among the tasks of the section it lands in.
        var inSection = {}
        for (var i = 0; i < m.count; i++) if (m.get(i).section === target.section) inSection[m.get(i).id] = true
        inSection[moved.id] = true
        if (target.plannedDate !== moved.plannedDate)
            backend.setDate(moved.id, target.plannedDate === "" ? "none" : target.plannedDate)
        backend.reorderTasks(ids.filter(function (id) { return inSection[id] }))
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        Label {
            transform: Translate { y: screen.enterOffset }
            text: "Upcoming"
            font.pixelSize: Theme.fontHero
            font.weight: Font.DemiBold
            Layout.leftMargin: Theme.s4
            Layout.topMargin: Theme.s2
            Layout.bottomMargin: Theme.s2
        }
        ListView {
            id: list
            transform: Translate { y: screen.enterOffset }
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: backend.upcomingModel
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            section.property: "section"
            section.delegate: Label {
                required property string section
                text: section
                font.weight: Font.DemiBold
                color: Theme.accent
                leftPadding: Theme.s4
                topPadding: Theme.s3
                bottomPadding: Theme.s1
            }
            // Drag a task's title to reorder it, or drop it among another day's tasks to move
            // it to that day ("No date" removes its date).
            property Item dropLine: upLine
            delegate: TaskRow {
                showDate: true
                onReorder: (from, to) => screen.moveTask(from, to)
            }
            Rectangle { id: upLine; visible: false; z: 50; width: parent.width; height: 3; radius: 2; color: Theme.accent }
            add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durMed } }

            Label {
                anchors.centerIn: parent
                width: parent.width - 2 * Theme.s6
                visible: backend.upcomingModel.count === 0   // model count: see CLAUDE.md
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: "Nothing planned ahead. Add something below whenever you like."
                color: Theme.subtext
            }
        }
        QuickAdd {
            id: quick
            Layout.fillWidth: true
            placeholder: "Add for " + screen.addLabel.toLowerCase() + "…"
            chipCheckable: false
            chipText: screen.addLabel + "  ▾"
            onChipClicked: dayMenu.popup()
            onSubmitted: (text, listId, newListName, tagIds, newTagNames) => {
                var when = quick.submitWhen || (screen.addDate === "" ? "tomorrow" : screen.addDate)
                backend.addTask(text, when, listId, newListName, tagIds, newTagNames)
                if (quick.submitWhen) appWindow.toast("Added to " + (when === "tomorrow" ? "tomorrow" : backend.dateLabel(when)), "")
            }
            // With a task typed, picking a day adds it right away for that day (one-off);
            // with nothing typed, it sets the day for the next adds.
            function pickDay(iso) {
                if (quick.taskText() !== "") quick.submit(iso)
                else screen.addDate = (iso === "tomorrow" ? "" : iso)
                quick.focusField()
            }
            Menu {
                id: dayMenu
                Instantiator {
                    model: backend.upcomingDays()
                    delegate: MenuItem {
                        required property var modelData
                        text: modelData.label
                        onTriggered: quick.pickDay(modelData.label === "Tomorrow" ? "tomorrow" : modelData.value)
                    }
                    onObjectAdded: (index, object) => dayMenu.insertItem(index, object)
                    onObjectRemoved: (index, object) => dayMenu.removeItem(object)
                }
                MenuSeparator {}
                MenuItem { text: "Pick a date…"; onTriggered: appWindow.pickDate(function (iso) { quick.pickDay(iso) }) }
            }
        }
    }
}
