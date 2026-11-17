import copy
from datetime import date, datetime, timedelta

import pytest

from app.core.models import AppData
from app.core.service import Service
from tests.conftest import PST


def test_first_run_has_one_list():
    d = AppData.new()
    assert [l.name for l in d.lists] == ["Tasks"]


def test_rollover(svc, clock):
    y = svc.add_task("from yesterday", date(2026, 11, 15))
    t = svc.add_task("today", date(2026, 11, 16))
    tm = svc.add_task("tomorrow", date(2026, 11, 17))
    none = svc.add_task("someday", None)
    ids = [x.id for x in svc.my_day()]
    assert y.id in ids and t.id in ids
    assert tm.id not in ids and none.id not in ids
    assert [x.id for x in svc.upcoming()] == [tm.id]
    clock.advance(days=1)
    assert tm.id in [x.id for x in svc.my_day()]


def test_step_completion_and_undo_restore_exact_state(svc):
    t = svc.add_task("t", date(2026, 11, 16))
    a = svc.add_step(t.id, "a")
    b = svc.add_step(t.id, "b")
    before = copy.deepcopy(svc.data.to_dict())
    c = svc.complete_step(t.id, a.id)
    assert not c.task_completed and c.step_index == 0
    assert svc.undo(c.token).ok
    after = svc.data.to_dict()
    before["settings"].pop("day_progress"); after["settings"].pop("day_progress")
    assert before == after


def test_last_step_completes_task_and_undo_reopens(svc):
    t = svc.add_task("t", date(2026, 11, 16))
    a = svc.add_step(t.id, "a")
    b = svc.add_step(t.id, "b")
    svc.complete_step(t.id, a.id)
    c = svc.complete_step(t.id, b.id)
    assert c.task_completed and t.done and c.step_index == 1
    r = svc.undo(c.token)
    assert r.ok and r.task_reopened and not t.done
    assert [s.id for s in t.remaining_steps] == [b.id]


def test_undo_older_token_does_not_clobber_later_work(svc):
    t = svc.add_task("t", date(2026, 11, 16))
    a, b, c = (svc.add_step(t.id, x) for x in "abc")
    ca = svc.complete_step(t.id, a.id)
    svc.complete_step(t.id, b.id)
    svc.undo(ca.token)
    assert not a.done and b.done


def _order(t):
    return [x.text for x in t.steps_in_order]


def test_move_step_keeps_done_steps_in_place(svc):
    t = svc.add_task("t", date(2026, 11, 16))
    a, b, c, d = (svc.add_step(t.id, x) for x in "abcd")
    svc.complete_step(t.id, b.id)
    svc.move_step(t.id, d.id, 0)                 # d first among remaining
    assert _order(t) == ["d", "b", "a", "c"]     # b (done) still 2nd
    assert [x.text for x in t.remaining_steps] == ["d", "a", "c"]


def test_restore_step_keeps_its_position(svc):
    t = svc.add_task("t", date(2026, 11, 16))
    a, b, c = (svc.add_step(t.id, x) for x in "abc")
    svc.complete_step(t.id, a.id)
    svc.restore_step(t.id, a.id)
    assert _order(t) == ["a", "b", "c"]


def test_manual_complete_does_not_complete_steps(svc):
    t = svc.add_task("t", date(2026, 11, 16))
    svc.add_step(t.id, "a")
    svc.complete_task(t.id)
    assert t.done and not any(s.done for s in t.steps)


def test_next_task_after_wraps(svc):
    a = svc.add_task("a", date(2026, 11, 16))
    b = svc.add_task("b", date(2026, 11, 16))
    c = svc.add_task("c", date(2026, 11, 16))
    assert svc.next_task_after(a.id).id == b.id
    assert svc.next_task_after(c.id).id == a.id
    svc.complete_task(b.id)
    assert svc.next_task_after(b.id).id == c.id


def test_delete_rules(svc):
    t = svc.add_task("t", date(2026, 11, 16))
    svc.complete_task(t.id)
    with pytest.raises(ValueError):
        svc.delete_task(t.id)
    u = svc.add_task("u")
    svc.delete_task(u.id)
    assert svc.task(u.id) is None


def test_delete_list_moves_tasks(svc):
    home = svc.add_list("Home")
    t = svc.add_task("t", None, home.id)
    with pytest.raises(ValueError):
        svc.delete_list(home.id)
    svc.delete_list(home.id, svc.default_list_id())
    assert t.list_id == svc.default_list_id()
    with pytest.raises(ValueError):
        svc.delete_list(svc.default_list_id())


def test_move_step(svc):
    t = svc.add_task("t", date(2026, 11, 16))
    a, b, c = (svc.add_step(t.id, x) for x in "abc")
    svc.move_step(t.id, c.id, 0)
    assert [s.text for s in t.remaining_steps] == ["c", "a", "b"]
    svc.move_step(t.id, c.id, 2)
    assert [s.text for s in t.remaining_steps] == ["a", "b", "c"]


def test_restore_step_reopens_task(svc):
    t = svc.add_task("t", date(2026, 11, 16))
    a = svc.add_step(t.id, "a")
    svc.complete_step(t.id, a.id)
    assert t.done
    svc.restore_step(t.id, a.id)
    assert not t.done and not a.done
