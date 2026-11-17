import json
import os
from datetime import date

import pytest

from app.core import store as store_mod
from app.core.models import AppData
from app.core.store import SchemaTooNewError, Store


def _data(title="x"):
    d = AppData.new()
    from app.core.service import Service
    Service(d).add_task(title)
    return d


def test_roundtrip_and_new(tmp_path):
    s = Store(tmp_path)
    r = s.load()
    assert r.is_new and r.data.lists[0].name == "Tasks"
    s.save(_data("hello"))
    r = s.load()
    assert r.data.tasks[0].title == "hello" and not r.is_new


def test_atomic_write_survives_crash(tmp_path, monkeypatch):
    s = Store(tmp_path)
    s.save(_data("good"))
    original = s.path.read_text(encoding="utf-8")

    def boom(*a, **k):
        raise OSError("simulated crash before replace")
    monkeypatch.setattr(store_mod.os, "replace", boom)
    with pytest.raises(OSError):
        s.save(_data("new"))
    assert s.path.read_text(encoding="utf-8") == original
    assert s.load().data.tasks[0].title == "good"


def test_backups_rotate_to_14(tmp_path):
    day = [date(2026, 10, 1)]
    s = Store(tmp_path, today=lambda: day[0])
    s.save(_data())
    from datetime import timedelta
    for i in range(20):
        day[0] = date(2026, 10, 2) + timedelta(days=i)
        s.save(_data(str(i)))
        s.save(_data(str(i) + "b"))  # second write same day: no new backup
    b = s.backups()
    assert len(b) == 14
    assert b[0].name == "data-2026-10-21.json"


def test_corrupt_recovers_from_backup(tmp_path):
    day = [date(2026, 11, 15)]
    s = Store(tmp_path, today=lambda: day[0])
    s.save(_data("first"))
    day[0] = date(2026, 11, 16)
    s.save(_data("second"))  # backs up "first" as 2026-11-16
    s.path.write_text("{ not json", encoding="utf-8")
    r = s.load()
    assert r.data.tasks[0].title == "first"
    assert r.notice and "backup" in r.notice
    assert list(tmp_path.glob("data.corrupt-*.json"))
    assert json.loads(s.path.read_text(encoding="utf-8"))["tasks"][0]["title"] == "first"


def test_corrupt_without_backup_keeps_file(tmp_path):
    s = Store(tmp_path)
    tmp_path.joinpath("data.json").write_text("garbage", encoding="utf-8")
    r = s.load()
    assert r.notice and list(tmp_path.glob("data.corrupt-*.json"))


def test_newer_schema_refused(tmp_path):
    s = Store(tmp_path)
    raw = {"schema_version": 99, "settings": {}, "lists": [], "tasks": []}
    s.path.write_text(json.dumps(raw), encoding="utf-8")
    with pytest.raises(SchemaTooNewError):
        s.load()
    assert json.loads(s.path.read_text())["schema_version"] == 99


def test_unknown_keys_preserved(tmp_path):
    s = Store(tmp_path)
    d = _data().to_dict()
    d["future_field"] = 1
    d["tasks"][0]["color"] = "blue"
    s.path.write_text(json.dumps(d), encoding="utf-8")
    loaded = s.load().data
    s.save(loaded)
    again = json.loads(s.path.read_text())
    assert again["future_field"] == 1 and again["tasks"][0]["color"] == "blue"
