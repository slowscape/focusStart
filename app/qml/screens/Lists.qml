import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

Item {
    id: screen
    readonly property int bottomInset: quick.height
    property real enterOffset: 0      // page-enter slide for header and list (not the add bar)   // undo/info messages sit above the add box
    property bool drawerOpen: false
    // Date for the next add: "" = no date, "tomorrow", or an ISO date.
    property string addWhen: ""

    // Esc closes the side panel. (Main's Esc is off on tab screens, so no clash.)
    Shortcut { sequence: "Esc"; enabled: screen.drawerOpen; onActivated: screen.drawerOpen = false }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            transform: Translate { y: screen.enterOffset }
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s2
            Layout.rightMargin: Theme.s2
            Layout.topMargin: Theme.s2
            Layout.bottomMargin: Theme.s2
            spacing: Theme.s1
            IconButton { icon_: "menu"; tip: "Lists"; onClicked: screen.drawerOpen = true }
            Label {
                Layout.fillWidth: true
                text: backend.currentListName
                font.pixelSize: Theme.fontHero
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                TapHandler { onTapped: screen.drawerOpen = true }
            }
            IconButton {
                icon_: "more"; tip: "List options"
                onClicked: listMenu.popup()
                Menu {
                    id: listMenu
                    MenuItem { text: "Print (save as PDF)…"; onTriggered: appWindow.exportPdf("list") }
                    MenuItem { text: "Rename list…"; onTriggered: nameDialog.openFor("rename") }
                    MenuItem {
                        text: "Delete list…"
                        enabled: backend.listsModel.count > 1
                        onTriggered: deleteDialog.open()
                    }
                }
            }
        }

        // Same cards as My Day: steps inline, check them off, drag titles to reorder.
        ListView {
            id: list
            transform: Translate { y: screen.enterOffset }
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.s3
            Layout.rightMargin: Theme.s3
            clip: true
            spacing: Theme.s2
            bottomMargin: Theme.s3
            model: backend.listTasksModel
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            property Item dropLine: taskLine
            delegate: TaskCard {
                onReorder: (from, to) => backend.reorderTasks(appWindow.reorderedIds(backend.listTasksModel, from, to))
            }
            Rectangle { id: taskLine; visible: false; z: 50; width: parent.width; height: 3; radius: 2; color: Theme.accent }
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durMed }
                    NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: Theme.durMed; easing.type: Easing.OutCubic }
                }
            }
            Label {
                anchors.centerIn: parent
                visible: backend.listTasksModel.count === 0   // model count: see CLAUDE.md
                text: "This list is clear."
                color: Theme.subtext
            }
        }

        // Adds to this list ("/" isn't needed here; "//" tags still work). No date by default;
        // Tomorrow / the calendar work as on My Day.
        QuickAdd {
            id: quick
            Layout.fillWidth: true
            allowLists: false
            readonly property string whenLabel: screen.addWhen === "" ? "" :
                (screen.addWhen === "tomorrow" ? "Tomorrow" : backend.dateLabel(screen.addWhen))
            placeholder: screen.addWhen === "" ? "Add to " + backend.currentListName + "…"
                                               : "Add for " + whenLabel.toLowerCase() + "…"
            chipCheckable: false
            chipChecked: screen.addWhen !== ""
            chipText: screen.addWhen === "" || screen.addWhen === "tomorrow" ? "Tomorrow" : whenLabel + "  ✕"
            onChipClicked: {
                if (quick.taskText() !== "") quick.submit("tomorrow")
                else screen.addWhen = (screen.addWhen === "" ? "tomorrow" : "")
            }
            showCalendar: true
            onCalendarClicked: appWindow.pickDate(function (iso) {
                var when = (iso <= backend.todayIso) ? "today" : iso
                if (quick.taskText() !== "") quick.submit(when)
                else screen.addWhen = (when === "today" ? "" : when)
                quick.focusField()
            })
            onSubmitted: (text, listId, newListName, tagIds, newTagNames) => {
                var when = quick.submitWhen || (screen.addWhen === "" ? "none" : screen.addWhen)
                backend.addTask(text, when, backend.currentListId, "", tagIds, newTagNames)
                if (when !== "none")
                    appWindow.toast("Added for " + (when === "today" ? "today" : when === "tomorrow" ? "tomorrow" : backend.dateLabel(when)), "")
                else Qt.callLater(list.positionViewAtEnd)
            }
        }
    }

    // ---------------------------------------------------------- side panel
    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Theme.scrim
        opacity: screen.drawerOpen ? 1 : 0
        visible: opacity > 0
        z: 20
        Behavior on opacity { NumberAnimation { duration: Theme.durMed } }
        MouseArea { anchors.fill: parent; onClicked: screen.drawerOpen = false }
    }
    Rectangle {
        id: panel
        objectName: "listsPanel"
        z: 21
        width: Math.min(300, screen.width * 0.85)
        height: parent.height
        x: screen.drawerOpen ? 0 : -width - 8
        visible: x > -width - 8
        color: Theme.dark ? "#272727" : "#fbfbfb"
        border.color: Theme.cardBorder
        Behavior on x { NumberAnimation { duration: Theme.durSlow; easing.type: Easing.OutCubic } }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: Theme.s2
            spacing: 0
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: Theme.s2
                Layout.rightMargin: Theme.s2
                IconButton { icon_: "menu"; tip: "Close"; onClicked: screen.drawerOpen = false }
                Label { text: "Lists"; font.pixelSize: Theme.fontTitle; font.weight: Font.DemiBold; Layout.fillWidth: true }
            }
            ListView {
                id: lists
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: Theme.s2
                clip: true
                model: backend.listsModel
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                property Item dropLine: listLine
                Rectangle { id: listLine; visible: false; z: 50; width: parent.width; height: 3; radius: 2; color: Theme.accent }
                delegate: ItemDelegate {
                    id: row
                    required property string itemId
                    required property string name
                    required property int count
                    required property int index
                    readonly property bool current: itemId === backend.currentListId
                    width: lists.width
                    height: 44
                    z: listDrag.dragging ? 10 : 0
                    transform: Translate { y: listDrag.offset }
                    // Click opens the list; drag reorders the lists.
                    ReorderArea {
                        id: listDrag
                        anchors.fill: parent
                        row: row
                        view: lists
                        index: row.index
                        indicator: listLine
                        onTapped: { backend.currentListId = row.itemId; screen.drawerOpen = false }
                        onDropped: (from, to) => backend.reorderLists(appWindow.reorderedIds(backend.listsModel, from, to))
                    }
                    background: Rectangle {
                        color: row.current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                                           : (listDrag.containsMouse ? Theme.hover : "transparent")
                        Rectangle {  // accent marker on the selected list
                            visible: row.current
                            width: 3; height: parent.height * 0.5; radius: 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.accent
                        }
                    }
                    contentItem: RowLayout {
                        spacing: Theme.s3
                        Icon { name: "list"; size: 14; color: row.current ? Theme.accent : Theme.subtext; Layout.leftMargin: Theme.s1 }
                        Label {
                            Layout.fillWidth: true
                            text: row.name
                            elide: Text.ElideRight
                            font.weight: row.current ? Font.DemiBold : Font.Normal
                        }
                        Rectangle {  // incomplete count, circled, right-aligned
                            visible: row.count > 0
                            implicitWidth: Math.max(22, countLabel.implicitWidth + 12)
                            implicitHeight: 22
                            radius: 11
                            color: Theme.track
                            Label {
                                id: countLabel
                                anchors.centerIn: parent
                                text: row.count
                                font.pixelSize: Theme.fontSmall
                            }
                        }
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.cardBorder }
            ItemDelegate {
                Layout.fillWidth: true
                height: 48
                onClicked: nameDialog.openFor("new")
                contentItem: RowLayout {
                    spacing: Theme.s3
                    Icon { name: "add"; size: 14; color: Theme.accent; Layout.leftMargin: Theme.s1 }
                    Label { text: "New list"; color: Theme.accent; Layout.fillWidth: true }
                }
            }
        }
    }

    // ---------------------------------------------------------- dialogs
    Dialog {
        id: nameDialog
        property string mode: "new"
        function openFor(m) {
            mode = m
            nameField.text = m === "rename" ? backend.currentListName : ""
            open()
            nameField.forceActiveFocus()
            nameField.selectAll()
        }
        anchors.centerIn: Overlay.overlay
        width: Math.min(320, screen.width - 32)
        modal: true
        title: mode === "new" ? "New list" : "Rename list"
        standardButtons: Dialog.Ok | Dialog.Cancel
        TextField {
            id: nameField
            width: parent.width
            placeholderText: "List name"
            onAccepted: nameDialog.accept()
        }
        onAccepted: {
            var n = nameField.text.trim()
            if (!n) return
            if (mode === "new") { backend.addList(n); screen.drawerOpen = false }
            else backend.renameList(backend.currentListId, n)
        }
    }

    Dialog {
        id: deleteDialog
        anchors.centerIn: Overlay.overlay
        width: Math.min(320, screen.width - 32)
        modal: true
        title: "Delete “" + backend.currentListName + "”?"
        standardButtons: Dialog.Ok | Dialog.Cancel
        property int taskCount: 0
        property var targets: []
        onAboutToShow: {
            taskCount = backend.listTaskCountAll(backend.currentListId)
            var t = []
            for (var i = 0; i < backend.listsModel.count; i++) {
                var l = backend.listsModel.get(i)
                if (l.id !== backend.currentListId) t.push({ id: l.id, name: l.name })
            }
            targets = t
            moveTo.currentIndex = 0
        }
        ColumnLayout {
            width: parent.width
            spacing: Theme.s2
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: deleteDialog.taskCount > 0 ? "Move its tasks to:" : "This list has no tasks."
            }
            ComboBox {
                id: moveTo
                visible: deleteDialog.taskCount > 0
                Layout.fillWidth: true
                textRole: "name"
                valueRole: "id"
                model: deleteDialog.targets
            }
        }
        onAccepted: backend.deleteList(backend.currentListId,
                                       deleteDialog.taskCount > 0 ? moveTo.currentValue : "")
    }
}
