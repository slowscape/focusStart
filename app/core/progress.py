"""Day-progress units, the one-way ratchet, and day-complete detection. No Qt.

Units: each step is 1 unit; a task with no steps is 1 unit.
  done      = steps with done_at today + step-less tasks with completed_at today
  remaining = incomplete steps of incomplete My Day tasks + incomplete step-less My Day tasks
"""
from __future__ import annotations

from dataclasses import dataclass
from datetime import date

from .dates import local_date_of, parse_date
from .models import AppData, Settings, Task

# If the day was full (floor == 1.0) and new work is added, the bar can't stay
# at 100% (100% means remaining == 0), so it holds just short of full.
NEAR_FULL = 0.95


@dataclass
class DayProgress:
    done: int
    remaining: int
    total: int
    computed: float
    displayed: float
    steps_done: int
    tasks_done: int


def in_my_day(task: Task, today: date) -> bool:
    if task.done or not task.planned_date:
        return False
    return parse_date(task.planned_date) <= today


def units(data: AppData, today: date) -> tuple[int, int, int, int]:
    """Return (done, remaining, steps_done_today, tasks_done_today)."""
    done = remaining = steps_done = tasks_done = 0
    for t in data.tasks:
        for s in t.steps:
            if s.done and local_date_of(s.done_at) == today:
                steps_done += 1
        if t.done and local_date_of(t.completed_at) == today:
            tasks_done += 1
            if t.stepless:
                done += 1
        if in_my_day(t, today):
            remaining += 1 if t.stepless else len(t.remaining_steps)
    done += steps_done
    return done, remaining, steps_done, tasks_done


def displayed_fill(floor: float, computed: float, remaining: int) -> float:
    if remaining == 0:
        return max(floor, computed)
    shown = max(floor, computed)
    if shown >= 1.0:  # only possible when a previously full day got new work
        shown = max(computed, NEAR_FULL)
    return shown


def compute(data: AppData, today: date, persist: bool = True) -> DayProgress:
    done, remaining, steps_done, tasks_done = units(data, today)
    total = done + remaining
    computed = done / total if total else 0.0
    s: Settings = data.settings
    dp = s.day_progress
    floor = float(dp.get("floor", 0.0)) if dp.get("date") == today.isoformat() else 0.0
    shown = displayed_fill(floor, computed, remaining) if total else 0.0
    if persist:
        s.day_progress = {"date": today.isoformat(), "floor": max(floor, computed)}
    return DayProgress(done, remaining, total, computed, shown, steps_done, tasks_done)
