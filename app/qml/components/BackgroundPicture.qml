import QtQuick

// Background picture, shown in its true colours, cropped to fill and centred.
// Two images take turns: the new one loads hidden, then they crossfade (0.1 s).
Item {
    id: bg
    property string source: ""
    property bool _showA: true
    readonly property int fade: 100

    function _flipWhenReady(img) {
        if (img.status === Image.Ready && img.source.toString() === bg.source && img !== (_showA ? a : b))
            _showA = (img === a)
    }
    onSourceChanged: {
        if (source === "") return
        if ((_showA ? a : b).source.toString() === source) return   // back on My Day: same picture
        var next = _showA ? b : a
        if (next.source.toString() === source) { _flipWhenReady(next); return }
        next.source = source
        _flipWhenReady(next)            // already cached: flip now; otherwise on load
    }

    readonly property bool _blank: source === ""      // fade both out (left My Day / off)

    component Pic: Image {
        id: pic
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        horizontalAlignment: Image.AlignHCenter
        verticalAlignment: Image.AlignVCenter
        asynchronous: true
        cache: false
        sourceSize.width: 1600          // plenty for a side-of-screen window; keeps memory low
        Behavior on opacity { NumberAnimation { duration: bg.fade } }
        onStatusChanged: bg._flipWhenReady(pic)
    }
    Pic { id: a; opacity: !bg._blank && bg._showA ? 1 : 0 }
    Pic { id: b; opacity: !bg._blank && !bg._showA ? 1 : 0 }
}
