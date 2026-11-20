import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Full-window prompt when a Pomodoro break ends, so the next focus session doesn't wait
// forgotten: "Continue <task> <step>?" with Continue (back to Focus, timer runs) or
// End Task (timer stopped and reset, back to My Day).
Rectangle {
    id: ov
    property string taskId: ""
    readonly property var info: taskId ? (backend.revision, backend.taskInfo(taskId)) : ({})
    readonly property bool open: visible
    signal continueTask(string taskId)
    signal endTask()
    function show(id) { taskId = id; visible = true; continueBtn.forceActiveFocus() }
    function hide() { visible = false }

    visible: false
    color: Theme.windowColor
    // Swallow clicks so nothing underneath reacts.
    MouseArea { anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.AllButtons }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * Theme.s6, 420)
        spacing: Theme.s3

        // This task's own progress: one segment per step, green = done.
        StepRing {
            Layout.alignment: Qt.AlignHCenter
            visible: (ov.info.stepTotal || 0) > 0
            implicitWidth: 56; implicitHeight: 56
            lineWidth: 5
            total: ov.info.stepTotal || 0
            done: ov.info.stepDone || 0
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            visible: (ov.info.stepTotal || 0) > 0
            text: (ov.info.stepDone || 0) + " of " + Theme.plural(ov.info.stepTotal || 0, "step") + " done"
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "Break's over. Continue"
            color: Theme.subtext
            font.pixelSize: Theme.fontBody
        }
        Label {
            Layout.fillWidth: true
            visible: (ov.info.title || "") !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: ov.info.title || ""
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall + 1
        }
        Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: (ov.info.currentStep || ov.info.title || "where you left off") + "?"
            font.pixelSize: Theme.fontTitle + 2
            font.weight: Font.DemiBold
        }
        Item { implicitHeight: Theme.s2 }
        Button {
            id: continueBtn
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            highlighted: true
            text: "Continue"
            font.pixelSize: Theme.fontTitle - 4
            onClicked: { ov.hide(); ov.continueTask(ov.taskId) }
            Keys.onReturnPressed: clicked()
            Keys.onEnterPressed: clicked()
        }
        Button {
            Layout.fillWidth: true
            flat: true
            text: "End Task"
            onClicked: { ov.hide(); ov.endTask() }
        }
    }
}
