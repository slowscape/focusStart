import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.models import AppData  # noqa: E402
from app.core.service import Service  # noqa: E402

PST = timezone(timedelta(hours=-8))


class Clock:
    def __init__(self, dt):
        self.dt = dt

    def __call__(self):
        return self.dt

    def advance(self, **kw):
        self.dt = self.dt + timedelta(**kw)

    def set(self, dt):
        self.dt = dt


@pytest.fixture
def clock():
    return Clock(datetime(2026, 11, 16, 9, 0, tzinfo=PST))


@pytest.fixture
def svc(clock):
    return Service(AppData.new(), clock)
