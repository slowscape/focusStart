"""All state mutations. No Qt imports.

The Qt layer calls these methods, then refreshes its models.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, timedelta
from typing import Any

from . import dates, progress
from .dates import Clock, local_date_of, parse_date, to_iso
from .models import TAG_COLORS, AppData, Step, Tag, Task, TaskList, new_id

_UNSET: Any = object()
UNDO_KEEP = 30


@dataclass
class Completion:
    token: str
    task_id: str
    step_id: str | None
    task_completed: bool          # this action completed the task
    step_index: int               # steps already done in this task before this one
    first_task_today: bool        # first task completed today (bigger flourish)
    day_complete: bool            # the once-per-day celebration fires now
    all_clear_again: bool         # day cleared again after it already fired today
    tasks_today: int = 0
    steps_today: int = 0
    repeat_date: str | None = None  # a repeating task's next copy was planned for this date


@dataclass
class _Undo:
    kind: str                     # "step" | "task"
    task_id: str
    step_id: str | None
    done_at: str                  # timestamp written by the action
    completed_task: bool
    added_day: str | None
    prev_floor: float
    prev_floor_date: str | None
    spawned_id: str | None = None # next copy of a repeating task, removed again on undo


@dataclass
class UndoResult:
    ok: bool
    day_complete_revoked: bool = False
    task_reopened: bool = False


class Service:
    def __init__(self, data: AppData, clock: Clock = dates.system_now):
        self.data = data
        self.clock = clock
        self._undo: dict[str, _Undo] = {}
        self._undo_order: list[str] = []
        self.version = 0

    # ---------- basics ----------
    def today(self) -> date:
        return self.clock().date()

    def now_iso(self) -> str:
        return to_iso(self.clock())

    def _changed(self) -> None:
        self.version += 1

    def task(self, task_id: str) -> Task | None:
        return next((t for t in self.data.tasks if t.id == task_id), None)

    def _task(self, task_id: str) -> Task:
        t = self.task(task_id)
        if t is None:
            raise KeyError(task_id)
        return t

    def list_by_id(self, list_id: str) -> TaskList | None:
        return next((l for l in self.data.lists if l.id == list_id), None)

    def default_list_id(self) -> str:
        return sorted(self.data.lists, key=lambda l: l.order)[0].id

    @staticmethod
    def _date_str(d: date | str | None) -> str | None:
        if d is None or d == "":
            return None
        if isinstance(d, date):
            return d.isoformat()
        return date.fromisoformat(d).isoformat()

    # ---------- queries ----------
    def _sorted(self, tasks):
        return sorted(tasks, key=lambda t: (t.order, t.created_at))

    def my_day(self) -> list[Task]:
        today = self.today()
        return self._sorted(t for t in self.data.tasks if progress.in_my_day(t, today))

    def upcoming(self) -> list[Task]:
        today = self.today()
        items = [t for t in self.data.tasks
                 if not t.done and t.planned_date and parse_date(t.planned_date) > today]
        return sorted(items, key=lambda t: (t.planned_date, t.order, t.created_at))

    def list_tasks(self, list_id: str) -> list[Task]:
        return self._sorted(t for t in self.data.tasks if t.list_id == list_id and not t.done)

    def lists(self) -> list[TaskList]:
        return sorted(self.data.lists, key=lambda l: l.order)

    def incomplete_count(self, list_id: str) -> int:
        return sum(1 for t in self.data.tasks if t.list_id == list_id and not t.done)

    def progress(self) -> progress.DayProgress:
        return progress.compute(self.data, self.today())

    def wins_today(self) -> int:
        return progress.units(self.data, self.today())[0]

    def next_task_after(self, task_id: str) -> Task | None:
        """Next task in My Day order after task_id, wrapping. Works after task_id completes."""
        current = self.task(task_id)
        items = [t for t in self.my_day() if t.id != task_id]
        if not items:
            return None
        if current is None:
            return items[0]
        key = (current.order, current.created_at)
        for t in items:
            if (t.order, t.created_at) > key:
                return t
        return items[0]

    # ---------- tasks ----------
    def _next_order(self) -> int:
        return max((t.order for t in self.data.tasks), default=-1) + 1

    def add_task(self, title: str, planned_date: date | str | None = None,
                 list_id: str | None = None, tag_ids: list[str] | None = None) -> Task:
        title = title.strip()
        if not title:
            raise ValueError("empty title")
        if list_id is None or self.list_by_id(list_id) is None:
            list_id = self.default_list_id()
        t = Task(id=new_id(), list_id=list_id, title=title, created_at=self.now_iso(),
                 planned_date=self._date_str(planned_date), order=self._next_order())
        tags = [i for i in (tag_ids or []) if self.tag_by_id(i)]
        if tags:
            t.extra["tags"] = list(dict.fromkeys(tags))
        self.data.tasks.append(t)
        self._changed()
        return t

    def update_task(self, task_id: str, *, title=_UNSET, notes=_UNSET,
                    planned_date=_UNSET, list_id=_UNSET) -> Task:
        t = self._task(task_id)
        if title is not _UNSET:
            title = title.strip()
            if title:
                t.title = title
        if notes is not _UNSET:
            t.notes = notes
        if planned_date is not _UNSET:
            t.planned_date = self._date_str(planned_date)
        if list_id is not _UNSET and self.list_by_id(list_id):
            t.list_id = list_id
        self._changed()
        return t

    def delete_task(self, task_id: str, include_completed: bool = False) -> None:
        """Delete a task and its steps. A completed task is only deleted with
        include_completed=True ("Delete from history"); it then leaves History."""
        t = self._task(task_id)
        if t.done and not include_completed:
            raise ValueError("completed tasks cannot be deleted")
        self.data.tasks.remove(t)
        self._changed()

    def reorder_tasks(self, ids: list[str]) -> None:
        """The tasks in `ids` take this order. They are re-dealt into the order slots they
        already hold, so tasks outside the view (other lists, other days) keep their places."""
        tasks = [t for t in (self.task(i) for i in dict.fromkeys(ids)) if t is not None]
        slots = sorted(t.order for t in tasks)
        for slot, t in zip(slots, tasks):
            t.order = slot
        self._changed()

    def set_repeat(self, task_id: str, rule: str) -> None:
        t = self._task(task_id)
        if rule in dates.REPEATS:
            t.extra["repeat"] = rule
        else:
            t.extra.pop("repeat", None)
        self._changed()

    def _spawn_repeat(self, t: Task) -> Task | None:
        """Plan the next copy of a repeating task: same title, list, notes, tags and steps
        (unchecked, notes kept), on its next date."""
        if not t.repeat:
            return None
        nxt = dates.next_occurrence(t.repeat, parse_date(t.planned_date), self.today())
        extra = {k: v for k, v in t.extra.items() if k != "completed_open"}
        copy = Task(id=new_id(), list_id=t.list_id, title=t.title, created_at=self.now_iso(),
                    notes=t.notes, planned_date=nxt.isoformat(), order=self._next_order(),
                    extra=extra)
        for s in t.steps_in_order:
            copy.steps.append(Step(id=new_id(), text=s.text, order=s.order,
                                   created_at=copy.created_at, notes=s.notes))
        self.data.tasks.append(copy)
        return copy

    # ---------- steps ----------
    def add_step(self, task_id: str, text: str) -> Step:
        text = text.strip()
        if not text:
            raise ValueError("empty step")
        t = self._task(task_id)
        order = max((s.order for s in t.steps), default=-1) + 1
        s = Step(id=new_id(), text=text, order=order, created_at=self.now_iso())
        t.steps.append(s)
        if t.done:  # adding work to a finished task reopens it
            t.completed_at = None
        self._changed()
        return s

    def edit_step(self, task_id: str, step_id: str, text: str) -> None:
        text = text.strip()
        s = self._task(task_id).step(step_id)
        if s and text:
            s.text = text
            self._changed()

    def set_step_notes(self, task_id: str, step_id: str, notes: str) -> None:
        s = self._task(task_id).step(step_id)
        if s is not None and s.notes != notes:
            s.notes = notes
            self._changed()

    def delete_step(self, task_id: str, step_id: str) -> None:
        t = self._task(task_id)
        s = t.step(step_id)
        if s and not s.done:
            t.steps.remove(s)
            self._changed()

    def move_step(self, task_id: str, step_id: str, new_index: int) -> None:
        """Move an incomplete step to new_index among the remaining steps.
        Done steps keep their positions: remaining steps are re-dealt into the
        order slots they already occupy."""
        t = self._task(task_id)
        rem = t.remaining_steps
        s = t.step(step_id)
        if s not in rem:
            return
        slots = [x.order for x in rem]          # already sorted
        rem.remove(s)
        new_index = max(0, min(new_index, len(rem)))
        rem.insert(new_index, s)
        for slot, x in zip(slots, rem):
            x.order = slot
        self._changed()

    # ---------- completion ----------
    def _remember(self, rec: _Undo) -> str:
        token = new_id()
        self._undo[token] = rec
        self._undo_order.append(token)
        while len(self._undo_order) > UNDO_KEEP:
            self._undo.pop(self._undo_order.pop(0), None)
        return token

    def _tasks_completed_today(self) -> int:
        today = self.today()
        return sum(1 for t in self.data.tasks if t.done and local_date_of(t.completed_at) == today)

    def _finish(self, kind: str, t: Task, step: Step | None, ts: str, completed_task: bool,
                step_index: int, remaining_before: int, first_task: bool,
                prev_floor: float, prev_floor_date: str | None) -> Completion:
        spawned = self._spawn_repeat(t) if completed_task else None
        p = self.progress()
        today = self.today().isoformat()
        s = self.data.settings
        day_complete = all_clear = False
        added_day = None
        if p.remaining == 0 and p.done >= 1 and remaining_before > 0:
            if today not in s.days_completed:
                s.days_completed.append(today)
                added_day = today
                day_complete = True
            else:
                all_clear = True
        token = self._remember(_Undo(kind, t.id, step.id if step else None, ts, completed_task,
                                     added_day, prev_floor, prev_floor_date,
                                     spawned.id if spawned else None))
        self._changed()
        return Completion(token, t.id, step.id if step else None, completed_task, step_index,
                          first_task and completed_task, day_complete, all_clear,
                          p.tasks_done, p.steps_done,
                          spawned.planned_date if spawned else None)

    def _floor_snapshot(self) -> tuple[float, str | None]:
        dp = self.data.settings.day_progress
        return float(dp.get("floor", 0.0)), dp.get("date")

    def complete_step(self, task_id: str, step_id: str) -> Completion:
        t = self._task(task_id)
        s = t.step(step_id)
        if s is None or s.done:
            raise ValueError("step not completable")
        prev_floor, prev_date = self._floor_snapshot()
        remaining_before = self.progress().remaining
        first_task = self._tasks_completed_today() == 0
        step_index = sum(1 for x in t.steps if x.done)
        ts = self.now_iso()
        s.done_at = ts
        completed = False
        if not t.done and not t.remaining_steps:
            t.completed_at = ts
            completed = True
        return self._finish("step", t, s, ts, completed, step_index, remaining_before,
                            first_task, prev_floor, prev_date)

    def complete_task(self, task_id: str) -> Completion:
        """Manual completion (step-less tasks, or 'Mark task done' in the editor).
        Remaining steps are NOT marked done; they drop out of the day total."""
        t = self._task(task_id)
        if t.done:
            raise ValueError("already complete")
        prev_floor, prev_date = self._floor_snapshot()
        remaining_before = self.progress().remaining
        first_task = self._tasks_completed_today() == 0
        ts = self.now_iso()
        t.completed_at = ts
        return self._finish("task", t, None, ts, True, sum(1 for x in t.steps if x.done),
                            remaining_before, first_task, prev_floor, prev_date)

    def undo(self, token: str) -> UndoResult:
        rec = self._undo.pop(token, None)
        if rec is None:
            return UndoResult(False)
        self._undo_order.remove(token)
        t = self.task(rec.task_id)
        if t is None:
            return UndoResult(False)
        reopened = False
        if rec.kind == "step":
            s = t.step(rec.step_id)
            if s is None or s.done_at != rec.done_at:
                return UndoResult(False)
            s.done_at = None
        if rec.completed_task and t.completed_at == rec.done_at:
            t.completed_at = None
            reopened = True
        elif rec.kind == "task":
            return UndoResult(False)
        if rec.spawned_id:  # the repeat's next copy goes away with the completion
            copy = self.task(rec.spawned_id)
            if copy is not None and not copy.done:
                self.data.tasks.remove(copy)
        revoked = False
        s = self.data.settings
        if rec.added_day and rec.added_day in s.days_completed:
            s.days_completed.remove(rec.added_day)
            revoked = True
        # Restore the ratchet so an undone completion doesn't leave the bar inflated
        # (and so 100% can't remain shown while work remains).
        dp = s.day_progress
        today = self.today().isoformat()
        if dp.get("date") == today:
            computed = progress.compute(self.data, self.today(), persist=False).computed
            prev = rec.prev_floor if rec.prev_floor_date == today else 0.0
            dp["floor"] = min(float(dp.get("floor", 0.0)), max(prev, computed))
        self._changed()
        return UndoResult(True, revoked, reopened)

    def restore_step(self, task_id: str, step_id: str) -> None:
        """Un-complete a step from the editor's 'Completed steps' disclosure."""
        t = self._task(task_id)
        s = t.step(step_id)
        if s is None or not s.done:
            return
        s.done_at = None            # stays in its original position
        if t.done:
            t.completed_at = None
        self._changed()

    def completed_steps(self, task_id: str) -> list[Step]:
        return self._task(task_id).done_steps

    def set_completed_open(self, task_id: str, is_open: bool) -> None:
        t = self._task(task_id)
        if is_open:
            t.extra["completed_open"] = True
        else:
            t.extra.pop("completed_open", None)
        self._changed()

    def set_task_pomodoro(self, task_id: str, on: bool) -> None:
        t = self._task(task_id)
        if on:
            t.extra.pop("pomodoro_off", None)
        else:
            t.extra["pomodoro_off"] = True
        self._changed()

    # ---------- lists ----------
    def find_list(self, name: str) -> TaskList | None:
        """Case-insensitive lookup (lists themselves keep their own casing)."""
        key = name.strip().casefold()
        return next((l for l in self.lists() if l.name.casefold() == key), None) if key else None

    def match_lists(self, query: str) -> list[TaskList]:
        """Lists whose name contains query (case-insensitive); prefix matches first."""
        q = query.strip().casefold()
        lists = self.lists()
        if not q:
            return lists
        starts = [l for l in lists if l.name.casefold().startswith(q)]
        contains = [l for l in lists if q in l.name.casefold() and l not in starts]
        return starts + contains

    def ensure_list(self, name: str) -> TaskList:
        """Existing list matching name (any case), or a new list named exactly as typed."""
        return self.find_list(name) or self.add_list(name)

    def add_list(self, name: str) -> TaskList:
        name = name.strip()
        if not name:
            raise ValueError("empty name")
        order = max((l.order for l in self.data.lists), default=-1) + 1
        l = TaskList(id=new_id(), name=name, order=order)
        self.data.lists.append(l)
        self._changed()
        return l

    def reorder_lists(self, ids: list[str]) -> None:
        order = {i: n for n, i in enumerate(dict.fromkeys(ids))}
        rest = [l for l in self.lists() if l.id not in order]
        for n, l in enumerate(sorted((l for l in self.data.lists if l.id in order),
                                     key=lambda l: order[l.id]) + rest):
            l.order = n
        self._changed()

    def rename_list(self, list_id: str, name: str) -> None:
        l = self.list_by_id(list_id)
        if l and name.strip():
            l.name = name.strip()
            self._changed()

    def delete_list(self, list_id: str, move_to: str | None = None) -> None:
        l = self.list_by_id(list_id)
        if l is None:
            return
        if len(self.data.lists) == 1:
            raise ValueError("cannot delete the last list")
        owned = [t for t in self.data.tasks if t.list_id == list_id]
        if owned:
            if move_to is None or move_to == list_id or self.list_by_id(move_to) is None:
                raise ValueError("choose a list to move tasks to")
            for t in owned:  # completed tasks move too, so history is kept
                t.list_id = move_to
        self.data.lists.remove(l)
        self._changed()

    # ---------- tags ----------
    def tags(self) -> list[Tag]:
        return sorted(self.data.tags, key=lambda g: g.order)

    def tag_by_id(self, tag_id: str) -> Tag | None:
        return next((g for g in self.data.tags if g.id == tag_id), None)

    def find_tag(self, name: str) -> Tag | None:
        key = name.strip().casefold()
        return next((g for g in self.tags() if g.name.casefold() == key), None) if key else None

    def match_tags(self, query: str) -> list[Tag]:
        q = query.strip().casefold()
        tags = self.tags()
        if not q:
            return tags
        starts = [g for g in tags if g.name.casefold().startswith(q)]
        return starts + [g for g in tags if q in g.name.casefold() and g not in starts]

    def add_tag(self, name: str, color: str | None = None) -> Tag:
        name = name.strip()
        if not name:
            raise ValueError("empty name")
        order = max((g.order for g in self.data.tags), default=-1) + 1
        g = Tag(id=new_id(), name=name, order=order,
                color=color or TAG_COLORS[len(self.data.tags) % len(TAG_COLORS)])
        self.data.tags.append(g)
        self._changed()
        return g

    def ensure_tag(self, name: str) -> Tag:
        return self.find_tag(name) or self.add_tag(name)

    def update_tag(self, tag_id: str, name: str | None = None, color: str | None = None) -> None:
        g = self.tag_by_id(tag_id)
        if g is None:
            return
        if name and name.strip():
            g.name = name.strip()
        if color:
            g.color = color
        self._changed()

    def delete_tag(self, tag_id: str) -> None:
        g = self.tag_by_id(tag_id)
        if g is None:
            return
        self.data.tags.remove(g)
        for t in self.data.tasks:
            if tag_id in t.tag_ids:
                rest = [i for i in t.tag_ids if i != tag_id]
                if rest:
                    t.extra["tags"] = rest
                else:
                    t.extra.pop("tags", None)
        self._changed()

    def set_task_tags(self, task_id: str, tag_ids: list[str]) -> None:
        t = self._task(task_id)
        ids = [i for i in dict.fromkeys(tag_ids) if self.tag_by_id(i)]
        if ids:
            t.extra["tags"] = ids
        else:
            t.extra.pop("tags", None)
        self._changed()

    # ---------- settings ----------
    def set_setting(self, name: str, value) -> None:
        setattr(self.data.settings, name, value)
        self._changed()
