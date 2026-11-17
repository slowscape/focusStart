import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

Item {
    id: screen
    readonly property int bottomInset: quick.height   // undo/info messages sit above the add box
    property bool drawerOpen: false

    // Esc closes the side panel. (Main's Esc is off on tab screens, so no clash.)
    Shortcut { sequence: "Esc"; enabled: screen.drawerOpen; onActivated: screen.drawerOpen = false }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
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

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: backend.listTasksModel
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            delegate: TaskRow { showDate: true }
            add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durMed } }
            Label {
                anchors.centerIn: parent
                visible: list.count === 0
                text: "This list is clear."
                color: Theme.subtext
            }
        }

        QuickAdd {
            id: quick
            Layout.fillWidth: true
            placeholder: "Add to " + backend.currentListName + "…"
            showChip: false
            onSubmitted: (text, listId, newListName) =>
                backend.addTask(text, "none", listId || backend.currentListId, newListName)
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
                delegate: ItemDelegate {
                    id: row
                    required property string itemId
                    required property string name
                    required property int count
                    readonly property bool current: itemId === backend.currentListId
                    width: lists.width
                    height: 44
                    onClicked: { backend.currentListId = itemId; screen.drawerOpen = false }
                    background: Rectangle {
                        color: row.current ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.14)
                                           : (row.hovered ? Theme.hover : "transparent")
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
