"""Plain dataclasses for the data file. No Qt imports.

Unknown keys are preserved in ``extra`` so a file touched by a newer build of
the same schema version does not lose data when saved by this one.
"""
from __future__ import annotations

import uuid
from dataclasses import dataclass, field
from datetime import date, datetime
from typing import Any

from .pomodoro import clean_settings as clean_pomodoro

SCHEMA_VERSION = 1
EFFECTS = ("full", "calm", "off")
APPEARANCES = ("system", "light", "dark")
WEEK_STARTS = ("monday", "sunday")


def new_id() -> str:
    return str(uuid.uuid4())


def _split(d: dict, known: set[str]) -> dict:
    return {k: v for k, v in d.items() if k not in known}


def _req_str(d: dict, key: str) -> str:
    v = d[key]
    if not isinstance(v, str):
        raise ValueError(f"{key} must be a string")
    return v


def _opt_str(d: dict, key: str) -> str | None:
    v = d.get(key)
    if v is not None and not isinstance(v, str):
        raise ValueError(f"{key} must be a string or null")
    return v


def _check_ts(v: str | None) -> str | None:
    if v is not None:
        datetime.fromisoformat(v)  # raises ValueError if malformed
    return v


def _check_date(v: str | None) -> str | None:
    if v is not None:
        date.fromisoformat(v)
    return v


@dataclass
class Step:
    id: str
    text: str
    order: int
    created_at: str
    done_at: str | None = None
    notes: str = ""
    extra: dict = field(default_factory=dict)

    KEYS = {"id", "text", "order", "created_at", "done_at", "notes"}

    @property
    def done(self) -> bool:
        return self.done_at is not None

    @classmethod
    def from_dict(cls, d: dict) -> "Step":
        return cls(
            id=_req_str(d, "id"),
            text=_req_str(d, "text"),
            order=int(d.get("order", 0)),
            created_at=_check_ts(_req_str(d, "created_at")),
            done_at=_check_ts(_opt_str(d, "done_at")),
            notes=d.get("notes") if isinstance(d.get("notes"), str) else "",
            extra=_split(d, cls.KEYS),
        )

    def to_dict(self) -> dict:
        out = dict(self.extra)
        out.update(id=self.id, text=self.text, order=self.order,
                   created_at=self.created_at, done_at=self.done_at)
        if self.notes:
            out["notes"] = self.notes
        return out


@dataclass
class Task:
    id: str
    list_id: str
    title: str
    created_at: str
    notes: str = ""
    planned_date: str | None = None
    completed_at: str | None = None
    order: int = 0
    steps: list[Step] = field(default_factory=list)
    extra: dict = field(default_factory=dict)

    KEYS = {"id", "list_id", "title", "notes", "planned_date", "created_at",
            "completed_at", "order", "steps"}

    @property
    def done(self) -> bool:
        return self.completed_at is not None

    @property
    def remaining_steps(self) -> list[Step]:
        return sorted((s for s in self.steps if not s.done), key=lambda s: s.order)

    @property
    def done_steps(self) -> list[Step]:
        return sorted((s for s in self.steps if s.done), key=lambda s: s.done_at or "")

    @property
    def completed_open(self) -> bool:
        return bool(self.extra.get("completed_open", False))

    @property
    def tag_ids(self) -> list[str]:
        v = self.extra.get("tags")
        return [x for x in v if isinstance(x, str)] if isinstance(v, list) else []

    @property
    def repeat(self) -> str:
        """"" or one of dates.REPEATS (stored as extra.repeat)."""
        v = self.extra.get("repeat")
        return v if isinstance(v, str) else ""

    @property
    def pomodoro_on(self) -> bool:
        """Per-task Pomodoro switch (stored as extra.pomodoro_off; default on)."""
        return not self.extra.get("pomodoro_off", False)

    @property
    def steps_in_order(self) -> list[Step]:
        return sorted(self.steps, key=lambda s: s.order)

    @property
    def stepless(self) -> bool:
        return not self.steps

    def step(self, step_id: str) -> Step | None:
        return next((s for s in self.steps if s.id == step_id), None)

    @classmethod
    def from_dict(cls, d: dict) -> "Task":
        steps = d.get("steps", [])
        if not isinstance(steps, list):
            raise ValueError("steps must be a list")
        notes = d.get("notes") or ""
        if not isinstance(notes, str):
            raise ValueError("notes must be a string")
        return cls(
            id=_req_str(d, "id"),
            list_id=_req_str(d, "list_id"),
            title=_req_str(d, "title"),
            notes=notes,
            planned_date=_check_date(_opt_str(d, "planned_date")),
            created_at=_check_ts(_req_str(d, "created_at")),
            completed_at=_check_ts(_opt_str(d, "completed_at")),
            order=int(d.get("order", 0)),
            steps=[Step.from_dict(s) for s in steps],
            extra=_split(d, cls.KEYS),
        )

    def to_dict(self) -> dict:
        out = dict(self.extra)
        out.update(id=self.id, list_id=self.list_id, title=self.title, notes=self.notes,
                   planned_date=self.planned_date, created_at=self.created_at,
                   completed_at=self.completed_at, order=self.order,
                   steps=[s.to_dict() for s in self.steps])
        return out


