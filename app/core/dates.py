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
