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
