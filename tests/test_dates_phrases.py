"""Date windows and positive-only copy. (Recap tests were removed with the recap screen.)"""
import re
from datetime import date, timedelta, timezone

from app.core import dates, phrases


def test_week_window_both_starts():
    wed = date(2026, 11, 18)
    assert dates.week_window(wed, "monday") == (date(2026, 11, 16), wed)
    assert dates.week_window(wed, "sunday") == (date(2026, 11, 15), wed)
    sun = date(2026, 11, 22)
    assert dates.week_window(sun, "monday") == (date(2026, 11, 16), sun)
    assert dates.week_window(sun, "sunday") == (sun, sun)


def test_month_and_year_boundary():
    assert dates.month_window(date(2027, 1, 1)) == (date(2027, 1, 1), date(2027, 1, 1))
    assert dates.yesterday_window(date(2027, 1, 1)) == (date(2026, 12, 31),) * 2
    assert dates.week_window(date(2027, 1, 1), "monday")[0] == date(2026, 12, 28)


def test_dst_bucketing_uses_wall_clock_date():
    # US DST ends 2026-11-01. 23:30 PDT and 23:30 PST both stay on their own day.
    assert dates.local_date_of("2026-10-31T23:30:00-07:00") == date(2026, 10, 31)
    assert dates.local_date_of("2026-11-01T23:30:00-08:00") == date(2026, 11, 1)


def _forbidden_hit(text):
    low = text.lower()
    for f in phrases.FORBIDDEN:
        if re.search(r"\b" + re.escape(f.strip()) + r"\b", low):
            return f
    return None


def test_no_forbidden_phrases_anywhere():
    for pool in (phrases.ENCOURAGEMENTS, phrases.TASK_DONE, phrases.PLAN_TIMER_DONE):
        for text in pool:
            assert _forbidden_hit(text) is None, text
