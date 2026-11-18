import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Task card (My Day and Lists). Nothing is cut short: the card grows to show the whole
// title and every remaining step. Click the title to open Focus (without starting the
// timer); drag the title to reorder cards; drag a step's text to reorder steps.
// Start (play) opens Focus and starts the timer; "..." opens the task menu.
Rectangle {
    id: card
    required property string itemId
    required property string title
    required property string notes
    required property string listId
    required property int stepTotal
    required property int stepDone
    required property int stepRemaining
    required property bool completedOpen
    required property var tagColors
    required property var tagNames
    required property string repeat
    required property int index
    readonly property var steps: backend.stepModel(itemId)
    readonly property var doneSteps: backend.doneStepModel(itemId)
    readonly property bool hasSteps: stepTotal > 0
    // The screen hosting the list handles a drop (it knows which tasks are in view).
    signal reorder(int from, int to)

    width: ListView.view ? ListView.view.width : 300
    implicitHeight: col.implicitHeight + 2 * Theme.s3
    height: implicitHeight
    radius: Theme.radius
    color: Theme.card
    border.color: titleDrag.dragging ? Theme.accent : Theme.cardBorder
    clip: true
    transform: Translate { y: titleDrag.offset }
    scale: titleDrag.dragging ? 1.02 : 1
    Behavior on scale { NumberAnimation { duration: Theme.durFast } }

    Rectangle {
        anchors.fill: parent; radius: parent.radius
        color: Theme.hover
        visible: cardHover.hovered
    }
    HoverHandler { id: cardHover }

    ColumnLayout {
        id: col
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.margins: Theme.s3
        spacing: Theme.s1

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s2
            CheckCircle {
                id: taskCheck
                visible: !card.hasSteps
                Layout.alignment: Qt.AlignTop
                onToggledOn: appWindow.completeTask(card.itemId, taskCheck, card)
            }
            StepRing {
                visible: card.hasSteps
                total: card.stepTotal
                done: card.stepDone
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 3
                Layout.leftMargin: 2
                Layout.rightMargin: 2
            }
            TagDots {
                colors: card.tagColors
                names: card.tagNames
                Layout.alignment: Qt.AlignTop
                Layout.topMargin: 9
            }
            Label {
                id: titleLabel
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: card.title + (card.repeat !== "" ? "  ↻" : "")
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontBody + 1
                font.weight: Font.DemiBold
                ReorderArea {
                    id: titleDrag
                    anchors.fill: parent
                    row: card
                    view: card.ListView.view
                    index: card.index
                    indicator: card.ListView.view ? (card.ListView.view.dropLine || null) : null
                    onTapped: appWindow.openFocus(card.itemId, false, true)
                    onDropped: (from, to) => card.reorder(from, to)
                }
                ToolTip.visible: titleDrag.containsMouse && !titleDrag.dragging
                ToolTip.delay: 900
                ToolTip.text: "Click to open · drag to move"
            }
            // Start and "..." sit together as one compact pair.
            RowLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 0
                IconButton {
                    icon_: "play"; tip: "Start (with timer)"
                    implicitWidth: 32
                    iconColor: Theme.accent
                    onClicked: appWindow.openFocus(card.itemId)
                }
                IconButton {
                    icon_: "more"; tip: "More"
                    implicitWidth: 32
                    onClicked: menu.popup()
                    TaskMenu { id: menu; taskId: card.itemId; listId: card.listId }
                }
            }
        }

        ListView {
            id: stepList
            Layout.fillWidth: true
            Layout.leftMargin: 4
            implicitHeight: contentHeight
            interactive: false
            visible: card.hasSteps
            model: card.steps
            property Item dropLine: stepLine
            delegate: StepRow {
                taskId: card.itemId
                onCompleted: (checkItem) => appWindow.completeStep(card.itemId, itemId, checkItem, card)
                onReorder: (from, to) => {
                    var it = card.steps.get(from)
                    if (it && it.id) backend.moveStep(card.itemId, it.id, to)
                }
            }
            add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durMed } }
            // No "displaced" transition: rows collapse their own height on removal, and the
            // rows below follow it. A displaced animation fights that collapse (rows jump up
            // behind the title, then drop back down).
            Rectangle { id: stepLine; visible: false; z: 50; width: parent.width; height: 2; radius: 1; color: Theme.accent }
        }
        // Completed steps, rolled up. Open/closed is remembered per task; new tasks start closed.
        AbstractButton {
            id: doneToggle
            visible: card.stepDone > 0
            Layout.leftMargin: 4
            Layout.topMargin: 2
            implicitHeight: 26
            implicitWidth: doneRow.implicitWidth
            hoverEnabled: true
            onClicked: backend.setCompletedOpen(card.itemId, !card.completedOpen)
            contentItem: RowLayout {
                id: doneRow
                spacing: Theme.s1
                Icon { name: card.completedOpen ? "chevron" : "chevronR"; size: 10; color: Theme.subtext }
                Label {
                    text: "Completed (" + card.stepDone + ")"
                    color: doneToggle.hovered ? Theme.textColor : Theme.subtext
                    font.pixelSize: Theme.fontSmall
                }
            }
        }
        Repeater {
            model: card.completedOpen ? card.doneSteps : null
            delegate: RowLayout {
                required property string itemId
                required property string text
                Layout.fillWidth: true
                Layout.leftMargin: 4
                spacing: Theme.s2
                CheckCircle {
                    diameter: 18
                    done: true
                    allowUncheck: true
                    Layout.alignment: Qt.AlignTop
                    onToggledOff: backend.restoreStep(card.itemId, parent.itemId)
                    ToolTip.visible: hovered
                    ToolTip.delay: 600
                    ToolTip.text: "Mark not done"
                }
                Label {
                    Layout.fillWidth: true
                    text: parent.text
                    color: Theme.subtext
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontBody
                }
            }
        }
        Button {
            visible: !card.hasSteps
            text: "Add steps"
            flat: true
            Layout.leftMargin: 26
            font.pixelSize: Theme.fontSmall
            onClicked: appWindow.openPlan(card.itemId)
        }
    }

    ListView.onRemove: { card.ListView.delayRemove = true; removeAnim.start() }
    SequentialAnimation {
        id: removeAnim
        PauseAnimation { duration: Theme.motion ? 380 : 0 }
        ParallelAnimation {
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: Theme.durMed }
            NumberAnimation { target: card; property: "height"; to: 0; duration: Theme.durSlow; easing.type: Easing.InOutCubic }
        }
        PropertyAction { target: card; property: "ListView.delayRemove"; value: false }
    }
}
