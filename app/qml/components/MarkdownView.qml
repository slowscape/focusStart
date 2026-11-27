import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Reading view for notes: **bold**, *italic*, [links](https://...), --- lines, bullets, and
// checkbox lines you can tick. All text can be selected and copied (SelectableText). `blocks` comes from backend.mdBlocks (core/notes.py): runs of
// ordinary lines render through Qt's own markdown (Text.MarkdownText, no extra library);
// checkbox lines are rows with a circle. Ticking emits checkToggled(line); links open in the
// browser (web/mail only, backend.openLink).
ColumnLayout {
    id: view
    property var blocks: []
    property int fontSize: Theme.fontBody
    signal checkToggled(int line)
    spacing: 4

    Repeater {
        model: view.blocks
        delegate: Item {
            id: blk
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: modelData.kind === "check" ? checkRow.implicitHeight
                          : modelData.kind === "title" ? titleText.implicitHeight : mdText.implicitHeight

            SelectableText {    // the note's title (first line)
                id: titleText
                visible: blk.modelData.kind === "title"
                width: parent.width
                text: blk.modelData.kind === "title" ? blk.modelData.text : ""
                textFormat: TextEdit.PlainText
                font.pixelSize: Theme.fontTitle
                font.weight: Font.DemiBold
            }
            SelectableText {     // ordinary lines: Qt's markdown
                id: mdText
                visible: blk.modelData.kind === "md"
                width: parent.width
                text: blk.modelData.kind === "md" ? blk.modelData.markdown : ""
                font.pixelSize: view.fontSize
            }
            RowLayout {  // a checkbox line
                id: checkRow
                visible: blk.modelData.kind === "check"
                width: parent.width
                spacing: Theme.s1
                Item { implicitWidth: (blk.modelData.indent || 0) * 16; visible: implicitWidth > 0 }
                CheckCircle {
                    diameter: 16
                    Layout.alignment: Qt.AlignTop
                    done: blk.modelData.done === true
                    allowUncheck: true
                    focusPolicy: Qt.NoFocus
                    onToggledOn: view.checkToggled(blk.modelData.line)
                    onToggledOff: view.checkToggled(blk.modelData.line)
                }
                SelectableText {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    text: blk.modelData.kind === "check" ? blk.modelData.markdown : ""
                    color: blk.modelData.done ? Theme.subtext : Theme.textColor
                    font.strikeout: blk.modelData.done === true
                    font.pixelSize: view.fontSize
                }
            }
        }
    }
}
