import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

// "List small actionable steps for 2 minutes": soft 2:00 timer, never force-stops.
Item {
    id: screen
    property string taskId
    property var info: (backend.revision, backend.taskInfo(taskId))
    property int secondsLeft: 120
    property string subline: "Small and concrete beats perfect."
    readonly property var steps: backend.stepModel(taskId)

    Component.onCompleted: Qt.callLater(input.forceActiveFocus)

    Timer {
        interval: 1000; repeat: true; running: screen.secondsLeft > 0
        onTriggered: {
            screen.secondsLeft -= 1
            ring.requestPaint()
            if (screen.secondsLeft === 0) {
                backend.playSound("chime")
                screen.subline = backend.planTimerDoneText()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.s4
        anchors.topMargin: Theme.s2
        spacing: Theme.s3

        RowLayout {
            Layout.fillWidth: true
            IconButton { icon_: "back"; tip: "Back (Esc)"; onClicked: appWindow.back() }
            Label {
                Layout.fillWidth: true
                text: screen.info.title || ""
                wrapMode: Text.Wrap
                color: Theme.subtext
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.s4
            Label {
                Layout.fillWidth: true
                text: "List small actionable steps for 2 minutes"
                font.pixelSize: Theme.fontTitle
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
            Canvas {
                id: ring
                implicitWidth: 64; implicitHeight: 64
                onPaint: {
                    var ctx = getContext("2d"); ctx.reset()
                    var cx = width / 2, cy = height / 2, r = width / 2 - 4
                    ctx.lineWidth = 5
                    ctx.strokeStyle = Theme.track
                    ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()
                    var f = screen.secondsLeft / 120
                    if (f > 0) {
                        ctx.strokeStyle = Theme.accent
                        ctx.lineCap = "round"
                        ctx.beginPath(); ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * f); ctx.stroke()
                    }
                }
                Label {
                    anchors.centerIn: parent
                    text: Math.floor(screen.secondsLeft / 60) + ":" + ("0" + screen.secondsLeft % 60).slice(-2)
                    font.pixelSize: Theme.fontBody
                    font.weight: Font.DemiBold
                }
            }
        }
        Label {
            Layout.fillWidth: true
            text: screen.subline
            color: screen.secondsLeft === 0 ? Theme.success : Theme.subtext
            wrapMode: Text.Wrap
        }

        StepInput {
            id: input
            Layout.fillWidth: true
            placeholderText: "Next small step\u2026"
            onAccepted: {
                if (text.trim()) {
                    backend.addStep(screen.taskId, text.trim())
                    clear()
                    Qt.callLater(list.positionViewAtEnd)
                }
            }
        }
        Label {
            Layout.fillWidth: true
            text: "List actionable steps"
            color: Theme.subtext
            font.pixelSize: Theme.fontSmall
            font.italic: true
            wrapMode: Text.Wrap
        }

        StepEditList {
            id: list
            taskId: screen.taskId
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        Button {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            text: "Get started"
            highlighted: true
            enabled: list.count > 0
            onClicked: appWindow.openFocus(screen.taskId, true)
        }
    }
}
