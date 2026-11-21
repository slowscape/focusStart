from datetime import date, datetime, timedelta

from app.core import history
from app.core.models import AppData
from app.core.pomodoro import Pomodoro, clean_settings
from app.core.service import Service
from tests.conftest import PST

TODAY = date(2026, 11, 16)


# ---------------- pomodoro
def test_pomodoro_cycle_and_long_break():
    p = Pomodoro(work=25, short=5, long=15, long_every=4)
    p.start(0)
    t = 0.0
    seen = []
    for _ in range(8):
        if p.waiting:
            p.resume(t)
        t += p.remaining(t)
        seen += p.tick(t)
    assert seen == ["short", "work", "short", "work", "short", "work", "long", "work"]


def test_pomodoro_waits_for_start_after_break():
    p = Pomodoro(work=25, short=5)
    p.start(0)
    assert p.tick(25 * 60) == ["short"] and not p.paused        # focus -> break: automatic
    assert p.tick(25 * 60 + 5 * 60 + 600) == ["work"]           # back 10 min late
    assert p.waiting and p.paused and p.remaining(99_999) == 25 * 60
    assert p.tick(99_999) == []                                 # nothing passes while waiting
    p.resume(100_000)
    assert not p.waiting and p.remaining(100_060) == 24 * 60


def test_pomodoro_pause_resume_and_live_change():
    p = Pomodoro()
    p.start(0)
    p.pause(60)
    assert p.remaining(600) == 24 * 60          # paused: time doesn't pass
    p.resume(600)
    assert p.remaining(660) == 23 * 60
    # Shorten focus to 2 minutes while 2 minutes in: phase ends right away.
    assert p.set_minutes("work", 2, 660) == ["short"]
    assert p.phase == "short" and p.remaining(660) == 5 * 60


def test_pomodoro_lengthen_live_keeps_elapsed():
    p = Pomodoro()
    p.start(0)
    p.set_minutes("work", 30, 600)
    assert p.remaining(600) == 20 * 60


def test_pomodoro_stop():
    p = Pomodoro()
    p.start(0)
    p.stop()
    assert not p.running and p.tick(10_000) == []


def test_pomodoro_settings_clamped():
    s = clean_settings({"work": 0, "short": "x", "long": 999, "enabled": False})
    assert s == {"enabled": False, "work": 1, "short": 5, "long": 120, "long_every": 4, "notch": False}


def test_pomodoro_settings_roundtrip():
    d = AppData.new()
    d.settings.pomodoro["work"] = 40
    again = AppData.from_dict(d.to_dict())
    assert again.settings.pomodoro["work"] == 40


# ---------------- lists: slash command support
def test_list_matching_case_insensitive_but_case_kept(svc):
    home = svc.add_list("Home Projects")
    assert svc.find_list("home projects").id == home.id
    assert [l.name for l in svc.match_lists("PRO")] == ["Home Projects"]
    assert [l.name for l in svc.match_lists("ho")][0] == "Home Projects"
    new = svc.ensure_list("WorkStuff")
    assert new.name == "WorkStuff"
    assert svc.ensure_list("workstuff").id == new.id
    assert len(svc.data.lists) == 3


# ---------------- completed disclosure + skip specific step
def test_completed_open_persists(svc):
    t = svc.add_task("t", TODAY)
    assert not t.completed_open
    svc.set_completed_open(t.id, True)
    again = AppData.from_dict(svc.data.to_dict())
    assert again.tasks[0].completed_open
    svc.set_completed_open(t.id, False)
    assert "completed_open" not in svc.data.to_dict()["tasks"][0]


# ---------------- history
def test_history_newest_first(svc, clock):
    t = svc.add_task("Trip", TODAY)
    a = svc.add_step(t.id, "Pick dates")
    b = svc.add_step(t.id, "Book")
    svc.complete_step(t.id, a.id)
    clock.advance(minutes=5)
    svc.complete_step(t.id, b.id)   # completes the task too, same timestamp
    ev = history.events(svc.data)
    assert [(e.kind, e.text) for e in ev] == [("task", "Trip"), ("step", "Book"), ("step", "Pick dates")]
    assert ev[0].list_name == "Tasks"


