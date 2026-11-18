import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

// Every completed step and task, newest first. Rows load in pages as you scroll.
Item {
    id: screen
    Component.onCompleted: backend.reloadHistory()
    Connections { target: backend; function onRevisionChanged() { backend.reloadHistory() } }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s4
            Layout.topMargin: Theme.s2
            Layout.bottomMargin: Theme.s2
            Label { text: "History"; font.pixelSize: Theme.fontHero; font.weight: Font.DemiBold; Layout.fillWidth: true }
        }
        // Totals: this week, month, year, all time (tasks and steps finished).
        GridLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s3
            Layout.rightMargin: Theme.s3
            Layout.bottomMargin: Theme.s2
            visible: backend.historySteps + backend.historyTasks > 0
            columns: 2
            rowSpacing: Theme.s2
            columnSpacing: Theme.s2
            Repeater {
                model: backend.historyStats
                Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1          // equal columns
                    implicitHeight: statCol.implicitHeight + 2 * Theme.s2
                    radius: Theme.radius
                    color: Theme.card
                    border.color: Theme.cardBorder
                    ColumnLayout {
                        id: statCol
                        anchors.fill: parent
                        anchors.margins: Theme.s2
                        anchors.leftMargin: Theme.s3
                        spacing: 0
                        Label { text: modelData.label; color: Theme.subtext; font.pixelSize: Theme.fontSmall }
                        Label {
                            Layout.fillWidth: true
                            wrapMode: Text.Wrap
                            text: Theme.plural(modelData.tasks, "task") + " · " + Theme.plural(modelData.steps, "step")
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: backend.historyModel
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
            delegate: Item {
                id: row
                required property string kind
                required property string text
                required property string sub
                required property string timeLabel
                required property string taskId
                width: list.width
                height: Math.max(44, col.implicitHeight + 12)
                // Click opens the task: a finished task shows read-only (notes, steps, delete).
                Rectangle { anchors.fill: parent; color: Theme.hover; visible: rowMouse.containsMouse }
                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (backend.taskInfo(row.taskId).exists) appWindow.openEditor(row.taskId)
                }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.s4
                    anchors.rightMargin: Theme.s4
                    spacing: Theme.s3
                    Rectangle {
                        width: 18; height: 18; radius: 9
                        color: row.kind === "task" ? Theme.success : "transparent"
                        border.width: row.kind === "task" ? 0 : 1.5
                        border.color: Theme.success
                        Icon { anchors.centerIn: parent; name: "check"; size: 10; color: row.kind === "task" ? "white" : Theme.success }
                    }
                    ColumnLayout {
                        id: col
                        Layout.fillWidth: true
                        spacing: 0
                        Label {
                            Layout.fillWidth: true
                            text: row.text
                            wrapMode: Text.Wrap
                            font.weight: row.kind === "task" ? Font.DemiBold : Font.Normal
                        }
                        Label {
                            Layout.fillWidth: true
                            text: row.sub
                            wrapMode: Text.Wrap
                            color: Theme.subtext
                            font.pixelSize: Theme.fontSmall
                        }
                    }
                    Label { text: row.timeLabel; color: Theme.subtext; font.pixelSize: Theme.fontSmall }
                }
            }
            Label {
                anchors.centerIn: parent
                width: parent.width - 2 * Theme.s6
                visible: list.count === 0
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: "Everything you finish will show up here."
                color: Theme.subtext
            }
        }
    }
}
