"""The QObject exposed to QML. Thin bridge: every mutation goes through Service."""
from __future__ import annotations

import logging
import random
import time
from datetime import date, datetime, timedelta
from pathlib import Path

from PySide6.QtCore import Property, QObject, QTimer, QUrl, Signal, Slot
from PySide6.QtGui import QDesktopServices

from ..core import dates, history, phrases, printout
from ..core.pomodoro import LIMITS as POMO_LIMITS, Pomodoro, clamp as pomo_clamp
from ..core.models import TAG_COLORS, Task
from ..core.service import Service
from ..core.store import Store
from .models import HistoryModel, KeyedListModel
from .pdf import write_pdf
from .sound import SoundBank, step_sound, task_sound

log = logging.getLogger(__name__)

TASK_ROLES = ["title", "notes", "plannedDate", "dateLabel", "listId", "listName",
              "stepTotal", "stepDone", "stepRemaining", "section", "inMyDay", "completedOpen",
              "tagColors", "tagNames", "repeat"]
TAG_ROLES = ["name", "color"]
IMAGE_EXT = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".gif"}
REPEAT_LABELS = {"daily": "Every day", "weekdays": "Every weekday", "weekly": "Every week",
                 "monthly": "Every month"}
STEP_ROLES = ["text"]
LIST_ROLES = ["name", "count"]


def _variant(task_id: str) -> int:
    try:
        return int(task_id.replace("-", "")[:8], 16) % 4
    except ValueError:
        return 0


