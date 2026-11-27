import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
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

            Label { text: "Appearance"; font.weight: Font.DemiBold }
            ButtonGroup { id: appearanceGroup }
            RowLayout {
                RadioButton { text: "System"; ButtonGroup.group: appearanceGroup; checked: backend.appearance === "system"; onClicked: backend.appearance = "system" }
                RadioButton { text: "Light"; ButtonGroup.group: appearanceGroup; checked: backend.appearance === "light"; onClicked: backend.appearance = "light" }
                RadioButton { text: "Dark"; ButtonGroup.group: appearanceGroup; checked: backend.appearance === "dark"; onClicked: backend.appearance = "dark" }
            }

            Label { text: "Sound"; font.weight: Font.DemiBold; Layout.topMargin: Theme.s3 }
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
                                          : "Hidden everywhere."
            }
            CheckBox {
                visible: backend.pomoEnabled
                text: "Display Pomodoro on notch"
                checked: backend.pomoNotch
                onToggled: backend.pomoSetNotch(checked)
            }
            Label {
                visible: backend.pomoEnabled
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                text: "Shows the timer at the top of the screen while it runs, even when StepTask is in the background."
            }

            // ---------------- tags
            Label { text: "Tags"; font.weight: Font.DemiBold; Layout.topMargin: Theme.s3 }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                text: "Type #name when adding a task to tag it. Click a dot to change its colour."
            }
            Repeater {
                model: backend.tagsModel
                RowLayout {
                    id: tagRow
                    required property string itemId
                    required property string name
                    required property string color
                    Layout.fillWidth: true
                    spacing: Theme.s2
                    AbstractButton {
                        implicitWidth: 28; implicitHeight: 28
                        onClicked: colorMenu.popup()
                        contentItem: Item {
                            Rectangle { anchors.centerIn: parent; width: 16; height: 16; radius: 8; color: tagRow.color }
                        }
                        background: Rectangle { radius: 14; color: parent.hovered ? Theme.hover : "transparent" }
                        Menu {
                            id: colorMenu
                            width: 8 * 30 + 16
                            topPadding: 6; bottomPadding: 6; leftPadding: 8; rightPadding: 8
                            Row {
                                spacing: 2
                                Repeater {
                                    model: backend.tagPalette
                                    AbstractButton {
                                        required property string modelData
                                        implicitWidth: 28; implicitHeight: 28
                                        onClicked: { backend.updateTag(tagRow.itemId, "", modelData); colorMenu.close() }
                                        contentItem: Item {
                                            Rectangle {
                                                anchors.centerIn: parent; width: 18; height: 18; radius: 9; color: modelData
                                                border.width: modelData === tagRow.color ? 2 : 0
                                                border.color: Theme.textColor
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    TextField {
                        Layout.fillWidth: true
                        text: tagRow.name
                        onEditingFinished: if (text.trim() && text.trim() !== tagRow.name) backend.updateTag(tagRow.itemId, text.trim(), "")
                    }
                    IconButton { icon_: "delete"; tip: "Delete tag (removes it from tasks)"; iconSize: 12; onClicked: backend.deleteTag(tagRow.itemId) }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                TextField {
                    id: newTag
                    Layout.fillWidth: true
                    placeholderText: "New tag"
                    onAccepted: { if (text.trim()) { backend.addTag(text.trim()); clear() } }
                }
                Button { text: "Add"; enabled: newTag.text.trim() !== ""; onClicked: { backend.addTag(newTag.text.trim()); newTag.clear() } }
            }

            // ---------------- background picture
            Label { text: "Background"; font.weight: Font.DemiBold; Layout.topMargin: Theme.s3 }
            Switch {
                text: backend.bgEnabled ? "Picture" : "Off (plain)"
                checked: backend.bgEnabled
                enabled: backend.bgFolder !== ""
                onToggled: backend.setBgEnabled(checked)
            }
            Label {
                Layout.fillWidth: true
                text: backend.bgFolder === "" ? "Choose a folder of pictures (jpg, png, webp...)."
                      : backend.bgFolder + "  ·  " + Theme.plural(backend.bgImageCount, "picture")
                wrapMode: Text.WrapAnywhere
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
            }
            RowLayout {
                Button { text: backend.bgFolder === "" ? "Choose folder…" : "Change folder…"; onClicked: bgDialog.open() }
                Button { text: "Open folder"; visible: backend.bgFolder !== ""; flat: true; onClicked: backend.openBgFolder() }
            }
            RowLayout {
                visible: backend.bgFolder !== ""
                enabled: backend.bgEnabled
                Label { text: "Change picture"; color: Theme.subtext }
                ComboBox {
                    Layout.fillWidth: true
                    textRole: "label"
                    valueRole: "value"
                    model: [
                        { value: 5, label: "Every 5 minutes" },
                        { value: 15, label: "Every 15 minutes" },
                        { value: 60, label: "Every hour" },
                        { value: 1440, label: "Once a day" }
                    ]
                    currentIndex: Math.max(0, [5, 15, 60, 1440].indexOf(backend.bgInterval))
                    onActivated: backend.setBgInterval(currentValue)
                }
            }
            FolderDialog {
                id: bgDialog
                title: "Folder of background pictures"
                onAccepted: backend.setBgFolder(selectedFolder.toString())
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
                text: Qt.platform.os === "windows"
                      ? "To keep data elsewhere (for example a OneDrive folder), start with:\nlaunch.bat --data-dir \"D:\\path\\to\\folder\""
                      : "To keep data elsewhere (for example a synced folder), start with:\n./launch.sh --data-dir \"$HOME/path/to/folder\""
            }
            Label {
                Layout.topMargin: Theme.s4
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
                text: "Shortcuts: " + (Qt.platform.os === "osx" ? "\u2318N" : "Ctrl+N") + " new task (new note on Notes) \u00B7 Esc back \u00B7 Space/Enter step complete (Focus) \u00B7 \u2192 skip step"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
        }
    }
}
