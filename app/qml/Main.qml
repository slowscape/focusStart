import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore
import "components"
import "screens"
import "theme"

ApplicationWindow {
    id: appWindow
    width: 380
    height: 720
    minimumWidth: 320
    minimumHeight: 480
    visible: false            // Python restores geometry, then shows
    title: "StepTask"
    color: Theme.windowColor

    // ---------------------------------------------------------------- theme
    Binding { target: Theme; property: "accent"; value: appWindow.palette.accent }
    Binding { target: Theme; property: "windowColor"; value: appWindow.palette.window }
    Binding { target: Theme; property: "textColor"; value: appWindow.palette.windowText }
    Binding { target: Theme; property: "effects"; value: backend.effects }

    // ----------------------------------------------------------- navigation
    // Room for the four tabs: window width minus the row's margins (12), the gear (36) and the
    // Fluent TabBar's own padding (4 + 4). If the tabs add up to more, the bar scrolls a few px
    // depending on the selected tab, and the tabs shift when switching. From appWindow.width
    // (not the TabBar's width) to avoid a binding loop.
    readonly property real tabSpace: width - 12 - 36 - 8 - 4
    readonly property var tabs: ["myday", "upcoming", "lists", "history"]
    property string lastFocusTaskId: ""
    property string screen: "myday"
    property var screenParams: ({})
    property string lastTab: "myday"
    property var history: []
    // Asks open editors (task notes) to save now; the app writes to disk on quit right after.
    signal flushEdits()
    onClosing: flushEdits()
    readonly property bool tabScreen: tabs.indexOf(screen) >= 0 || screen === "settings"

    readonly property var screenFiles: ({
        myday: "screens/MyDay.qml", upcoming: "screens/Upcoming.qml", lists: "screens/Lists.qml",
        settings: "screens/Settings.qml", focus: "screens/FocusView.qml", plan: "screens/PlanSteps.qml",
        history: "screens/History.qml", editor: "screens/TaskEditor.qml"
    })

    function go(name, params) {
        if (screen !== name || JSON.stringify(params || {}) !== JSON.stringify(screenParams)) {
            if (!tabScreen) history.push({ screen: screen, params: screenParams })
            if (tabs.indexOf(name) >= 0 || name === "settings") history = []
            if (tabs.indexOf(name) >= 0) lastTab = name
            screenParams = params || {}
            screen = name
            loader.load()
        }
    }
    function back() {
        if (tabScreen) { go(lastTab); return }
        var prev = history.pop()
        // Skip entries whose task no longer exists
        while (prev && prev.params.taskId && !backend.taskInfo(prev.params.taskId).exists) prev = history.pop()
        if (prev) { screenParams = prev.params; screen = prev.screen }
        else { screenParams = {}; screen = lastTab }
        loader.load()
    }
    // noTimer: opened by clicking a task's title (look/work without starting the Pomodoro).
    function openFocus(taskId, replacePlan, noTimer) {
        lastFocusTaskId = taskId
        if (!noTimer) backend.pomoAutoStart(taskId)   // the Start arrow starts (or resumes after a break) the Pomodoro timer
        if (replacePlan && screen === "plan") { screenParams = { taskId: taskId }; screen = "focus"; loader.load(); return }
        go("focus", { taskId: taskId })
    }
    // A view's ids after dragging row `from` to `to` (for backend.reorderTasks / reorderLists).
    function reorderedIds(model, from, to) {
        var ids = []
        for (var i = 0; i < model.count; i++) ids.push(model.get(i).id)
        var moved = ids.splice(from, 1)[0]
        ids.splice(to, 0, moved)
        return ids
    }
    function openPlan(taskId) { go("plan", { taskId: taskId }) }
    function openEditor(taskId) { go("editor", { taskId: taskId }) }

    // ---------------------------------------------------------- completion
    function completeStep(taskId, stepId, sourceItem, cardItem) {
        var at = sourceItem ? centerOf(sourceItem) : null
        var rect = cardItem ? rectOf(cardItem) : null
        var res = backend.completeStep(taskId, stepId)
        celebrate(res, at, rect)
        return res
    }
    function completeTask(taskId, sourceItem, cardItem) {
        var at = sourceItem ? centerOf(sourceItem) : null
        var rect = cardItem ? rectOf(cardItem) : null
        var res = backend.completeTask(taskId)
        celebrate(res, at, rect)
        return res
    }
    function centerOf(item) { return item.mapToItem(fxLoader, item.width / 2, item.height / 2) }
    function rectOf(item) { var p = item.mapToItem(fxLoader, 0, 0); return { x: p.x, y: p.y, w: item.width, h: item.height } }

    function celebrate(res, at, rect) {
        if (!res || !res.ok) return
        var fx = Theme.particles ? fxLoader.item : null
        if (res.dayComplete) {
            if (fx) fx.dayConfetti()
            dayOverlay.show(res.tasksToday, res.stepsToday)
        } else if (res.taskDone) {
            if (fx) {
                var r = rect || { x: 0, y: appWindow.height * 0.35, w: fxLoader.width, h: 120 }
                fx.confetti(r.x, r.y, r.w, r.h, res.variant, res.firstTaskToday)
            }
        } else if (fx && at) {
            fx.pop(at.x, at.y, res.variant)
        }
        undoToast.show(res.message, res.token)
    }
    function undo(token) {
        var r = backend.undo(token)
        if (r.ok) toast("Undone", "")
    }
    function toast(msg, token) { undoToast.show(msg, token) }

    // -------------------------------------------------------- dialogs
    // Print: save My Day / the current list as a checklist PDF (opens in the PDF viewer).
    function exportPdf(kind) {
        pdfDialog.kind = kind
        pdfDialog.selectedFile = pdfDialog.currentFolder + "/" + backend.pdfFileName(kind)
        pdfDialog.open()
    }
    property var _dateCallback: null
    function pickDate(cb) { _dateCallback = cb; datePopup.open() }
    property string _deleteId: ""
    function confirmDelete(taskId) {
        _deleteId = taskId
        var info = backend.taskInfo(taskId)
        deleteDialog.taskTitle = info.title || ""
        deleteDialog.fromHistory = info.done === true
        deleteDialog.doneSteps = info.completedCount || 0
        deleteDialog.open()
    }

    Connections {
        target: backend
        function onDayCompleteRevoked() { dayOverlay.hide() }
        function onBreakOver(taskId) {
            breakOver.show(taskId)
            appWindow.raise()            // bring the window forward (Windows may only flash it)
            appWindow.alert(0)
        }
    }
    onActiveChanged: backend.windowActiveChanged(active)

    // -------------------------------------------------------- shortcuts
    Shortcut {
        sequence: "Ctrl+N"
        onActivated: {
            if (appWindow.screen === "myday" && loader.item) loader.item.focusAdd()
            else appWindow.go("myday", { focusQuickAdd: true })
        }
    }
    Shortcut {
        // Only enabled when it has something to do, so it never clashes with a
        // screen's own Esc (e.g. closing the Lists side panel).
        sequence: "Esc"
        enabled: !dayOverlay.open && !breakOver.open && (!appWindow.tabScreen || appWindow.screen === "settings")
        onActivated: appWindow.back()
    }

    // -------------------------------------------------------------- layout
    // Optional background picture (Settings > Background), on My Day only, in true colours.
    BackgroundPicture {
        anchors.fill: parent
        source: appWindow.screen === "myday" ? backend.bgImage : ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.s2
            Layout.rightMargin: Theme.s1
            Layout.topMargin: Theme.s1
            visible: appWindow.tabScreen
            spacing: 0
            TabBar {
                id: tabBar
                Layout.fillWidth: true
                background: Item {}
                currentIndex: appWindow.tabs.indexOf(appWindow.screen)
                TabButton { focusPolicy: Qt.NoFocus; text: "My Day"; width: appWindow.tabSpace * 0.24; leftPadding: 2; rightPadding: 2; onClicked: appWindow.go("myday") }
                TabButton { focusPolicy: Qt.NoFocus; text: "Upcoming"; width: appWindow.tabSpace * 0.3; leftPadding: 2; rightPadding: 2; onClicked: appWindow.go("upcoming") }
                TabButton { focusPolicy: Qt.NoFocus; text: "Lists"; width: appWindow.tabSpace * 0.2; leftPadding: 2; rightPadding: 2; onClicked: appWindow.go("lists") }
                TabButton { focusPolicy: Qt.NoFocus; text: "History"; width: appWindow.tabSpace * 0.26; leftPadding: 2; rightPadding: 2; onClicked: appWindow.go("history") }
            }
            IconButton {
                icon_: "settings"; tip: "Settings"
                iconColor: appWindow.screen === "settings" ? Theme.accent : Theme.textColor
                onClicked: appWindow.screen === "settings" ? appWindow.back() : appWindow.go("settings")
            }
        }

        // Pomodoro still running while you're elsewhere: a slim strip back to the task.
        ItemDelegate {
            Layout.fillWidth: true
            visible: backend.pomoEnabled && backend.pomoRunning && appWindow.screen !== "focus"
            implicitHeight: 30
            onClicked: if (appWindow.lastFocusTaskId && backend.taskInfo(appWindow.lastFocusTaskId).exists)
                           appWindow.openFocus(appWindow.lastFocusTaskId)
            background: Rectangle {
                color: backend.pomoPhase === "work" ? Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
                                                    : Qt.rgba(Theme.success.r, Theme.success.g, Theme.success.b, 0.14)
            }
            contentItem: RowLayout {
                spacing: Theme.s2
                Icon { name: "timer"; size: 12; color: Theme.subtext; Layout.leftMargin: Theme.s2 }
                Label {
                    Layout.fillWidth: true
                    font.pixelSize: Theme.fontSmall
                    text: backend.pomoWaiting ? "Break done · ready when you are"
                          : (backend.pomoPhase === "work" ? "Focus" : backend.pomoPhase === "short" ? "Short break" : "Long break")
                            + "  " + Math.floor(backend.pomoRemaining / 60) + ":" + ("0" + backend.pomoRemaining % 60).slice(-2)
                            + (backend.pomoPaused ? "  (paused)" : "")
                }
                Label { text: "Back to task ›"; font.pixelSize: Theme.fontSmall; color: Theme.accent; Layout.rightMargin: Theme.s2 }
            }
        }

        // Calm one-line notice (welcome, restored from backup, ...)
        Rectangle {
            Layout.fillWidth: true
            Layout.margins: Theme.s2
            visible: backend.notice !== ""
            implicitHeight: noticeRow.implicitHeight + Theme.s2 * 2
            radius: Theme.radius
            color: Qt.rgba(Theme.accent.r, Theme.accent.g, Theme.accent.b, 0.12)
            RowLayout {
                id: noticeRow
                anchors.fill: parent
                anchors.leftMargin: Theme.s3
                anchors.rightMargin: Theme.s1
                Label { Layout.fillWidth: true; text: backend.notice; wrapMode: Text.Wrap; font.pixelSize: Theme.fontSmall }
                IconButton { icon_: "close"; tip: "Dismiss"; iconSize: 10; onClicked: backend.dismissNotice() }
            }
        }

        Item {
            id: stage
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            Loader {
                id: loader
                width: stage.width
                height: stage.height
                // setSource passes per-screen params as initial properties.
                function load() {
                    setSource(Qt.resolvedUrl(appWindow.screenFiles[appWindow.screen]), appWindow.screenParams)
                }
                // Slide only. Never animate the whole page's opacity: it dims the entire
                // window for a moment, which reads as a flash. Screens with a bottom add bar
                // expose `enterOffset` (applied to their header and list only), so the bar
                // stays still; other screens slide as a whole.
                onLoaded: {
                    var hasOwn = item && item.enterOffset !== undefined
                    enter.target = hasOwn ? item : loader
                    enter.property = hasOwn ? "enterOffset" : "y"
                    loader.y = 0
                    enter.restart()
                }
                NumberAnimation {
                    id: enter
                    target: loader; property: "y"
                    from: Theme.motion ? 8 : 0; to: 0
                    duration: Theme.durMed; easing.type: Easing.OutCubic
                }
            }
            Component.onCompleted: loader.load()
        }

    }

    // ------------------------------------------------------------ overlays
    Loader {
        id: fxLoader
        anchors.fill: parent
        z: 50
        enabled: false
        // Particles need a GPU renderer; Qt's software renderer (some VMs / Remote Desktop)
        // can't draw them, so use the simple fallback there or if the module is missing.
        property bool particlesFailed: false
        readonly property bool software: GraphicsInfo.api === GraphicsInfo.Software
        source: (software || particlesFailed) ? "components/FallbackEffects.qml" : "components/ParticleEffects.qml"
        onStatusChanged: if (status === Loader.Error && !particlesFailed) particlesFailed = true
    }

    UndoToast {
        id: undoToast
        z: 60
        anchors.horizontalCenter: parent.horizontalCenter
        baseY: appWindow.height - height - ((loader.item && loader.item.bottomInset) ? loader.item.bottomInset + 20 : 24)
        onUndoRequested: (token) => appWindow.undo(token)
    }

    BreakOverOverlay {
        id: breakOver
        anchors.fill: parent
        z: 80
        onContinueTask: (taskId) => {
            if (taskId) appWindow.openFocus(taskId)    // Start resumes the waiting session
            else backend.pomoTogglePause()
        }
        onEndTask: { backend.pomoStop(); appWindow.go("myday") }
    }

    DayCompleteOverlay {
        id: dayOverlay
        anchors.fill: parent
        z: 70
        onPlanTomorrow: appWindow.go("upcoming", { focusQuickAdd: true })
    }

    FileDialog {
        id: pdfDialog
        property string kind: "myday"
        title: "Save checklist as PDF"
        fileMode: FileDialog.SaveFile
        defaultSuffix: "pdf"
        nameFilters: ["PDF (*.pdf)"]
        currentFolder: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0]
        onAccepted: if (backend.exportPdf(kind, selectedFile.toString())) appWindow.toast("PDF saved", "")
    }

    DatePopup {
        id: datePopup
        onPicked: (iso) => { if (appWindow._dateCallback) appWindow._dateCallback(iso); appWindow._dateCallback = null }
    }

    Dialog {
        id: deleteDialog
        property string taskTitle: ""
        property bool fromHistory: false     // a finished task: removes it from History for good
        property int doneSteps: 0
        anchors.centerIn: Overlay.overlay
        width: Math.min(320, appWindow.width - 32)
        modal: true
        title: fromHistory ? "Delete from history?" : "Delete this task?"
        standardButtons: Dialog.Ok | Dialog.Cancel
        Label {
            width: parent.width
            wrapMode: Text.Wrap
            text: deleteDialog.fromHistory
                  ? "“" + deleteDialog.taskTitle + "”" + (deleteDialog.doneSteps > 0
                        ? " and its " + Theme.plural(deleteDialog.doneSteps, "completed step") : "")
                    + " will be removed from History. This can't be undone."
                  : "“" + deleteDialog.taskTitle + "” and its steps will be removed."
        }
        onAccepted: {
            var id = appWindow._deleteId
            if (appWindow.screen === "editor" || appWindow.screen === "focus" || appWindow.screen === "plan") appWindow.back()
            if (fromHistory) backend.deleteFromHistory(id)
            else backend.deleteTask(id)
        }
    }
}