class Backend(QObject):
    revisionChanged = Signal()
    progressChanged = Signal()
    settingsChanged = Signal()
    noticeChanged = Signal()
    currentListChanged = Signal()
    dayCompleteRevoked = Signal()
    dateRolledOver = Signal()
    pomodoroChanged = Signal()
    historyChanged = Signal()
    backgroundChanged = Signal()

    def __init__(self, service: Service, store: Store, sounds: SoundBank,
                 notice: str | None = None, first_run: bool = False, parent=None):
        super().__init__(parent)
        self.svc = service
        self.store = store
        self.sounds = sounds
        self._notice = notice or ""
        self._first_run = first_run
        self._revision = 0
        self._progress = None
        self._step_models: dict[str, KeyedListModel] = {}
        self._done_models: dict[str, KeyedListModel] = {}
        self._history = HistoryModel(self)
        self._history_dirty = True
        self._history_totals = (0, 0)
        pomo = self.svc.data.settings.pomodoro
        self._pomo = Pomodoro(pomo["work"], pomo["short"], pomo["long"], pomo["long_every"])
        self._pomo_timer = QTimer(self)
        self._pomo_timer.setInterval(500)
        self._pomo_timer.timeout.connect(self._pomo_tick)
        self._pomo_task: str | None = None    # the task whose Start began the timer
        self._focus_task: str = ""            # task open in Focus (for the bar's play/power)
        self._bg_image = ""
        self._last_encouragement: str | None = None
        self._today = self.svc.today()
        self._window_active = False

        self._my_day = KeyedListModel(TASK_ROLES, self)
        self._upcoming = KeyedListModel(TASK_ROLES, self)
        self._list_tasks = KeyedListModel(TASK_ROLES, self)
        self._lists = KeyedListModel(LIST_ROLES, self)
        self._tags = KeyedListModel(TAG_ROLES, self)
        self._current_list = self.svc.default_list_id()

        self._save_timer = QTimer(self)
        self._save_timer.setSingleShot(True)
        self._save_timer.setInterval(300)
        self._save_timer.timeout.connect(self.flush)

        self._tick = QTimer(self)
        self._tick.setInterval(60_000)
        self._tick.timeout.connect(self.tick)
        self._tick.start()

        self._bg_image = self._compute_bg()
        if first_run:
            self._notice = "Welcome. Add your first task below, then break it into small steps."
            self._schedule_save()
        self._refresh()

    # ================================================================ plumbing
    def _schedule_save(self):
        self._save_timer.start()

    @Slot()
    def flush(self):
        self._save_timer.stop()
        try:
            self.store.save(self.svc.data)
        except Exception:  # noqa: BLE001
            log.exception("save failed")
            self._set_notice("Couldn't save just now. Your changes are kept in memory; "
                             "see app.log in the data folder.")

    def _set_notice(self, text: str):
        if text != self._notice:
            self._notice = text
            self.noticeChanged.emit()

    def _task_item(self, t: Task, section: str = "") -> dict:
        lst = self.svc.list_by_id(t.list_id)
        done = sum(1 for s in t.steps if s.done)
        rem = len(t.remaining_steps)
        today = self.svc.today()
        tags = [g for g in (self.svc.tag_by_id(i) for i in t.tag_ids) if g is not None]
        return {
            "id": t.id, "title": t.title, "notes": t.notes,
            "plannedDate": t.planned_date or "",
            "dateLabel": self._date_label(t.planned_date, today),
            "listId": t.list_id, "listName": lst.name if lst else "",
            "stepTotal": done + rem, "stepDone": done, "stepRemaining": rem,
            "section": section,
            "inMyDay": bool(t.planned_date and date.fromisoformat(t.planned_date) <= today),
            "completedOpen": t.completed_open,
            "tagColors": [g.color for g in tags], "tagNames": [g.name for g in tags],
            "repeat": t.repeat,
        }

    @staticmethod
    def _date_label(iso: str | None, today: date) -> str:
        if not iso:
            return ""
        d = date.fromisoformat(iso)
        if d <= today:
            return "Today"
        if d == today + timedelta(days=1):
            return "Tomorrow"
        if d - today < timedelta(days=7):
            return d.strftime("%A")
        return f"{d.strftime('%a')}, {d.strftime('%b')} {d.day}"

    def _upcoming_section(self, iso: str, today: date) -> str:
        d = date.fromisoformat(iso)
        if d == today + timedelta(days=1):
            return "Tomorrow"
        if d <= dates.week_end(today, self.svc.data.settings.week_starts):
            return d.strftime("%A")
        return "Later"

    def _refresh(self):
        today = self.svc.today()
        self._my_day.sync([self._task_item(t) for t in self.svc.my_day()])
        # Upcoming, then every open task with no date at the bottom (easy to send to My Day).
        undated = sorted((t for t in self.svc.data.tasks if not t.done and not t.planned_date),
                         key=lambda t: (t.order, t.created_at))
        self._upcoming.sync([self._task_item(t, self._upcoming_section(t.planned_date, today))
                             for t in self.svc.upcoming()]
                            + [self._task_item(t, "No date") for t in undated])
        if self.svc.list_by_id(self._current_list) is None:
            self._current_list = self.svc.default_list_id()
            self.currentListChanged.emit()
        self._list_tasks.sync([self._task_item(t) for t in self.svc.list_tasks(self._current_list)])
        self._lists.sync([{"id": l.id, "name": l.name, "count": self.svc.incomplete_count(l.id)}
                          for l in self.svc.lists()])
        self._tags.sync([{"id": g.id, "name": g.name, "color": g.color} for g in self.svc.tags()])
        for task_id, model in self._step_models.items():
            t = self.svc.task(task_id)
            model.sync([{"id": s.id, "text": s.text} for s in (t.remaining_steps if t else [])])
        for task_id, model in self._done_models.items():
            t = self.svc.task(task_id)
            model.sync([{"id": s.id, "text": s.text} for s in (t.done_steps if t else [])])
        self._history_dirty = True
        self._progress = self.svc.progress()
        self._revision += 1
        self.revisionChanged.emit()
        self.progressChanged.emit()

    def _mutated(self):
        self._refresh()
        self._schedule_save()

    def _sound(self, name: str):
        s = self.svc.data.settings
        if s.sound and s.effects != "off":
            self.sounds.play(name, s.volume)

    # ================================================================ properties
    def _get_revision(self):
        return self._revision
    revision = Property(int, _get_revision, notify=revisionChanged)

    myDayModel = Property(QObject, lambda self: self._my_day, constant=True)
    upcomingModel = Property(QObject, lambda self: self._upcoming, constant=True)
    listTasksModel = Property(QObject, lambda self: self._list_tasks, constant=True)
    listsModel = Property(QObject, lambda self: self._lists, constant=True)
    tagsModel = Property(QObject, lambda self: self._tags, constant=True)

    def _get_today_label(self):
        d = self.svc.today()
        return f"{d.strftime('%A')}, {d.strftime('%B')} {d.day}"
    todayLabel = Property(str, _get_today_label, notify=revisionChanged)

    def _get_today_iso(self):
        return self.svc.today().isoformat()
    todayIso = Property(str, _get_today_iso, notify=revisionChanged)

    stepsDoneToday = Property(int, lambda self: self._progress.steps_done, notify=progressChanged)
    tasksDoneToday = Property(int, lambda self: self._progress.tasks_done, notify=progressChanged)

    def _get_notice(self):
        return self._notice
    notice = Property(str, _get_notice, notify=noticeChanged)

    @Slot()
    def dismissNotice(self):
        self._set_notice("")

    # settings
    def _s(self):
        return self.svc.data.settings

    def _set_sound(self, v):
        self.svc.set_setting("sound", bool(v)); self.settingsChanged.emit(); self._schedule_save()
    sound = Property(bool, lambda self: self._s().sound, _set_sound, notify=settingsChanged)

    def _set_volume(self, v):
        self.svc.set_setting("volume", max(0.0, min(1.0, float(v))))
        self.settingsChanged.emit(); self._schedule_save()
    volume = Property(float, lambda self: self._s().volume, _set_volume, notify=settingsChanged)

    def _set_effects(self, v):
        if v in ("full", "calm", "off"):
            self.svc.set_setting("effects", v); self.settingsChanged.emit(); self._schedule_save()
    effects = Property(str, lambda self: self._s().effects, _set_effects, notify=settingsChanged)

    def _set_week_starts(self, v):
        if v in ("monday", "sunday"):
            self.svc.set_setting("week_starts", v); self.settingsChanged.emit(); self._mutated()
    weekStarts = Property(str, lambda self: self._s().week_starts, _set_week_starts,
                          notify=settingsChanged)

    dataDir = Property(str, lambda self: str(self.store.dir), constant=True)

    @Slot()
    def openDataFolder(self):
        QDesktopServices.openUrl(QUrl.fromLocalFile(str(self.store.dir)))

    @Slot(str)
    def playSound(self, name: str):
        self._sound(name)

    @Slot()
    def previewVolume(self):
        s = self._s()
        if s.sound:
            self.sounds.play("pop_0_4", s.volume)

    # ================================================================ lists screen
    def _get_current_list(self):
        return self._current_list

    def _set_current_list(self, list_id):
        if list_id != self._current_list and self.svc.list_by_id(list_id):
            self._current_list = list_id
            self.currentListChanged.emit()
            self._refresh()
    currentListId = Property(str, _get_current_list, _set_current_list, notify=currentListChanged)

    def _get_current_list_name(self):
        l = self.svc.list_by_id(self._current_list)
        return l.name if l else ""
    currentListName = Property(str, _get_current_list_name, notify=revisionChanged)

    @Slot(str, result=str)
    def addList(self, name: str) -> str:
        try:
            l = self.svc.add_list(name)
        except ValueError:
            return ""
        self._current_list = l.id
        self.currentListChanged.emit()
        self._mutated()
        return l.id

    @Slot(str, str)
    def renameList(self, list_id: str, name: str):
        self.svc.rename_list(list_id, name)
        self._mutated()

    @Slot(str, result=int)
    def listTaskCountAll(self, list_id: str) -> int:
        return sum(1 for t in self.svc.data.tasks if t.list_id == list_id)

    @Slot(str, str, result=bool)
    def deleteList(self, list_id: str, move_to: str) -> bool:
        try:
            self.svc.delete_list(list_id, move_to or None)
        except ValueError as e:
            log.info("delete list refused: %s", e)
            return False
        self._mutated()
        return True

    # ================================================================ tasks
    def _parse_when(self, when: str):
        today = self.svc.today()
        if when == "today":
            return today
        if when == "tomorrow":
            return today + timedelta(days=1)
        if when in ("", "none"):
            return None
        return date.fromisoformat(when)

    @Slot(str, str, str, str, "QVariantList", "QVariantList", result=str)
    def addTask(self, title: str, when: str, list_id: str, new_list_name: str,
                tag_ids=None, new_tag_names=None) -> str:
        """new_list_name (from the quick-add /command) wins: existing list in any case,
        or a new list named exactly as typed. Tags: existing ids plus //names to create."""
        if not title.strip():
            return ""
        if new_list_name.strip():
            list_id = self.svc.ensure_list(new_list_name).id
        tags = [str(i) for i in (tag_ids or [])]
        tags += [self.svc.ensure_tag(str(n)).id for n in (new_tag_names or []) if str(n).strip()]
        try:
            t = self.svc.add_task(title, self._parse_when(when), list_id or None, tags)
        except ValueError:
            return ""
        lists = [l.id for l in self.svc.lists()]
        log.info("task added: list #%s, date %s, %d tag(s)",
                 lists.index(t.list_id) if t.list_id in lists else "?", t.planned_date or "none", len(tags))
        self._mutated()
        return t.id

    @Slot(str, result="QVariantList")
    def listMatches(self, query: str):
        return [{"id": l.id, "name": l.name} for l in self.svc.match_lists(query)]

    @Slot(str, result="QVariantMap")
    def findList(self, name: str):
        l = self.svc.find_list(name)
        return {"id": l.id, "name": l.name} if l else {}

    @Slot(str, result="QVariantMap")
    def taskInfo(self, task_id: str):
        t = self.svc.task(task_id)
        if t is None:
            return {"exists": False}
        item = self._task_item(t)
        rem = t.remaining_steps
        item.update({
            "exists": True, "done": t.done,
            "steps": [{"id": s.id, "text": s.text, "done": s.done, "notes": s.notes}
                      for s in t.steps_in_order],
            "doneSteps": [{"id": s.id, "text": s.text, "notes": s.notes} for s in t.done_steps],
            "tagIds": t.tag_ids,
            "tags": [{"id": g.id, "name": g.name, "color": g.color}
                     for g in (self.svc.tag_by_id(i) for i in t.tag_ids) if g is not None],
            "repeatLabel": REPEAT_LABELS.get(t.repeat, ""),
            "currentStepId": rem[0].id if rem else "",
            "currentStep": rem[0].text if rem else "",
            "completedCount": len(t.done_steps),
            "completedLabel": self._completed_label(t.completed_at),
            "pomodoro": t.pomodoro_on,
            "dateChoice": self._date_choice(t.planned_date),
        })
        return item

    def _completed_label(self, ts: str | None) -> str:
        if not ts:
            return ""
        when = datetime.fromisoformat(ts)
        return f"{history.day_label(when.date(), self.svc.today())}, {history.time_label(when)}"

    def _date_choice(self, iso):
        if not iso:
            return "none"
        d = date.fromisoformat(iso)
        today = self.svc.today()
        if d <= today:
            return "today"
        if d == today + timedelta(days=1):
            return "tomorrow"
        return "date"

    @Slot(str, str)
    def setTitle(self, task_id: str, title: str):
        if self.svc.task(task_id):
            self.svc.update_task(task_id, title=title)
            self._mutated()

    @Slot(str, str)
    def setNotes(self, task_id: str, notes: str):
        t = self.svc.task(task_id)
        if t and t.notes != notes:
            self.svc.update_task(task_id, notes=notes)
            self._mutated()

    @Slot(str, str)
    def setDate(self, task_id: str, when: str):
        if self.svc.task(task_id):
            self.svc.update_task(task_id, planned_date=self._parse_when(when))
            self._mutated()

    @Slot(str, bool)
    def setTaskPomodoro(self, task_id: str, on: bool):
        if self.svc.task(task_id):
            self.svc.set_task_pomodoro(task_id, on)
            self._mutated()

    @Slot(str, str)
    def setList(self, task_id: str, list_id: str):
        if self.svc.task(task_id):
            self.svc.update_task(task_id, list_id=list_id)
            self._mutated()

    @Slot(str)
    def deleteTask(self, task_id: str):
        try:
            self.svc.delete_task(task_id)
        except (KeyError, ValueError):
            return
        self._forget_task_models(task_id)
        self._mutated()

    @Slot(str)
    def deleteFromHistory(self, task_id: str):
        """Remove a finished task and its steps for good (History, Done badges)."""
        try:
            self.svc.delete_task(task_id, include_completed=True)
        except KeyError:
            return
        self._forget_task_models(task_id)
        self._mutated()

    def _forget_task_models(self, task_id: str):
        self._step_models.pop(task_id, None)
        self._done_models.pop(task_id, None)

    @Slot(str, result=str)
    def nextTaskAfter(self, task_id: str) -> str:
        t = self.svc.next_task_after(task_id)
        return t.id if t else ""

    @Slot(result=int)
    def myDayCount(self) -> int:
        return len(self.svc.my_day())

    # ================================================================ steps
    # ================================================================ order (drag and drop)
    @Slot("QVariantList")
    def reorderTasks(self, ids):
        """The tasks shown in a view, in their new order (My Day, a list, an Upcoming day)."""
        self.svc.reorder_tasks([str(i) for i in ids])
        self._mutated()

    @Slot("QVariantList")
    def reorderLists(self, ids):
        self.svc.reorder_lists([str(i) for i in ids])
        self._mutated()

    # ================================================================ repeat, tags
    @Slot(str, str)
    def setRepeat(self, task_id: str, rule: str):
        if self.svc.task(task_id):
            self.svc.set_repeat(task_id, rule)
            self._mutated()

    @Slot(str, "QVariantList")
    def setTaskTags(self, task_id: str, ids):
        if self.svc.task(task_id):
            self.svc.set_task_tags(task_id, [str(i) for i in ids])
            self._mutated()

    tagPalette = Property("QVariantList", lambda self: list(TAG_COLORS), constant=True)

    @Slot(str, result="QVariantList")
    def tagMatches(self, query: str):
        return [{"id": g.id, "name": g.name, "color": g.color} for g in self.svc.match_tags(query)]

    @Slot(str, result="QVariantMap")
    def findTag(self, name: str):
        g = self.svc.find_tag(name)
        return {"id": g.id, "name": g.name, "color": g.color} if g else {}

    @Slot(str, result=str)
    def addTag(self, name: str) -> str:
        try:
            g = self.svc.add_tag(name)
        except ValueError:
            return ""
        self._mutated()
        return g.id

    @Slot(str, str, str)
    def updateTag(self, tag_id: str, name: str, color: str):
        self.svc.update_tag(tag_id, name or None, color or None)
        self._mutated()

    @Slot(str)
    def deleteTag(self, tag_id: str):
        self.svc.delete_tag(tag_id)
        self._mutated()

    # ================================================================ steps
    @Slot(str, str, str)
    def setStepNotes(self, task_id: str, step_id: str, notes: str):
        t = self.svc.task(task_id)
        s = t.step(step_id) if t else None
        if s is not None and s.notes != notes:
            self.svc.set_step_notes(task_id, step_id, notes)
            self._mutated()

    @Slot(str, result=QObject)
    def stepModel(self, task_id: str):
        m = self._step_models.get(task_id)
        if m is None:
            m = KeyedListModel(STEP_ROLES, self)  # parented: QML must not garbage-collect it
            t = self.svc.task(task_id)
            m.sync([{"id": s.id, "text": s.text} for s in (t.remaining_steps if t else [])])
            self._step_models[task_id] = m
        return m

    @Slot(str, str, result=str)
    def addStep(self, task_id: str, text: str) -> str:
        try:
            s = self.svc.add_step(task_id, text)
        except (KeyError, ValueError):
            return ""
        self._mutated()
        return s.id

    @Slot(str, str, str)
    def editStep(self, task_id: str, step_id: str, text: str):
        self.svc.edit_step(task_id, step_id, text)
        self._mutated()

    @Slot(str, str)
    def deleteStep(self, task_id: str, step_id: str):
        self.svc.delete_step(task_id, step_id)
        self._mutated()

    @Slot(str, str, int)
    def moveStep(self, task_id: str, step_id: str, new_index: int):
        self.svc.move_step(task_id, step_id, new_index)
        self._mutated()

    @Slot(str, result=QObject)
    def doneStepModel(self, task_id: str):
        m = self._done_models.get(task_id)
        if m is None:
            m = KeyedListModel(STEP_ROLES, self)
            t = self.svc.task(task_id)
            m.sync([{"id": s.id, "text": s.text} for s in (t.done_steps if t else [])])
            self._done_models[task_id] = m
        return m

    @Slot(str, bool)
    def setCompletedOpen(self, task_id: str, is_open: bool):
        if self.svc.task(task_id):
            self.svc.set_completed_open(task_id, is_open)
            self._mutated()

    @Slot(str, result="QVariantList")
    def completedSteps(self, task_id: str):
        t = self.svc.task(task_id)
        return [{"id": s.id, "text": s.text} for s in (t.done_steps if t else [])]

    @Slot(str, str)
    def restoreStep(self, task_id: str, step_id: str):
        self.svc.restore_step(task_id, step_id)
        self._mutated()

    # ================================================================ completion
    def _completion_result(self, c) -> dict:
        s = self._s()
        variant = _variant(c.task_id)
        if c.day_complete:
            effect = "day"
            self._sound("day_complete")
        elif c.task_completed:
            effect = "taskBig" if c.first_task_today else "task"
            self._sound(task_sound(c.tasks_today, c.first_task_today))
        else:
            effect = "step"
            self._sound(step_sound(variant, c.step_index))
        pool = phrases.TASK_DONE if c.task_completed else phrases.ENCOURAGEMENTS
        msg = phrases.pick_different(pool, self._last_encouragement)
        self._last_encouragement = msg
        if c.all_clear_again:
            msg = "All clear again."
        if c.repeat_date:
            msg += " Next one: " + self._date_label(c.repeat_date, self.svc.today()) + "."
        if c.task_completed and c.task_id == self._pomo_task and self._pomo.running:
            self._pomo.stop()          # the task that started the timer is done: timer off
            self._pomo_task = None
            self._pomo_emit()
        return {"ok": True, "token": c.token, "effect": effect, "variant": variant,
                "taskDone": c.task_completed, "dayComplete": c.day_complete,
                "allClearAgain": c.all_clear_again, "firstTaskToday": c.first_task_today,
                "message": msg, "tasksToday": c.tasks_today, "stepsToday": c.steps_today,
                "taskId": c.task_id}

    @Slot(str, str, result="QVariantMap")
    def completeStep(self, task_id: str, step_id: str):
        try:
            c = self.svc.complete_step(task_id, step_id)
        except (KeyError, ValueError):
            return {"ok": False}
        res = self._completion_result(c)
        self._mutated()
        return res

    @Slot(str, result="QVariantMap")
    def completeTask(self, task_id: str):
        try:
            c = self.svc.complete_task(task_id)
        except (KeyError, ValueError):
            return {"ok": False}
        res = self._completion_result(c)
        self._mutated()
        return res

    @Slot(str, result="QVariantMap")
    def undo(self, token: str):
        r = self.svc.undo(token)
        if r.ok:
            self._mutated()
            if r.day_complete_revoked:
                self.dayCompleteRevoked.emit()
        return {"ok": r.ok, "dayCompleteRevoked": r.day_complete_revoked}

    # ================================================================ plan page
    @Slot(result=str)
    def planTimerDoneText(self):
        return random.choice(phrases.PLAN_TIMER_DONE)

    # ================================================================ dates
    @Slot(result="QVariantList")
    def upcomingDays(self):
        today = self.svc.today()
        out = []
        for i in range(1, 8):
            d = today + timedelta(days=i)
            out.append({"value": d.isoformat(), "label": self._date_label(d.isoformat(), today)})
        return out

    @Slot(str, result=str)
    def dateLabel(self, iso: str) -> str:
        return self._date_label(iso or None, self.svc.today())

    # ================================================================ print / PDF
    def _print_source(self, kind: str):
        if kind == "list":
            l = self.svc.list_by_id(self._current_list)
            name = l.name if l else "List"
            return name, self._get_today_label(), self.svc.list_tasks(self._current_list)
        return "My Day", self._get_today_label(), self.svc.my_day()

    @Slot(str, result=str)
    def pdfFileName(self, kind: str) -> str:
        heading, _sub, _tasks = self._print_source(kind)
        return printout.filename(heading, self.svc.today().isoformat())

    @Slot(str, str, result=bool)
    def exportPdf(self, kind: str, file_url: str) -> bool:
        """Write My Day ("myday") or the current list ("list") as a checklist PDF, then open it
        in the default PDF viewer so it can be printed."""
        path = QUrl(file_url).toLocalFile() if "://" in file_url else file_url
        if not path:
            return False
        if not path.lower().endswith(".pdf"):
            path += ".pdf"
        heading, sub, tasks = self._print_source(kind)
        try:
            write_pdf(path, heading, sub, printout.from_tasks(tasks))
        except Exception:  # noqa: BLE001
            log.exception("PDF export failed")
            self._set_notice("Couldn't save the PDF there. Try another folder.")
            return False
        QDesktopServices.openUrl(QUrl.fromLocalFile(path))
        return True

    # ================================================================ history
    historyModel = Property(QObject, lambda self: self._history, constant=True)
    historySteps = Property(int, lambda self: self._history_totals[0], notify=historyChanged)
    historyTasks = Property(int, lambda self: self._history_totals[1], notify=historyChanged)

    def _get_history_stats(self):
        return [{"label": x.label, "tasks": x.tasks, "steps": x.steps}
                for x in history.totals(self.svc.data, self.svc.today(), self._s().week_starts)]
    historyStats = Property("QVariantList", _get_history_stats, notify=historyChanged)

    @Slot()
    def reloadHistory(self):
        """Rebuild the history index (cheap) and show its first page."""
        if not self._history_dirty and self._history.rowCount() > 0:
            return
        today = self.svc.today()
        rows = []
        steps = tasks = 0
        for e in history.events(self.svc.data):
            when = e.when
            if e.kind == "step":
                steps += 1
                sub = e.task_title
            else:
                tasks += 1
                sub = "Task done" + (f" \u00B7 {e.list_name}" if e.list_name else "")
            rows.append({"kind": e.kind, "text": e.text, "sub": sub, "taskId": e.task_id,
                         "timeLabel": history.time_label(when),
                         "section": history.day_label(when.date(), today)})
        self._history_totals = (steps, tasks)
        self._history.reset(rows)
        self._history_dirty = False
        self.historyChanged.emit()

    # ================================================================ pomodoro
    def _pomo_settings(self):
        return self.svc.data.settings.pomodoro

    def _pomo_now(self):
        return time.monotonic()

    def _pomo_emit(self):
        if self._pomo.running and not self._pomo.paused:
            if not self._pomo_timer.isActive():
                self._pomo_timer.start()
        else:
            self._pomo_timer.stop()
        self.pomodoroChanged.emit()

    def _pomo_tick(self):
        if self._pomo.tick(self._pomo_now()):
            self._sound("chime")  # one gentle chime per change; nothing to dismiss
        self._pomo_emit()         # stops the ticker while the next session waits for Start

    pomoEnabled = Property(bool, lambda self: self._pomo_settings()["enabled"], notify=pomodoroChanged)
    pomoRunning = Property(bool, lambda self: self._pomo.running, notify=pomodoroChanged)
    pomoPaused = Property(bool, lambda self: self._pomo.paused, notify=pomodoroChanged)
    pomoWaiting = Property(bool, lambda self: self._pomo.waiting, notify=pomodoroChanged)
    pomoPhase = Property(str, lambda self: self._pomo.phase, notify=pomodoroChanged)
    pomoRemaining = Property(int, lambda self: int(self._pomo.remaining(self._pomo_now()) + 0.999),
                             notify=pomodoroChanged)
    pomoWorkDone = Property(int, lambda self: self._pomo.work_done, notify=pomodoroChanged)
    pomoLongEvery = Property(int, lambda self: self._pomo.long_every, notify=pomodoroChanged)
    pomoWork = Property(int, lambda self: self._pomo.work, notify=pomodoroChanged)
    pomoShort = Property(int, lambda self: self._pomo.short, notify=pomodoroChanged)
    pomoLong = Property(int, lambda self: self._pomo.long, notify=pomodoroChanged)
    # Max minutes per phase, for the SpinBoxes (same limits the settings loader applies).
    pomoMax = Property("QVariantMap", lambda self: {k: POMO_LIMITS[k][1] for k in ("work", "short", "long")},
                       constant=True)

    @Slot(str)
    def pomoAutoStart(self, task_id: str):
        """The Start arrow: starts the timer (or the focus session waiting after a break),
        unless the timer is off in Settings or for this task."""
        t = self.svc.task(task_id)
        if not self._pomo_settings()["enabled"] or (t is not None and not t.pomodoro_on):
            return
        now = self._pomo_now()
        if not self._pomo.running:
            self._pomo.start(now)
            self._pomo_task = task_id
        elif self._pomo.waiting:
            self._pomo.resume(now)
        else:
            return
        self._pomo_emit()

    @Slot(str)
    def setFocusTask(self, task_id: str):
        self._focus_task = task_id

    @Slot()
    def pomoTogglePause(self):
        now = self._pomo_now()
        if not self._pomo.running:
            self._pomo.start(now)
            self._pomo_task = self._focus_task or None
        elif self._pomo.paused:
            self._pomo.resume(now)
        else:
            self._pomo.pause(now)
        self._pomo_emit()

    @Slot(bool)
    def pomoPower(self, on: bool):
        """The bar's power button. Off stops and resets; on starts a fresh focus session."""
        self.pomoSetEnabled(on)
        if on:
            self._pomo.start(self._pomo_now())
            self._pomo_task = self._focus_task or None
            self._pomo_emit()

    @Slot(bool)
    def pomoSetEnabled(self, on: bool):
        """Settings switch: timer on/off everywhere (off = greyed out and reset).
        Turning it on here doesn't start it; a task's Start arrow or the bar's play does."""
        self._pomo_settings()["enabled"] = bool(on)
        if not on:
            self._pomo.stop()
        self._schedule_save()
        self._pomo_emit()

    @Slot(str, int)
    def pomoSetMinutes(self, phase: str, minutes: int):
        if phase not in ("work", "short", "long"):
            return
        minutes = pomo_clamp(phase, minutes)
        self._pomo_settings()[phase] = minutes
        if self._pomo.set_minutes(phase, minutes, self._pomo_now()):
            self._sound("chime")
        self._schedule_save()
        self._pomo_emit()

    # ================================================================ background images
    def _bg(self):
        return self.svc.data.settings.background

    def _bg_files(self) -> list:
        folder = self._bg()["folder"]
        if not folder:
            return []
        try:
            p = Path(folder)
            return sorted((f for f in p.iterdir() if f.suffix.lower() in IMAGE_EXT and f.is_file()),
                          key=lambda f: f.name.lower())
        except OSError:
            return []

    def _compute_bg(self) -> str:
        bg = self._bg()
        files = self._bg_files() if bg["enabled"] else []
        if not files:
            return ""
        minutes = bg["interval"]
        slot = self.svc.today().toordinal() if minutes >= 1440 else int(time.time() // 60 // minutes)
        return QUrl.fromLocalFile(str(files[slot % len(files)])).toString()

    def _bg_update(self):
        img = self._compute_bg()
        if img != self._bg_image:
            self._bg_image = img
        self.backgroundChanged.emit()

    bgImage = Property(str, lambda self: self._bg_image, notify=backgroundChanged)
    bgEnabled = Property(bool, lambda self: self._bg()["enabled"], notify=backgroundChanged)
    bgFolder = Property(str, lambda self: self._bg()["folder"], notify=backgroundChanged)
    bgInterval = Property(int, lambda self: self._bg()["interval"], notify=backgroundChanged)
    bgImageCount = Property(int, lambda self: len(self._bg_files()), notify=backgroundChanged)

    @Slot(bool)
    def setBgEnabled(self, on: bool):
        self._bg()["enabled"] = bool(on)
        self._schedule_save()
        self._bg_update()

    @Slot(str)
    def setBgFolder(self, folder_url: str):
        path = QUrl(folder_url).toLocalFile() if "://" in folder_url else folder_url
        self._bg()["folder"] = path
        self._bg()["enabled"] = bool(path)
        self._schedule_save()
        self._bg_update()

    @Slot(int)
    def setBgInterval(self, minutes: int):
        from ..core.models import BACKGROUND_INTERVALS
        if minutes in BACKGROUND_INTERVALS:
            self._bg()["interval"] = minutes
            self._schedule_save()
            self._bg_update()

    @Slot()
    def openBgFolder(self):
        if self._bg()["folder"]:
            QDesktopServices.openUrl(QUrl.fromLocalFile(self._bg()["folder"]))

    # ================================================================ day rollover
    @Slot(bool)
    def windowActiveChanged(self, active: bool):
        self._window_active = active
        if active:
            self.tick()

    @Slot()
    def tick(self):
        if self._bg()["enabled"]:
            img = self._compute_bg()
            if img != self._bg_image:
                self._bg_image = img
                self.backgroundChanged.emit()
        today = self.svc.today()
        if today != self._today:
            self._today = today
            self._refresh()  # rollover: My Day, Upcoming sections, progress floor reset
            self.dateRolledOver.emit()