@dataclass
class TaskList:
    id: str
    name: str
    order: int = 0
    extra: dict = field(default_factory=dict)

    KEYS = {"id", "name", "order"}

    @classmethod
    def from_dict(cls, d: dict) -> "TaskList":
        return cls(id=_req_str(d, "id"), name=_req_str(d, "name"),
                   order=int(d.get("order", 0)), extra=_split(d, cls.KEYS))

    def to_dict(self) -> dict:
        out = dict(self.extra)
        out.update(id=self.id, name=self.name, order=self.order)
        return out


# Tag colours: friendly, distinct, readable on light and dark. (No red: SPEC section 9.)
TAG_COLORS = ["#4f8ff7", "#2bb3a3", "#5cb85c", "#e0b028", "#f0883e", "#a371f7", "#e86bb0", "#8b949e"]


@dataclass
class Tag:
    id: str
    name: str
    color: str = TAG_COLORS[0]
    order: int = 0
    extra: dict = field(default_factory=dict)

    KEYS = {"id", "name", "color", "order"}

    @classmethod
    def from_dict(cls, d: dict) -> "Tag":
        color = d.get("color") if isinstance(d.get("color"), str) else TAG_COLORS[0]
        return cls(id=_req_str(d, "id"), name=_req_str(d, "name"), color=color,
                   order=int(d.get("order", 0)), extra=_split(d, cls.KEYS))

    def to_dict(self) -> dict:
        out = dict(self.extra)
        out.update(id=self.id, name=self.name, color=self.color, order=self.order)
        return out


BACKGROUND_INTERVALS = (5, 15, 60, 1440)   # minutes; 1440 = once a day


def clean_background(d) -> dict:
    out = {"enabled": False, "folder": "", "interval": 15}
    if isinstance(d, dict):
        out["enabled"] = bool(d.get("enabled", False))
        if isinstance(d.get("folder"), str):
            out["folder"] = d["folder"]
        if d.get("interval") in BACKGROUND_INTERVALS:
            out["interval"] = d["interval"]
    return out


