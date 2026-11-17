"""Low-latency sound playback with QSoundEffect (WAV) and a small pool per sound."""
from __future__ import annotations

import logging
from pathlib import Path

from PySide6.QtCore import QObject, QTimer, QUrl

log = logging.getLogger(__name__)

try:
    from PySide6.QtMultimedia import QSoundEffect
except Exception as e:  # pragma: no cover - depends on the wheel/platform
    QSoundEffect = None
    log.error("QtMultimedia unavailable, sounds disabled: %s", e)

POOL = 2


class SoundBank(QObject):
    def __init__(self, sounds_dir: Path, parent=None):
        super().__init__(parent)
        self.dir = Path(sounds_dir)
        self._pools: dict[str, list] = {}
        self._next: dict[str, int] = {}
        self.available = QSoundEffect is not None
        if self.available:
            # Preload after the window is up so startup isn't delayed.
            QTimer.singleShot(200, self._preload)

    def _preload(self):
        for wav in sorted(self.dir.glob("*.wav")):
            self._pool(wav.stem)

    def _pool(self, name: str):
        pool = self._pools.get(name)
        if pool is None:
            path = self.dir / f"{name}.wav"
            if not path.exists():
                log.warning("missing sound %s", path)
                self._pools[name] = []
                return []
            pool = []
            for _ in range(POOL):
                fx = QSoundEffect(self)
                fx.setSource(QUrl.fromLocalFile(str(path)))
                pool.append(fx)
            self._pools[name] = pool
            self._next[name] = 0
        return pool

    def play(self, name: str, volume: float) -> None:
        if not self.available:
            return
        pool = self._pool(name)
        if not pool:
            return
        i = self._next[name]
        self._next[name] = (i + 1) % len(pool)
        fx = pool[i]
        fx.setVolume(max(0.0, min(1.0, volume)))
        fx.play()


def step_sound(variant: int, step_index: int) -> str:
    """Climb the pentatonic scale as steps in a task are completed."""
    return f"pop_{variant % 4}_{min(step_index, 7)}"


def task_sound(variant: int, first_today: bool) -> str:
    return "chord_big" if first_today else f"chord_{variant % 3}"
