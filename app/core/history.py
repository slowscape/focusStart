"""Every completed step and task, newest first. No Qt."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date, datetime

from .models import AppData


@dataclass
class HistoryEvent:
    ts: str
    kind: str          # "step" | "task"
    text: str          # step text or task title
    task_title: str
    list_name: str
    task_id: str
    item_id: str       # step id, or task id for tasks

    @property
    def when(self) -> datetime:
        return datetime.fromisoformat(self.ts)


def events(data: AppData) -> list[HistoryEvent]:
    names = {l.id: l.name for l in data.lists}
    out: list[HistoryEvent] = []
    for t in data.tasks:
        lst = names.get(t.list_id, "")
        for s in t.steps:
            if s.done_at:
                out.append(HistoryEvent(s.done_at, "step", s.text, t.title, lst, t.id, s.id))
        if t.completed_at:
            out.append(HistoryEvent(t.completed_at, "task", t.title, t.title, lst, t.id, t.id))
    # Newest first. Within the same second a task sorts after its last step (it happened "after").
    out.sort(key=lambda e: (e.when.timestamp(), e.kind == "task"), reverse=True)
    return out


@dataclass
class Totals:
    label: str
    tasks: int
    steps: int


def totals(data: AppData, today: date, week_starts: str = "monday") -> list[Totals]:
    """Finished tasks and steps: this week, this month, this year, all time."""
    from .dates import local_date_of, week_start
    windows = [("This week", week_start(today, week_starts)), ("This month", today.replace(day=1)),
               ("This year", today.replace(month=1, day=1)), ("All time", date.min)]
    counts = [[0, 0] for _ in windows]
    for t in data.tasks:
        stamps = [(local_date_of(s.done_at), 1) for s in t.steps if s.done_at]
        if t.completed_at:
            stamps.append((local_date_of(t.completed_at), 0))
        for d, is_step in stamps:
            for i, (_, start) in enumerate(windows):
                if start <= d <= today or (start == date.min and d is not None):
                    counts[i][is_step] += 1
    return [Totals(label, c[0], c[1]) for (label, _), c in zip(windows, counts)]


def day_label(d: date, today: date) -> str:
    delta = (today - d).days
    if delta == 0:
        return "Today"
    if delta == 1:
        return "Yesterday"
    label = f"{d.strftime('%A')}, {d.strftime('%B')} {d.day}"
    return label if d.year == today.year else f"{label}, {d.year}"


def time_label(dt: datetime) -> str:
    h = dt.hour % 12 or 12
    return f"{h}:{dt.minute:02d} {'AM' if dt.hour < 12 else 'PM'}"