def test_history_labels():
    assert history.day_label(TODAY, TODAY) == "Today"
    assert history.day_label(TODAY - timedelta(days=1), TODAY) == "Yesterday"
    assert history.day_label(date(2025, 3, 2), TODAY) == "Sunday, March 2, 2025"
    assert history.time_label(datetime(2026, 1, 1, 0, 5)) == "12:05 AM"
    assert history.time_label(datetime(2026, 1, 1, 13, 30)) == "1:30 PM"


def test_pomodoro_limits_per_phase():
    from app.core.pomodoro import LIMITS, clamp
    s = clean_settings({"work": 200, "short": 90, "long": 150})
    assert (s["work"], s["short"], s["long"]) == (180, 60, 120)
    assert clamp("short", 90) == LIMITS["short"][1] == 60
    assert clamp("long", 45) == 45 and clamp("work", 0) == 1


# ---------------- delete from history
def test_delete_completed_task_needs_flag_and_leaves_history(svc):
    import pytest
    t = svc.add_task("Trip", TODAY)
    s = svc.add_step(t.id, "Book")
    svc.update_task(t.id, notes="flight 7am")
    svc.complete_step(t.id, s.id)
    keep = svc.add_task("Other", TODAY)
    svc.complete_task(keep.id)
    assert svc.task(t.id).notes == "flight 7am"      # notes stay on a finished task
    with pytest.raises(ValueError):
        svc.delete_task(t.id)
    svc.delete_task(t.id, include_completed=True)
    assert svc.task(t.id) is None
    assert [e.text for e in history.events(svc.data)] == ["Other"]
    assert svc.progress().tasks_done == 1 and svc.progress().steps_done == 0


def test_task_pomodoro_switch_persists(svc):
    t = svc.add_task("t", TODAY)
    assert t.pomodoro_on
    svc.set_task_pomodoro(t.id, False)
    again = AppData.from_dict(svc.data.to_dict())
    assert not again.tasks[0].pomodoro_on
    svc.set_task_pomodoro(t.id, True)
    assert "pomodoro_off" not in svc.data.to_dict()["tasks"][0]


# ---------------- print / PDF
def test_print_includes_open_tasks_and_remaining_steps_only(svc):
    from app.core import printout
    t = svc.add_task("Trip", TODAY)
    a = svc.add_step(t.id, "Dates")
    svc.add_step(t.id, "Book")
    svc.complete_step(t.id, a.id)
    plain = svc.add_task("Call dentist", TODAY)
    done = svc.add_task("Done one", TODAY)
    svc.complete_task(done.id)
    items = printout.from_tasks(svc.data.tasks)
    assert [(i.title, i.steps) for i in items] == [("Trip", ["Book"]), ("Call dentist", [])]


def test_print_filename_is_windows_safe():
    from app.core import printout
    assert printout.filename("My Day", "2026-11-17") == "My Day 2026-11-17.pdf"
    assert printout.filename('Home/Work: "A"?', "2026-11-17") == "HomeWork A 2026-11-17.pdf"


def test_pomodoro_notch_setting():
    assert clean_settings(None)["notch"] is False
    assert clean_settings({"notch": True})["notch"] is True
    assert clean_settings({"notch": "yes"})["notch"] is False   # only real booleans count
    assert clean_settings({"notch": 1})["notch"] is False


def test_notch_dock_setting_cleaned():
    s = clean_settings({"notch_dock": {"edge": "bottom", "x": 1.7}})
    assert s["notch_dock"] == {"edge": "bottom", "x": 1.0}          # clamped to the screen
    assert "notch_dock" not in clean_settings({"notch_dock": {"edge": "left", "x": 0.2}})
    assert "notch_dock" not in clean_settings({"notch_dock": [10, 20]})
