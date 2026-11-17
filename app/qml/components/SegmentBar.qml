import QtQuick
import "../theme"

// Horizontal segmented progress for Focus view (done vs remaining).
Row {
    id: bar
    property int total: 0
    property int done: 0
    spacing: total > 16 ? 2 : 4
    height: 6
    Repeater {
        model: bar.total
        Rectangle {
            width: (bar.width - bar.spacing * (bar.total - 1)) / Math.max(1, bar.total)
            height: bar.height
            radius: 3
            color: index < bar.done ? Theme.success : Theme.track
            Behavior on color { ColorAnimation { duration: Theme.durSlow } }
        }
    }
}
