from datetime import date, datetime

from app.core import progress
from app.core.models import AppData
from app.core.service import Service
from tests.conftest import PST

TODAY = date(2026, 11, 16)


def test_units_mixed_and_rolled_over(svc, clock):
    # rolled-over task with a step done on an earlier day
    clock.set(datetime(2026, 11, 15, 9, tzinfo=PST))
    old = svc.add_task("old", date(2026, 11, 15))
    o1 = svc.add_step(old.id, "o1"); svc.add_step(old.id, "o2")
    svc.complete_step(old.id, o1.id)  # yesterday: must not count today
    clock.set(datetime(2026, 11, 16, 9, tzinfo=PST))
    plain = svc.add_task("plain", TODAY)  # step-less: 1 unit
    st = svc.add_task("steps", TODAY)
    s1 = svc.add_step(st.id, "s1"); svc.add_step(st.id, "s2")
    p = svc.progress()
    assert (p.done, p.remaining, p.total) == (0, 4, 4)
    svc.complete_step(st.id, s1.id)
    svc.complete_task(plain.id)
    p = svc.progress()
    assert (p.done, p.remaining, p.total) == (2, 2, 4)


def test_dropped_steps_leave_total(svc):
    t = svc.add_task("t", TODAY)
    a = svc.add_step(t.id, "a"); svc.add_step(t.id, "b"); svc.add_step(t.id, "c")
    svc.complete_step(t.id, a.id)
    svc.complete_task(t.id)  # b, c dropped
    p = svc.progress()
    assert (p.done, p.remaining, p.total) == (1, 0, 1)
    u = svc.add_task("u", TODAY)
    x = svc.add_step(u.id, "x")
    svc.delete_step(u.id, x.id)
    assert svc.progress().total == 2  # u is now step-less: 1 unit


def test_ratchet_never_decreases_when_scope_grows(svc):
    t = svc.add_task("t", TODAY)
    steps = [svc.add_step(t.id, str(i)) for i in range(4)]
    seen = [svc.progress().displayed]
    svc.complete_step(t.id, steps[0].id); seen.append(svc.progress().displayed)
    svc.complete_step(t.id, steps[1].id); seen.append(svc.progress().displayed)
    for i in range(5):
        svc.add_step(t.id, f"more{i}"); seen.append(svc.progress().displayed)
    u = svc.add_task("u", TODAY); seen.append(svc.progress().displayed)
    svc.complete_step(t.id, steps[2].id); seen.append(svc.progress().displayed)
    assert all(b >= a for a, b in zip(seen, seen[1:])), seen
    assert seen[-1] == 0.5  # held at floor
    assert svc.progress().displayed < 1.0


def test_ratchet_reaches_full_only_when_remaining_zero(svc):
    t = svc.add_task("t", TODAY)
    a = svc.add_step(t.id, "a"); b = svc.add_step(t.id, "b")
    svc.complete_step(t.id, a.id)
    assert svc.progress().displayed < 1
    svc.complete_step(t.id, b.id)
    p = svc.progress()
    assert p.remaining == 0 and p.displayed == 1.0
    svc.add_task("more", TODAY)
    p = svc.progress()
    assert p.remaining == 1 and p.displayed < 1.0
    assert p.displayed == progress.NEAR_FULL


def test_floor_resets_on_new_date_and_survives_restart(svc, clock):
    t = svc.add_task("t", TODAY)
    a = svc.add_step(t.id, "a"); svc.add_step(t.id, "b")
    svc.complete_step(t.id, a.id)
    svc.add_step(t.id, "c")
    assert svc.progress().displayed == 0.5
    # restart: reload from dict
    data2 = AppData.from_dict(svc.data.to_dict())
    svc2 = Service(data2, clock)
    assert svc2.progress().displayed == 0.5
    clock.advance(days=1)
    p = svc2.progress()
    assert p.done == 0 and p.displayed == 0.0
    assert svc2.data.settings.day_progress["date"] == "2026-11-17"


def test_empty_day():
    p = progress.compute(AppData.new(), TODAY)
    assert p.total == 0 and p.displayed == 0.0


def test_day_complete_fires_once(svc):
    t = svc.add_task("t", TODAY)
    a = svc.add_step(t.id, "a")
    c = svc.complete_step(t.id, a.id)
    assert c.day_complete and "2026-11-16" in svc.data.settings.days_completed
    u = svc.add_task("u", TODAY)
    c2 = svc.complete_task(u.id)
    assert not c2.day_complete and c2.all_clear_again


def test_empty_day_never_fires(svc):
    t = svc.add_task("someday", None)  # not in My Day
    c = svc.complete_task(t.id)
    assert not c.day_complete and not c.all_clear_again


def test_undo_final_completion_clears_day(svc):
    t = svc.add_task("t", TODAY)
    a = svc.add_step(t.id, "a"); b = svc.add_step(t.id, "b")
    svc.complete_step(t.id, a.id)
    c = svc.complete_step(t.id, b.id)
    assert c.day_complete
    r = svc.undo(c.token)
    assert r.day_complete_revoked
    assert "2026-11-16" not in svc.data.settings.days_completed
    p = svc.progress()
    assert p.remaining == 1 and p.displayed < 1.0
    c3 = svc.complete_step(t.id, b.id)
    assert c3.day_complete  # can fire again after undo


def test_undo_restores_floor(svc):
    t = svc.add_task("t", TODAY)
    a, b, c, d = (svc.add_step(t.id, x) for x in "abcd")
    svc.complete_step(t.id, a.id)
    cb = svc.complete_step(t.id, b.id)
    assert svc.progress().displayed == 0.5
    svc.undo(cb.token)
    assert svc.progress().displayed == 0.25
