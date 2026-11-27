import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Small formatting bar above a MarkdownField: bold, italic, link, horizontal line, bullet,
// checkbox. Acts on the field's selection (the text transforms live in core/notes.py). The
// buttons never take focus, so the selection survives the click.
RowLayout {
    id: bar
    property Item target: null            // the MarkdownField being edited
    spacing: 2

    function apply(r) {
        if (!target || !r) return
        target.text = r.text
        target.select(r.start, r.end)
        target.forceActiveFocus()
    }
    function sel() { return { s: target.selectionStart, e: target.selectionEnd } }

    ToolButtonIcon { icon_: "bold"; tip: "Bold"; onClicked: { var x = bar.sel(); bar.apply(backend.mdWrap(bar.target.text, x.s, x.e, "**")) } }
    ToolButtonIcon { icon_: "italic"; tip: "Italic"; onClicked: { var x = bar.sel(); bar.apply(backend.mdWrap(bar.target.text, x.s, x.e, "*")) } }
    ToolButtonIcon { icon_: "link"; tip: "Link"; onClicked: linkPopup.openFor(bar.target.selectedText) }
    ToolButtonIcon { icon_: "rule"; tip: "Line"; onClicked: bar.apply(backend.mdRule(bar.target.text, bar.target.cursorPosition)) }
    ToolButtonIcon { icon_: "bullets"; tip: "Bullets"; onClicked: { var x = bar.sel(); bar.apply(backend.mdPrefix(bar.target.text, x.s, x.e, "bullet")) } }
    ToolButtonIcon { icon_: "checkbox"; tip: "Checkbox"; onClicked: { var x = bar.sel(); bar.apply(backend.mdPrefix(bar.target.text, x.s, x.e, "check")) } }
    Item { Layout.fillWidth: true }

    component ToolButtonIcon: AbstractButton {
        id: tbi
        property string icon_
        property string tip
        implicitWidth: 30; implicitHeight: 28
        hoverEnabled: true
        focusPolicy: Qt.NoFocus
        padding: 0
        background: Rectangle { radius: 6; color: tbi.hovered ? Theme.hover : "transparent"; border.color: Theme.cardBorder }
        contentItem: Item { Icon { anchors.centerIn: parent; name: tbi.icon_; size: 14 } }
        ToolTip.visible: hovered
        ToolTip.delay: 500
        ToolTip.text: tip
        Accessible.name: tip
    }

    // Link: asks for the address (and the words to show when nothing is selected).
    Popup {
        id: linkPopup
        property int selStart: 0
        property int selEnd: 0
        function openFor(selected) {
            selStart = bar.target.selectionStart; selEnd = bar.target.selectionEnd
            labelField.text = ""; urlField.text = "https://"
            labelField.visible = selected === ""
            open(); urlField.forceActiveFocus(); urlField.selectAll()
        }
        function commit() {
            var url = urlField.text.trim()
            close()
            if (url === "" || url === "https://") { bar.target.forceActiveFocus(); return }
            bar.apply(backend.mdLink(bar.target.text, selStart, selEnd, url, labelField.text))
        }
        y: bar.height + 4
        width: Math.min(300, appWindow.width - 32)
        padding: Theme.s3
        topPadding: Theme.s3; bottomPadding: Theme.s3; leftPadding: Theme.s3; rightPadding: Theme.s3
        topInset: 0; bottomInset: 0; leftInset: 0; rightInset: 0
        modal: true
        focus: true
        contentItem: ColumnLayout {
            spacing: Theme.s2
            Label { text: "Add a link"; font.weight: Font.DemiBold }
            TextField { id: labelField; Layout.fillWidth: true; placeholderText: "Text to show"; onAccepted: urlField.forceActiveFocus() }
            TextField { id: urlField; Layout.fillWidth: true; onAccepted: linkPopup.commit() }
            RowLayout {
                Item { Layout.fillWidth: true }
                Button { text: "Cancel"; flat: true; onClicked: { linkPopup.close(); bar.target.forceActiveFocus() } }
                Button { text: "Add"; highlighted: true; onClicked: linkPopup.commit() }
            }
        }
    }
}
