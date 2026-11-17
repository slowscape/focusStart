import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

// Small month picker. Emits ISO yyyy-mm-dd (local date, built from y/m/d parts).
Popup {
    id: dp
    signal picked(string iso)
    property int year: new Date().getFullYear()
    property int month: new Date().getMonth()
    modal: true
    focus: true
    anchors.centerIn: Overlay.overlay
    width: Math.min(300, (parent ? parent.width : 300) - 32)
    padding: Theme.s3
    onAboutToShow: { var d = new Date(); year = d.getFullYear(); month = d.getMonth() }

    function pad(n) { return (n < 10 ? "0" : "") + n }
    function step(delta) {
        var m = month + delta
        year += Math.floor(m / 12)
        month = ((m % 12) + 12) % 12
    }

    contentItem: ColumnLayout {
        spacing: Theme.s2
        RowLayout {
            Layout.fillWidth: true
            IconButton { icon_: "back"; tip: "Previous month"; onClicked: dp.step(-1) }
            Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.weight: Font.DemiBold
                text: Qt.locale().standaloneMonthName(dp.month) + " " + dp.year
            }
            IconButton { icon_: "next"; tip: "Next month"; onClicked: dp.step(1) }
        }
        DayOfWeekRow {
            Layout.fillWidth: true
            locale: grid.locale
            delegate: Label {
                required property string shortName
                text: shortName
                horizontalAlignment: Text.AlignHCenter
                color: Theme.subtext
                font.pixelSize: Theme.fontSmall
            }
        }
        MonthGrid {
            id: grid
            Layout.fillWidth: true
            month: dp.month
            year: dp.year
            delegate: AbstractButton {
                id: cell
                required property var model
                readonly property bool inMonth: model.month === grid.month
                readonly property bool isToday: model.today
                implicitHeight: 34
                hoverEnabled: true
                background: Rectangle {
                    radius: height / 2
                    color: cell.isToday ? Theme.accent : (cell.hovered ? Theme.hover : "transparent")
                }
                contentItem: Label {
                    text: cell.model.day
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    opacity: cell.inMonth ? 1 : 0.35
                    color: cell.isToday ? "white" : Theme.textColor
                }
                onClicked: {
                    dp.picked(model.year + "-" + dp.pad(model.month + 1) + "-" + dp.pad(model.day))
                    dp.close()
                }
            }
        }
        Button { Layout.alignment: Qt.AlignRight; text: "Cancel"; flat: true; onClicked: dp.close() }
    }
}
