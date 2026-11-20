"""What goes on a printed checklist (My Day or a list). No Qt; app/qt/pdf.py draws it.

Every task and each of its remaining steps gets an empty checkbox. Body text is 18 pt.
"""
from __future__ import annotations

from dataclasses import dataclass, field

from .models import Task

BODY_PT = 18
HEADING_PT = 26
SUB_PT = 12


@dataclass
class PrintTask:
    title: str
    steps: list[str] = field(default_factory=list)


def from_tasks(tasks: list[Task]) -> list[PrintTask]:
    """Open tasks with their remaining (not done) steps, in order."""
    return [PrintTask(t.title, [s.text for s in t.remaining_steps]) for t in tasks if not t.done]


def filename(heading: str, iso_date: str) -> str:
    """'My Day 2026-11-17.pdf'; characters Windows forbids in file names are dropped."""
    safe = "".join(c for c in heading if c not in '<>:"/\\|?*').strip() or "StepTask"
    return f"{safe} {iso_date}.pdf"
