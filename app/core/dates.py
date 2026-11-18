"""Local-date helpers. No Qt imports.

All "day" bucketing uses the wall-clock date recorded in each timestamp
(timestamps are stored with the local offset in effect at the time), so a
step finished at 23:30 local stays on that day even across DST changes or
time-zone travel.
"""
from __future__ import annotations

from datetime import date, datetime, timedelta
from typing import Callable

Clock = Callable[[], datetime]


def system_now() -> datetime:
    """Current local time, timezone-aware."""
    return datetime.now().astimezone()


def to_iso(dt: datetime) -> str:
    return dt.isoformat(timespec="seconds")


def local_date_of(ts: str | None) -> date | None:
    """Wall-clock date of an ISO timestamp (keeps its own offset)."""
    if not ts:
        return None
    return datetime.fromisoformat(ts).date()


def parse_date(s: str | None) -> date | None:
    if not s:
        return None
    return date.fromisoformat(s)


def week_start(d: date, week_starts: str = "monday") -> date:
    if week_starts == "sunday":
        offset = (d.weekday() + 1) % 7
    else:
        offset = d.weekday()
    return d - timedelta(days=offset)


def week_end(d: date, week_starts: str = "monday") -> date:
    return week_start(d, week_starts) + timedelta(days=6)


def month_start(d: date) -> date:
    return d.replace(day=1)


def yesterday_window(today: date) -> tuple[date, date]:
    y = today - timedelta(days=1)
    return y, y


def week_window(today: date, week_starts: str = "monday") -> tuple[date, date]:
    """From the configured week start through today, inclusive."""
    return week_start(today, week_starts), today


def month_window(today: date) -> tuple[date, date]:
    """From the 1st through today, inclusive."""
    return month_start(today), today


def in_window(d: date | None, window: tuple[date, date]) -> bool:
    return d is not None and window[0] <= d <= window[1]


REPEATS = ("daily", "weekdays", "weekly", "monthly")


def _add_month(d: date, day: int) -> date:
    y, m = (d.year + 1, 1) if d.month == 12 else (d.year, d.month + 1)
    last = (date(y + (m == 12), m % 12 + 1, 1) - timedelta(days=1)).day
    return date(y, m, min(day, last))


def next_occurrence(rule: str, anchor: date | None, today: date) -> date:
    """First date after today in the series that `anchor` (the task's planned date,
    or today if it had none) belongs to. Always at least one step after the anchor."""
    d = anchor or today
    day = d.day
    while True:
        if rule == "weekdays":
            d += timedelta(days=1)
            while d.weekday() >= 5:
                d += timedelta(days=1)
        elif rule == "weekly":
            d += timedelta(days=7)
        elif rule == "monthly":
            d = _add_month(d, day)
        else:  # daily
            d += timedelta(days=1)
        if d > today:
            return d
