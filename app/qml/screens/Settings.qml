import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../theme"

Item {
    id: screen
    Flickable {
        id: flick
        anchors.fill: parent
        contentHeight: col.implicitHeight + Theme.s6
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}
        ColumnLayout {
            id: col
            x: Theme.s4
            width: flick.width - 2 * Theme.s4
            spacing: Theme.s2

            Label { text: "Settings"; font.pixelSize: Theme.fontHero; font.weight: Font.DemiBold; Layout.topMargin: Theme.s2; Layout.bottomMargin: Theme.s2 }

            Label { text: "Sound"; font.weight: Font.DemiBold }
            Switch {
                text: backend.sound ? "On" : "Off"
                checked: backend.sound
                onToggled: backend.sound = checked
            }
            RowLayout {
                Layout.fillWidth: true
                enabled: backend.sound
                Label { text: "Volume"; color: Theme.subtext }
                Slider {
                    Layout.fillWidth: true
                    from: 0; to: 1
                    value: backend.volume
                    onMoved: backend.volume = value
                    onPressedChanged: if (!pressed) backend.previewVolume()
                }
            }

            Label { text: "Effects"; font.weight: Font.DemiBold; Layout.topMargin: Theme.s3 }
            ButtonGroup { id: fxGroup }
            RadioButton { text: "Full: sound, motion and confetti"; ButtonGroup.group: fxGroup; checked: backend.effects === "full"; onClicked: backend.effects = "full" }
            RadioButton { text: "Calm: sound and a small checkmark"; ButtonGroup.group: fxGroup; checked: backend.effects === "calm"; onClicked: backend.effects = "calm" }
            RadioButton { text: "Off: silent and still"; ButtonGroup.group: fxGroup; checked: backend.effects === "off"; onClicked: backend.effects = "off" }

            Label { text: "Pomodoro timer"; font.weight: Font.DemiBold; Layout.topMargin: Theme.s3 }
            Switch {
                text: backend.pomoEnabled ? "On" : "Off"
                checked: backend.pomoEnabled
                onToggled: backend.pomoSetEnabled(checked)
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                text: backend.pomoEnabled ? "Starts when you press a task's Start arrow. You can also turn it off for one task in Edit task."
                                          : "Shown greyed out. Turn it on here or with its power button."
            }

            Label { text: "Week starts on"; font.weight: Font.DemiBold; Layout.topMargin: Theme.s3 }
            ButtonGroup { id: wkGroup }
            RowLayout {
                RadioButton { text: "Monday"; ButtonGroup.group: wkGroup; checked: backend.weekStarts === "monday"; onClicked: backend.weekStarts = "monday" }
                RadioButton { text: "Sunday"; ButtonGroup.group: wkGroup; checked: backend.weekStarts === "sunday"; onClicked: backend.weekStarts = "sunday" }
            }

            Label { text: "Data folder"; font.weight: Font.DemiBold; Layout.topMargin: Theme.s3 }
            Label {
                Layout.fillWidth: true
                text: backend.dataDir
                wrapMode: Text.WrapAnywhere
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
            }
            Button { text: "Open folder"; onClicked: backend.openDataFolder() }
            Label {
                Layout.fillWidth: true
                Layout.topMargin: Theme.s2
                wrapMode: Text.Wrap
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                text: "To keep data elsewhere (for example a OneDrive folder), start with:\nlaunch.bat --data-dir \"D:\\path\\to\\folder\""
            }
            Label {
                Layout.topMargin: Theme.s4
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                text: "Shortcuts: Ctrl+N new task \u00B7 Esc back \u00B7 Space/Enter step complete (Focus) \u00B7 \u2192 skip step"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
    }
}
