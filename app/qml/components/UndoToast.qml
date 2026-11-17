import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Completion toast with Undo, ~5 s.
Rectangle {
    id: toast
    property string message: ""
    property string token: ""
    signal undoRequested(string token)
    function show(msg, tok) {
        message = msg; token = tok || ""
        open = true
        timer.restart()
    }
    function hide() { open = false; timer.stop() }
    property bool open: false

    width: Math.min(parent ? parent.width - 2 * Theme.s4 : 340, 360)
    height: 44
    radius: Theme.radius
    color: Theme.dark ? "#2b2b2b" : "#ffffff"
    border.color: Theme.cardBorder
    opacity: open ? 1 : 0
    visible: opacity > 0
    y: open ? baseY : baseY + 12
    property real baseY: 0
    Behavior on opacity { NumberAnimation { duration: Theme.durMed } }
    Behavior on y { NumberAnimation { duration: Theme.durMed; easing.type: Easing.OutCubic } }

    Timer { id: timer; interval: 5000; onTriggered: toast.open = false }
    HoverHandler { onHoveredChanged: if (hovered) timer.stop(); else if (toast.open) timer.restart() }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.s4
        anchors.rightMargin: Theme.s1
        spacing: Theme.s2
        Label {
            Layout.fillWidth: true
            text: toast.message
            elide: Text.ElideRight
            font.pixelSize: Theme.fontBody
        }
        Button {
            visible: toast.token !== ""
            text: "Undo"
            flat: true
            focusPolicy: Qt.NoFocus
            onClicked: { toast.undoRequested(toast.token); toast.hide() }
        }
    }
}
