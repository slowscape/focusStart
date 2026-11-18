"""Step notes, tags, repeating tasks, reordering, History totals, background settings."""
from datetime import date

import pytest

from app.core import dates, history
from app.core.models import AppData, clean_background
from tests.conftest import PST  # noqa: F401  (fixtures come from conftest)

TODAY = date(2026, 11, 16)  # a Monday


# ---------------- step notes
def test_step_notes_roundtrip_and_compact(svc):
    t = svc.add_task("t", TODAY)
    a = svc.add_step(t.id, "a")
    b = svc.add_step(t.id, "b")
    svc.set_step_notes(t.id, a.id, "left off here")
    d = svc.data.to_dict()
    steps = d["tasks"][0]["steps"]
    assert steps[0]["notes"] == "left off here" and "notes" not in steps[1]   # empty notes not written
    again = AppData.from_dict(d)
    assert again.tasks[0].step(a.id).notes == "left off here"
    assert again.tasks[0].step(b.id).notes == ""


# ---------------- reorder
def test_reorder_tasks_keeps_other_tasks_in_place(svc):
    a, b, c = (svc.add_task(n, TODAY) for n in "abc")
    other = svc.add_task("other list", None)
    before = other.order
    svc.reorder_tasks([c.id, a.id, b.id])
    assert [t.title for t in svc.my_day()] == ["c", "a", "b"]
    assert other.order == before


def test_reorder_lists(svc):
    home = svc.add_list("Home")
    work = svc.add_list("Work")
    first = svc.lists()[0]
    svc.reorder_lists([work.id, first.id, home.id])
    assert [l.name for l in svc.lists()] == ["Work", "Tasks", "Home"]


# ---------------- repeating tasks
@pytest.mark.parametrize("rule,anchor,expected", [
    ("daily", date(2026, 11, 16), date(2026, 11, 17)),
    ("daily", date(2026, 11, 10), date(2026, 11, 17)),      # rolled over: next is tomorrow
    ("weekdays", date(2026, 11, 20), date(2026, 11, 23)),   # Friday -> Monday
    ("weekly", date(2026, 11, 11), date(2026, 11, 18)),     # stays on Wednesdays
    ("monthly", date(2026, 10, 31), date(2026, 11, 30)),    # 31st clamps to month end
    ("monthly", date(2026, 11, 16), date(2026, 12, 16)),
])
def test_next_occurrence(rule, anchor, expected):
    assert dates.next_occurrence(rule, anchor, TODAY) == expected


def test_monthly_returns_to_the_31st_after_short_month():
    assert dates.next_occurrence("monthly", date(2027, 1, 31), date(2027, 1, 31)) == date(2027, 2, 28)
    # The day of month comes from the anchor, so a later anchor on the 28th stays on the 28th.
    assert dates.next_occurrence("monthly", date(2027, 2, 28), date(2027, 2, 28)) == date(2027, 3, 28)


def test_completing_repeating_task_plans_fresh_copy_and_undo_removes_it(svc):
    t = svc.add_task("Water plants", TODAY)
    s1 = svc.add_step(t.id, "Fill can")
    s2 = svc.add_step(t.id, "Water")
    svc.set_step_notes(t.id, s1.id, "blue can")
    svc.set_repeat(t.id, "daily")
    svc.complete_step(t.id, s1.id)
    c = svc.complete_step(t.id, s2.id)
    assert c.task_completed and c.repeat_date == "2026-11-17"
    copies = [x for x in svc.data.tasks if x.title == "Water plants" and not x.done]
    assert len(copies) == 1
    copy = copies[0]
    assert copy.planned_date == "2026-11-17" and copy.repeat == "daily"
    assert [(s.text, s.done, s.notes) for s in copy.steps_in_order] == [
        ("Fill can", False, "blue can"), ("Water", False, "")]
    assert copy not in svc.my_day()                        # it's for tomorrow
    svc.undo(c.token)
    assert svc.task(copy.id) is None and not svc.task(t.id).done


def test_non_repeating_task_spawns_nothing(svc):
    t = svc.add_task("once", TODAY)
    svc.complete_task(t.id)
    assert len(svc.data.tasks) == 1


# ---------------- tags
def test_tags_crud_and_task_assignment(svc):
    work = svc.add_tag("Work")
    calls = svc.ensure_tag("calls")
    assert svc.ensure_tag("CALLS").id == calls.id          # case-insensitive
    assert work.color != calls.color                       # colours rotate through the palette
    t = svc.add_task("Ring Sam", TODAY, tag_ids=[calls.id, work.id, calls.id, "nope"])
    assert t.tag_ids == [calls.id, work.id]
    assert [g.name for g in svc.match_tags("w")] == ["Work"]
    svc.update_tag(work.id, name="Job", color="#a371f7")
    assert svc.tag_by_id(work.id).name == "Job"
    svc.delete_tag(calls.id)
    assert t.tag_ids == [work.id]
    again = AppData.from_dict(svc.data.to_dict())
    assert [g.name for g in again.tags] == ["Job"] and again.tasks[0].tag_ids == [work.id]
    svc.set_task_tags(t.id, [])
    assert "tags" not in svc.data.to_dict()["tasks"][0]


# ---------------- History totals
def test_history_totals(svc, clock):
    from datetime import datetime
    def done_on(day, steps):
        clock.set(datetime(day.year, day.month, day.day, 10, tzinfo=PST))
        t = svc.add_task("t", day)
        ids = [svc.add_step(t.id, str(i)).id for i in range(steps)]
        for i in ids:
            svc.complete_step(t.id, i)
    done_on(date(2025, 12, 30), 2)   # last year
    done_on(date(2026, 3, 2), 1)     # this year
    done_on(date(2026, 11, 3), 1)    # this month
    done_on(date(2026, 11, 16), 3)   # this week (Monday)
    got = {x.label: (x.tasks, x.steps) for x in history.totals(svc.data, TODAY, "monday")}
    assert got == {"This week": (1, 3), "This month": (2, 4), "This year": (3, 5), "All time": (4, 7)}


# ---------------- background settings
def test_background_settings_cleaned():
    assert clean_background(None) == {"enabled": False, "folder": "", "interval": 15}
    assert clean_background({"enabled": 1, "folder": "D:/Pics", "interval": 7})["interval"] == 15
    d = AppData.new()
    d.settings.background = {"enabled": True, "folder": "D:/Pics", "interval": 60}
    assert AppData.from_dict(d.to_dict()).settings.background["interval"] == 60
