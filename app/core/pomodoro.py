"""Pomodoro timer logic. No Qt; time is passed in (monotonic seconds) so it's testable.

Rules: focus -> short break, and every Nth focus -> long break instead; breaks -> focus.
Focus -> break advances on its own. When a break ends, the next focus session is set up
but waits (paused, full length) until the user presses Start: nobody is back on the second.
Duration changes apply live.
"""
from __future__ import annotations

from dataclasses import dataclass, field

PHASES = ("work", "short", "long")
DOCK_EDGES = ("top", "bottom", "left", "right")
DEFAULTS = {"enabled": True, "work": 25, "short": 5, "long": 15, "long_every": 4,
            "notch": False}  # notch: show the running timer in a pill at the top of the screen
# Allowed range per setting (minutes, or sessions for long_every). The UI uses the same limits.
LIMITS = {"work": (1, 180), "short": (1, 60), "long": (1, 120), "long_every": (2, 12)}


def clamp(key: str, value: int) -> int:
    lo, hi = LIMITS[key]
    return max(lo, min(hi, int(value)))


def clean_settings(d: dict | None) -> dict:
    out = dict(DEFAULTS)
    if isinstance(d, dict):
        for key in ("enabled", "notch"):
            if isinstance(d.get(key), bool):
                out[key] = d[key]
        # Where the notch pill is docked: a screen edge, and its centre along that edge as a
        # fraction of the edge's length (absent = top centre).
        dock = d.get("notch_dock")
        if isinstance(dock, dict) and dock.get("edge") in DOCK_EDGES \
                and isinstance(dock.get("pos"), (int, float)):
            out["notch_dock"] = {"edge": dock["edge"], "pos": min(1.0, max(0.0, float(dock["pos"])))}
        for k, (lo, hi) in LIMITS.items():
            try:
                out[k] = max(lo, min(hi, int(d.get(k, out[k]))))
            except (TypeError, ValueError):
                pass
    return out


@dataclass
class Pomodoro:
    work: int = 25           # minutes
    short: int = 5
    long: int = 15
    long_every: int = 4
    phase: str = ""          # "" when stopped
    paused: bool = False
    waiting: bool = False    # break over; next focus session waits for Start
    work_done: int = 0       # focus sessions finished in the current cycle (0..long_every-1)
    _elapsed: float = 0.0    # seconds run in this phase before the current run segment
    _since: float | None = None

    @property
    def running(self) -> bool:
        return self.phase != ""

    def length(self, phase: str | None = None) -> float:
        return 60.0 * {"work": self.work, "short": self.short, "long": self.long}[phase or self.phase]

    def elapsed(self, now: float) -> float:
        return self._elapsed + ((now - self._since) if self._since is not None else 0.0)

    def remaining(self, now: float) -> float:
        if not self.running:
            return 0.0
        return max(0.0, self.length() - self.elapsed(now))

    # ----- controls
    def start(self, now: float) -> None:
        self.phase, self.paused, self.work_done, self.waiting = "work", False, 0, False
        self._elapsed, self._since = 0.0, now

    def stop(self) -> None:
        self.phase, self.paused, self.work_done, self.waiting = "", False, 0, False
        self._elapsed, self._since = 0.0, None

    def pause(self, now: float) -> None:
        if self.running and not self.paused:
            self._elapsed = self.elapsed(now)
            self._since, self.paused = None, True

    def resume(self, now: float) -> None:
        if self.running and self.paused:
            self._since, self.paused, self.waiting = now, False, False

    def set_minutes(self, phase: str, minutes: int, now: float) -> list[str]:
        """Change a duration live. Returns phases entered if the change ends the current one."""
        minutes = max(1, int(minutes))
        setattr(self, phase, minutes)
        return self.tick(now)

    # ----- time passing
    def _next_phase(self) -> str:
        if self.phase == "work":
            self.work_done += 1
            if self.work_done >= self.long_every:
                self.work_done = 0
                return "long"
            return "short"
        return "work"

    def tick(self, now: float) -> list[str]:
        """Advance through any finished phases; returns the phases entered (usually 0 or 1)."""
        entered: list[str] = []
        if not self.running or self.paused:
            return entered
        guard = 0
        while self.elapsed(now) >= self.length() and guard < 50:
            over = self.elapsed(now) - self.length()
            self.phase = self._next_phase()
            entered.append(self.phase)
            guard += 1
            if self.phase == "work":   # break over: hold the new session until Start
                self._elapsed, self._since = 0.0, None
                self.paused = self.waiting = True
                break
            self._elapsed, self._since = over, now
        return entered
