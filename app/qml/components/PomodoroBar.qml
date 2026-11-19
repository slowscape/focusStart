import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Compact Pomodoro timer. Focus -> break advances on its own with one soft chime. When a
// break ends, a full-window "Continue?" prompt appears (BreakOverOverlay in Main.qml).
// Tap the time to change durations (live). The square stop button stops and resets it.
// Turning the timer off entirely is only in Settings (all tasks) or Edit task (one task);
// then the screen hides this bar.
Rectangle {
    id: bar
    readonly property string phase: backend.pomoPhase
    readonly property bool onBreak: phase === "short" || phase === "long"
    implicitHeight: 44
    radius: Theme.radius
    color: onBreak ? Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.14)
                   : Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
    function fmt(sec) { return Math.floor(sec / 60) + ":" + ("0" + sec % 60).slice(-2) }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.s3
        anchors.rightMargin: Theme.s1
        spacing: Theme.s2
        ColumnLayout {
            spacing: 0
            Label {
                text: backend.pomoWaiting ? "Ready when you are"
                      : bar.phase === "work" ? "Focus" : bar.phase === "short" ? "Short break"
                      : bar.phase === "long" ? "Long break" : "Ready"
                font.pixelSize: Theme.fontSmall
                font.weight: Font.DemiBold
                color: bar.onBreak ? Theme.success : Theme.accent
            }
            Row {  // focus sessions done in this cycle
                spacing: 3
                Repeater {
                    model: backend.pomoLongEvery
                    Rectangle {
                        required property int index
                        width: 6; height: 6; radius: 3
                        color: index < backend.pomoWorkDone ? (bar.onBreak ? Theme.success : Theme.accent) : Theme.track
                    }
                }
            }
        }
        Item { Layout.fillWidth: true }
        AbstractButton {
            id: timeButton
            hoverEnabled: true
            implicitWidth: timeLabel.implicitWidth + 12
            implicitHeight: 32
            onClicked: editPopup.open()
            background: Rectangle { radius: 6; color: timeButton.hovered ? Theme.hover : "transparent" }
            contentItem: Label {
                id: timeLabel
                text: bar.fmt(backend.pomoRunning ? backend.pomoRemaining : backend.pomoWork * 60)
                font.pixelSize: Theme.fontTitle
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                opacity: backend.pomoPaused ? 0.5 : 1
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            ToolTip.visible: hovered
            ToolTip.delay: 500
            ToolTip.text: "Change times"
        }
        IconButton {
            icon_: backend.pomoRunning && !backend.pomoPaused ? "pause" : "play"
            tip: backend.pomoRunning && !backend.pomoPaused ? "Pause" : (backend.pomoRunning ? "Resume" : "Start")
            iconSize: 14
            onClicked: backend.pomoTogglePause()
        }
        IconButton {
            icon_: "stop"
            tip: "Stop and reset"
            iconSize: 12
            iconColor: Theme.subtext
            enabled: backend.pomoRunning
            onClicked: backend.pomoStop()
        }
    }

    Popup {
        id: editPopup
        y: bar.height + 4
        x: Math.max(0, bar.width - width)
        // Wide enough for the label plus Fluent's wide SpinBox (220 px squeezed the labels
        // into the number fields). Fluent adds its own padding/insets: set them all.
        width: Math.min(280, appWindow.width - 2 * Theme.s3)
        padding: Theme.s3
        topPadding: Theme.s3; bottomPadding: Theme.s3; leftPadding: Theme.s3; rightPadding: Theme.s3
        topInset: 0; bottomInset: 0; leftInset: 0; rightInset: 0
        focus: true
        contentItem: ColumnLayout {
            spacing: Theme.s2
            Label { text: "Minutes"; font.weight: Font.DemiBold }
            Repeater {
                model: [
                    { key: "work", label: "Focus" },
                    { key: "short", label: "Short break" },
                    { key: "long", label: "Long break" }
                ]
                delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Theme.s2
                    Label {
                        text: modelData.label
                        Layout.fillWidth: true
                        Layout.minimumWidth: 40
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignVCenter
                    }
                    SpinBox {
                        Layout.preferredWidth: 120
                        Layout.maximumWidth: 120
                        from: 1; to: backend.pomoMax[modelData.key]
                        editable: true
                        value: modelData.key === "work" ? backend.pomoWork
                             : modelData.key === "short" ? backend.pomoShort : backend.pomoLong
                        onValueModified: backend.pomoSetMinutes(modelData.key, value)
                    }
                }
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                text: "Long break after every " + backend.pomoLongEvery + " focus sessions. Changes apply right away."
            }
        }
    }
}
