import QtQuick
import "../theme"

// Press and drag to reorder a ListView's rows; a plain click still counts as a click.
// Put it over the part of a delegate you grab (a title, a step's text). The delegate binds
// `transform: Translate { y: <this>.offset }` so the row follows the pointer while the
// ListView keeps managing its real position. On release, `dropped(from, to)` gives model
// indexes; the screen applies the move (backend.reorderTasks / moveStep / reorderLists).
// preventStealing keeps the ListView from scrolling while dragging; the wheel still scrolls.
MouseArea {
    id: ra
    property Item row                    // the delegate being dragged
    property ListView view               // the list it belongs to
    property int index: -1               // the row's model index
    property Item indicator: null        // optional drop line (a child of `view`)
    property int threshold: 6
    readonly property alias dragging: ra._dragging
    property real offset: 0
    signal tapped()
    signal dropped(int from, int to)
    // Hold still for `longPressMs` (when something listens: `longPressEnabled`): longPressed()
    // instead of tapped(). Moving first still drags.
    property bool longPressEnabled: false
    property int longPressMs: 500
    signal longPressed()
    property bool _longFired: false
    Timer {
        id: holdTimer
        interval: ra.longPressMs
        onTriggered: if (ra.pressed && !ra._dragging) { ra._longFired = true; ra.longPressed() }
    }

    property bool _dragging: false
    property real _startY: 0
    property int _target: -1

    preventStealing: true
    hoverEnabled: true
    cursorShape: _dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor

    function _contentY(m) { return mapToItem(view.contentItem, m.x, m.y).y }
    function _reset() {
        _dragging = false
        offset = 0
        _target = -1
        if (row) row.z = 0
        if (indicator) indicator.visible = false
    }
    function _targetIndex() {
        var cy = row.y + row.height / 2 + offset
        var i = view.indexAt(view.width / 2, cy)
        if (i < 0) i = cy < view.contentItem.childrenRect.y ? 0 : view.count - 1
        return i
    }

    onPressed: (m) => {
        _startY = _contentY(m); _dragging = false; _longFired = false
        if (longPressEnabled) holdTimer.restart()
    }
    onPositionChanged: (m) => {
        if (!pressed || !view || !row) return
        var y = _contentY(m)
        if (!_dragging && !_longFired && Math.abs(y - _startY) > threshold) { holdTimer.stop(); _dragging = true; row.z = 100 }
        if (!_dragging) return
        offset = y - _startY
        // Scroll when dragging near the top or bottom edge.
        var vy = mapToItem(view, m.x, m.y).y
        if (vy < 28 && view.contentY > view.originY) view.contentY = Math.max(view.originY, view.contentY - 12)
        else if (vy > view.height - 28 && view.contentY < view.contentHeight - view.height + view.originY)
            view.contentY = Math.min(view.contentHeight - view.height + view.originY, view.contentY + 12)
        _target = _targetIndex()
        if (indicator) {
            var it = view.itemAtIndex(_target)
            indicator.visible = it !== null && _target !== index
            if (it) indicator.y = (_target > index ? it.y + it.height : it.y) - view.contentY - indicator.height / 2
        }
    }
    onReleased: {
        holdTimer.stop()
        if (_longFired) { _longFired = false; return }      // the long press already acted
        if (_dragging) {
            var from = index, to = _targetIndex()
            _reset()
            if (to >= 0 && to !== from) dropped(from, to)
        } else {
            tapped()
        }
    }
    onCanceled: { holdTimer.stop(); _longFired = false; _reset() }
}
