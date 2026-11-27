import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Small "Edit" / "Done" text button for notes (pencil / check icon). Never takes focus, so
// clicking Done doesn't pull focus away mid-save, and Edit can't be hit by accident from the keyboard.
AbstractButton {
    id: btn
    property bool editing: false
    hoverEnabled: true
    focusPolicy: Qt.NoFocus
    padding: 0
    leftPadding: 6; rightPadding: 8
    implicitHeight: 24
    implicitWidth: row.implicitWidth + leftPadding + rightPadding
    Accessible.name: editing ? "Done editing" : "Edit"
    background: Rectangle { radius: 6; color: btn.hovered ? Theme.hover : "transparent" }
    contentItem: Item {
        RowLayout {
            id: row
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Icon { name: btn.editing ? "check" : "edit"; size: 12; color: Theme.accent }
            Label { text: btn.editing ? "Done" : "Edit"; color: Theme.accent; font.pixelSize: Theme.fontSmall }
        }
    }
}
