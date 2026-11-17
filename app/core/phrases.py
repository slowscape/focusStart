"""Fixed, positive-only copy pools. No Qt."""
from __future__ import annotations

import random

ENCOURAGEMENTS = [
    "Nice.", "One down.", "That's momentum.", "Done.", "Good move.",
    "Keep rolling.", "Look at you go.", "Another one.", "Smooth.", "On a roll.",
]

TASK_DONE = [
    "Task done. Nice work.", "Finished. That counts.", "All steps done.",
    "That one's wrapped up.", "Done and dusted.",
]

PLAN_TIMER_DONE = ["That's a real start.", "Nice planning. Keep going if you like.",
                   "That's the hardest part done."]

# Words that must never appear in any user-facing copy (guardrails, section 9).
FORBIDDEN = [
    "overdue", "late", "missed", "streak", "haven't", "havent", "didn't", "didnt",
    "behind", "failed", "fail", "should have", "only ", "lost", "broke your",
    "you forgot", "again?", "last chance", "deadline",
]


def pick_different(pool: list[str], last: str | None, rng: random.Random | None = None) -> str:
    rng = rng or random.Random()
    choices = [p for p in pool if p != last] or pool
    return rng.choice(choices)
