import QtQuick
import QtQuick.Controls
import "../theme"

// The "..." menu for a task: edit, change date, change list, delete.
Menu {
    id: m
    property string taskId
    property string listId
    property bool showStart: false

    MenuItem { text: "Edit"; onTriggered: appWindow.openEditor(m.taskId) }
    Menu {
        title: "Change date"
        MenuItem { text: "Today"; onTriggered: backend.setDate(m.taskId, "today") }
        MenuItem { text: "Tomorrow"; onTriggered: backend.setDate(m.taskId, "tomorrow") }
        MenuItem { text: "Pick a date…"; onTriggered: appWindow.pickDate(function (iso) { backend.setDate(m.taskId, iso) }) }
        MenuItem { text: "No date"; onTriggered: backend.setDate(m.taskId, "none") }
    }
    Menu {
        id: listMenu
        title: "Change list"
        Instantiator {
            model: backend.listsModel
            delegate: MenuItem {
                required property string itemId
                required property string name
                text: name
                checkable: true
                checked: itemId === m.listId
                onTriggered: backend.setList(m.taskId, itemId)
            }
            onObjectAdded: (index, object) => listMenu.insertItem(index, object)
            onObjectRemoved: (index, object) => listMenu.removeItem(object)
        }
    }
    MenuSeparator {}
    MenuItem { text: "Delete"; onTriggered: appWindow.confirmDelete(m.taskId) }
}
