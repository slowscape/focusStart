import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

Item {
    id: screen
    readonly property int bottomInset: quick.height   // undo/info messages sit above the add box
    property bool focusQuickAdd: false
    // Date for the next add: "" = today, "tomorrow", or an ISO date from the calendar.
    property string addWhen: ""
    function focusAdd() { quick.focusField() }
    Component.onCompleted: if (focusQuickAdd) Qt.callLater(quick.focusField)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header: title + date | small Done badges | Print. The badges sit in a right-aligned
        // Flow that may shrink: when both don't fit (320 px minimum width) they stack instead
        // of widening the row. A row wider than the window pushed the whole page past the
        // right edge and cut off the cards.
        RowLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            Layout.leftMargin: Theme.s4
            Layout.rightMargin: Theme.s2
            Layout.topMargin: Theme.s2
            Layout.bottomMargin: Theme.s3
            spacing: Theme.s2
            ColumnLayout {
                spacing: 0
                Label { text: "My Day"; font.pixelSize: Theme.fontHero; font.weight: Font.DemiBold }
                Label { text: backend.todayLabel; color: Theme.subtext }
            }
            Flow {
                id: badges
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                layoutDirection: Qt.RightToLeft
                spacing: Theme.s1
                Chip {
                    compact: true
                    tone: true
                    visible: backend.tasksDoneToday > 0
                    text: backend.tasksDoneToday + (backend.tasksDoneToday === 1 ? " Task" : " Tasks") + " Done"
                    fill: Theme.successSoft
                }
                Chip {
                    compact: true
                    tone: true
                    visible: backend.stepsDoneToday > 0
                    text: backend.stepsDoneToday + (backend.stepsDoneToday === 1 ? " Step" : " Steps") + " Done"
                    fill: Theme.successSoft
                }
            }
            IconButton {
                icon_: "print"; tip: "Print (save as PDF)"
                Layout.alignment: Qt.AlignVCenter
                onClicked: appWindow.exportPdf("myday")
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.s3
            Layout.rightMargin: Theme.s3
            clip: true
            spacing: Theme.s2
            model: backend.myDayModel
            bottomMargin: Theme.s3
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            delegate: TaskCard {}
            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durMed }
                    NumberAnimation { property: "scale"; from: 0.97; to: 1; duration: Theme.durMed; easing.type: Easing.OutCubic }
                }
            }

            EmptyState {
                anchors.centerIn: parent
                visible: list.count === 0
                title: "All clear"
                actionText: "Add something for tomorrow"
                onAction: { screen.addWhen = "tomorrow"; quick.focusField() }
            }
        }

        QuickAdd {
            id: quick
            Layout.fillWidth: true
            readonly property string whenLabel: screen.addWhen === "" ? "" :
                (screen.addWhen === "tomorrow" ? "Tomorrow" : backend.dateLabel(screen.addWhen))
            placeholder: screen.addWhen === "" ? "Add a task\u2026  (/ picks a list)" : "Add for " + (screen.addWhen === "tomorrow" ? "tomorrow" : whenLabel) + "\u2026"
            chipCheckable: false
            chipChecked: screen.addWhen !== ""
            chipText: screen.addWhen === "" || screen.addWhen === "tomorrow" ? "Tomorrow" : whenLabel + "  \u2715"
            // With a task typed, Tomorrow / a picked date adds it right away (one-off).
            // With nothing typed, they set the date for the next adds, as before.
            onChipClicked: {
                if (quick.taskText() !== "") quick.submit("tomorrow")
                else screen.addWhen = (screen.addWhen === "" ? "tomorrow" : "")
            }
            showCalendar: true
            onCalendarClicked: appWindow.pickDate(function (iso) {
                var when = (iso <= backend.todayIso) ? "" : iso
                if (quick.taskText() !== "") quick.submit(when === "" ? "today" : when)
                else screen.addWhen = when
                quick.focusField()
            })
            onSubmitted: (text, listId, newListName) => {
                var when = quick.submitWhen || (screen.addWhen === "" ? "today" : screen.addWhen)
                backend.addTask(text, when, listId, newListName)
                if (when !== "today")
                    appWindow.toast("Added to " + (when === "tomorrow" ? "tomorrow" : backend.dateLabel(when)), "")
                else Qt.callLater(list.positionViewAtEnd)
            }
        }
    }
}
