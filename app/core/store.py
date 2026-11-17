"""Load/save the JSON data file. No Qt imports.

- Atomic write: data.json.tmp -> flush -> fsync -> os.replace.
- Daily backup before the first write of each day; newest 14 kept.
- Corrupt file: keep it aside, recover from the newest readable backup.
- Refuses to load (and therefore to overwrite) a newer schema version.
"""
from __future__ import annotations

import json
import logging
import os
import re
import shutil
import time
from dataclasses import dataclass
from datetime import date, datetime
from pathlib import Path
from typing import Callable

from .models import SCHEMA_VERSION, AppData

log = logging.getLogger(__name__)

BACKUP_KEEP = 14
_BACKUP_RE = re.compile(r"^data-(\d{4}-\d{2}-\d{2})\.json$")


class SchemaTooNewError(Exception):
    """The data file was written by a newer version of the app."""


@dataclass
class LoadResult:
    data: AppData
    notice: str | None = None
    is_new: bool = False


class Store:
    def __init__(self, data_dir: Path, today: Callable[[], date] = date.today):
        self.dir = Path(data_dir)
        self.path = self.dir / "data.json"
        self.tmp_path = self.dir / "data.json.tmp"
        self.backups_dir = self.dir / "backups"
        self._today = today

    # ---------- load ----------
    def _read(self, path: Path) -> AppData:
        with open(path, "r", encoding="utf-8") as f:
            raw = json.load(f)
        if not isinstance(raw, dict):
            raise ValueError("not a JSON object")
        version = raw.get("schema_version", SCHEMA_VERSION)
        if not isinstance(version, int):
            raise ValueError("bad schema_version")
        if version > SCHEMA_VERSION:
            raise SchemaTooNewError(
                f"{path.name} uses data format v{version}; this app understands v{SCHEMA_VERSION}.")
        return AppData.from_dict(raw)

    def backups(self) -> list[Path]:
        """Backups, newest first."""
        if not self.backups_dir.is_dir():
            return []
        found = [p for p in self.backups_dir.iterdir() if _BACKUP_RE.match(p.name)]
        return sorted(found, key=lambda p: p.name, reverse=True)

    def _recover(self, reason: str) -> LoadResult | None:
        for b in self.backups():
            try:
                data = self._read(b)
            except SchemaTooNewError:
                raise
            except Exception as e:  # noqa: BLE001 - any unreadable backup: try the next
                log.warning("backup %s unreadable: %s", b.name, e)
                continue
            day = _BACKUP_RE.match(b.name).group(1)
            log.warning("recovered from %s (%s)", b.name, reason)
            self._write(data)  # make the recovered copy the live file
            return LoadResult(data, notice=f"Restored your tasks from the {day} backup.")
        return None

    def load(self) -> LoadResult:
        self.dir.mkdir(parents=True, exist_ok=True)
        if not self.path.exists():
            recovered = self._recover("data.json missing") if self.backups() else None
            if recovered:
                return recovered
            return LoadResult(AppData.new(), is_new=True)
        try:
            return LoadResult(self._read(self.path))
        except SchemaTooNewError:
            raise
        except Exception as e:  # noqa: BLE001
            log.error("data.json unreadable: %s", e)
            stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
            kept = self.dir / f"data.corrupt-{stamp}.json"
            try:
                shutil.copy2(self.path, kept)
            except OSError as ce:
                log.error("could not keep corrupt copy: %s", ce)
            recovered = self._recover(str(e))
            if recovered:
                return recovered
            # Nothing to recover from. The unreadable file is kept aside, never discarded.
            return LoadResult(AppData.new(), is_new=False,
                              notice=f"Your data file couldn't be read, so a fresh one was started. "
                                     f"The old file was kept as {kept.name}.")

    # ---------- save ----------
    def save(self, data: AppData) -> None:
        self.dir.mkdir(parents=True, exist_ok=True)
        self._daily_backup()
        self._write(data)

    def _daily_backup(self) -> None:
        if not self.path.exists():
            return
        target = self.backups_dir / f"data-{self._today().isoformat()}.json"
        if target.exists():
            return
        self.backups_dir.mkdir(parents=True, exist_ok=True)
        try:
            shutil.copy2(self.path, target)
        except OSError as e:
            log.error("backup failed: %s", e)
            return
        for old in self.backups()[BACKUP_KEEP:]:
            try:
                old.unlink()
            except OSError as e:
                log.warning("could not remove old backup %s: %s", old.name, e)

    def _write(self, data: AppData) -> None:
        payload = json.dumps(data.to_dict(), ensure_ascii=False, indent=1)
        with open(self.tmp_path, "w", encoding="utf-8", newline="\n") as f:
            f.write(payload)
            f.flush()
            os.fsync(f.fileno())
        # On Windows, antivirus/OneDrive can hold the target briefly; retry.
        for attempt in range(6):
            try:
                os.replace(self.tmp_path, self.path)
                return
            except PermissionError:
                if attempt == 5:
                    raise
                time.sleep(0.05 * (attempt + 1))
