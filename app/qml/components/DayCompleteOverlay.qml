import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Full-window overlay card for Day complete.
Item {
    id: ov
    property bool open: false
    property int tasks: 0
    property int steps: 0
    signal planTomorrow()
    function show(t, s) { tasks = t; steps = s; open = true }
    function hide() { open = false }
    visible: opacity > 0
    opacity: open ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.durSlow } }

    Rectangle { anchors.fill: parent; color: Theme.scrim }
    MouseArea { anchors.fill: parent; onClicked: {} }   // modal

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 2 * Theme.s6, 320)
        height: col.implicitHeight + 2 * Theme.s6
        radius: 12
        color: Theme.dark ? "#2b2b2b" : "#ffffff"
        border.color: Theme.cardBorder
        scale: ov.open ? 1 : 0.92
        Behavior on scale { NumberAnimation { duration: Theme.motion ? 320 : 0; easing.type: Easing.OutBack } }

        ColumnLayout {
            id: col
            anchors.fill: parent
            anchors.margins: Theme.s6
            spacing: Theme.s3
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 56; height: 56; radius: 28
                color: Theme.success
                Icon { anchors.centerIn: parent; name: "check"; size: 26; color: "white" }
            }
            Label {
                Layout.alignment: Qt.AlignHCenter
                text: "Day complete"
                font.pixelSize: Theme.fontHero
                font.weight: Font.DemiBold
            }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Theme.plural(ov.tasks, "task") + " and " + Theme.plural(ov.steps, "step") + " today. Nice work."
                color: Theme.subtext
            }
            Item { implicitHeight: Theme.s1 }
            Button {
                Layout.fillWidth: true
                text: "Plan tomorrow"
                highlighted: true
                onClicked: { ov.hide(); ov.planTomorrow() }
            }
            Button {
                Layout.fillWidth: true
                text: "Close"
                flat: true
                onClicked: ov.hide()
            }
        }
    }
}