@dataclass
class Settings:
    sound: bool = True
    volume: float = 0.7
    effects: str = "full"
    week_starts: str = "monday"
    appearance: str = "system"      # light/dark override; "system" follows Windows
    day_progress: dict = field(default_factory=lambda: {"date": None, "floor": 0.0})
    days_completed: list[str] = field(default_factory=list)
    window: dict | None = None
    pomodoro: dict = field(default_factory=lambda: clean_pomodoro(None))
    background: dict = field(default_factory=lambda: clean_background(None))
    extra: dict = field(default_factory=dict)

    # Old files may still hold "last_recap_date"/"recap_history" (recap screen removed);
    # like any unknown key they are kept in extra.
    KEYS = {"sound", "volume", "effects", "week_starts", "appearance",
            "day_progress", "days_completed", "window", "pomodoro", "background"}

    @classmethod
    def from_dict(cls, d: dict) -> "Settings":
        s = cls()
        s.sound = bool(d.get("sound", True))
        try:
            s.volume = min(1.0, max(0.0, float(d.get("volume", 0.7))))
        except (TypeError, ValueError):
            s.volume = 0.7
        s.effects = d.get("effects") if d.get("effects") in EFFECTS else "full"
        s.week_starts = d.get("week_starts") if d.get("week_starts") in WEEK_STARTS else "monday"
        s.appearance = d.get("appearance") if d.get("appearance") in APPEARANCES else "system"
        dp = d.get("day_progress")
        if isinstance(dp, dict):
            try:
                s.day_progress = {"date": dp.get("date"), "floor": float(dp.get("floor", 0.0))}
            except (TypeError, ValueError):
                pass
        dc = d.get("days_completed")
        if isinstance(dc, list):
            s.days_completed = [x for x in dc if isinstance(x, str)]
        w = d.get("window")
        if isinstance(w, dict) and all(isinstance(w.get(k), (int, float)) for k in ("x", "y", "w", "h")):
            s.window = {k: int(w[k]) for k in ("x", "y", "w", "h")}
        s.pomodoro = clean_pomodoro(d.get("pomodoro"))
        s.background = clean_background(d.get("background"))
        s.extra = _split(d, cls.KEYS)
        return s

    def to_dict(self) -> dict:
        out = dict(self.extra)
        out.update(sound=self.sound, volume=self.volume, effects=self.effects,
                   week_starts=self.week_starts, appearance=self.appearance,
                   day_progress=dict(self.day_progress),
                   days_completed=list(self.days_completed), window=self.window,
                   pomodoro=dict(self.pomodoro), background=dict(self.background))
        return out


@dataclass
class AppData:
    settings: Settings = field(default_factory=Settings)
    lists: list[TaskList] = field(default_factory=list)
    tasks: list[Task] = field(default_factory=list)
    tags: list[Tag] = field(default_factory=list)
    schema_version: int = SCHEMA_VERSION
    extra: dict = field(default_factory=dict)

    KEYS = {"schema_version", "settings", "lists", "tasks", "tags"}

    @classmethod
    def new(cls) -> "AppData":
        return cls(lists=[TaskList(id=new_id(), name="Tasks", order=0)])

    @classmethod
    def from_dict(cls, d: dict) -> "AppData":
        if not isinstance(d, dict):
            raise ValueError("root must be an object")
        lists = d.get("lists", [])
        tasks = d.get("tasks", [])
        tags = d.get("tags", [])
        if not isinstance(lists, list) or not isinstance(tasks, list):
            raise ValueError("lists and tasks must be arrays")
        if not isinstance(tags, list):
            tags = []
        data = cls(
            settings=Settings.from_dict(d.get("settings") or {}),
            lists=[TaskList.from_dict(x) for x in lists],
            tasks=[Task.from_dict(x) for x in tasks],
            tags=[Tag.from_dict(x) for x in tags if isinstance(x, dict)],
            schema_version=int(d.get("schema_version", SCHEMA_VERSION)),
            extra=_split(d, cls.KEYS),
        )
        if not data.lists:
            data.lists.append(TaskList(id=new_id(), name="Tasks", order=0))
        # Repair orphaned tasks rather than lose them.
        ids = {l.id for l in data.lists}
        for t in data.tasks:
            if t.list_id not in ids:
                t.list_id = data.lists[0].id
        return data

    def to_dict(self) -> dict:
        out = dict(self.extra)
        out.update(schema_version=self.schema_version, settings=self.settings.to_dict(),
                   lists=[l.to_dict() for l in self.lists],
                   tasks=[t.to_dict() for t in self.tasks],
                   tags=[g.to_dict() for g in self.tags])
        return out
