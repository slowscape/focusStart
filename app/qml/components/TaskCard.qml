import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// My Day card. Tap expands in place; play opens Focus; "..." opens the task menu.
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
    required property int index
    property bool expanded: false
    readonly property var steps: backend.stepModel(itemId)
    readonly property var doneSteps: backend.doneStepModel(itemId)
    readonly property bool hasSteps: stepTotal > 0

    width: ListView.view ? ListView.view.width : 300
    implicitHeight: col.implicitHeight + 2 * Theme.s3
    height: implicitHeight
    radius: Theme.radius
    color: Theme.card
    border.color: Theme.cardBorder
    clip: true

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
            Label {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                text: card.title
                wrapMode: Text.Wrap
                maximumLineCount: card.expanded ? 6 : 2
                elide: Text.ElideRight
                font.pixelSize: Theme.fontBody + 1
                font.weight: Font.DemiBold
                TapHandler { onTapped: card.expanded = !card.expanded }
            }
            // Start and "..." sit together as one compact pair.
            RowLayout {
                Layout.alignment: Qt.AlignTop
                spacing: 0
                IconButton {
                    icon_: "play"; tip: "Start"
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
            delegate: StepRow {
                taskId: card.itemId
                shown: card.expanded || index < 3
                onCompleted: (checkItem) => appWindow.completeStep(card.itemId, itemId, checkItem, card)
            }
            add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.durMed } }
            // No "displaced" transition: rows collapse their own height on removal, and the
            // rows below follow it. A displaced animation fights that collapse (rows jump up
            // behind the title, then drop back down).
        }
        Label {
            visible: !card.expanded && card.stepRemaining > 3
            text: "+" + (card.stepRemaining - 3) + " more"
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
            Layout.leftMargin: 34
            TapHandler { onTapped: card.expanded = true }
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
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    font.pixelSize: Theme.fontBody
                }
            }
        }
        Label {
            visible: card.expanded && card.notes !== ""
            Layout.fillWidth: true
            Layout.topMargin: Theme.s1
            text: card.notes
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
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
