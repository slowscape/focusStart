"""QAbstractListModel subclasses with keyed, minimal-change sync.

sync() emits real row insert/remove/move signals (never a full reset), which is
what lets QML ListView run its add/remove/displaced transitions.
"""
from __future__ import annotations

from PySide6.QtCore import (QAbstractListModel, QByteArray, QModelIndex, Property, Qt,
                            Signal, Slot)


class KeyedListModel(QAbstractListModel):
    countChanged = Signal()

    def __init__(self, roles: list[str], parent=None):
        super().__init__(parent)
        self._roles = ["id"] + [r for r in roles if r != "id"]
        self._role_ids = {Qt.UserRole + 1 + i: r for i, r in enumerate(self._roles)}
        self._items: list[dict] = []

    # --- Qt API ---
    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self._items)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid() or not (0 <= index.row() < len(self._items)):
            return None
        name = self._role_ids.get(role)
        if name is None:
            return None
        return self._items[index.row()].get(name)

    def roleNames(self):
        # "id" can't be a QML property name, so it is exposed to delegates as "itemId".
        return {k: QByteArray(("itemId" if v == "id" else v).encode())
                for k, v in self._role_ids.items()}

    def _get_count(self):
        return len(self._items)

    count = Property(int, _get_count, notify=countChanged)

    @Slot(int, result="QVariantMap")
    def get(self, row: int):
        return dict(self._items[row]) if 0 <= row < len(self._items) else {}

    @Slot(str, result=int)
    def indexOf(self, item_id: str) -> int:
        for i, it in enumerate(self._items):
            if it["id"] == item_id:
                return i
        return -1

    def items(self) -> list[dict]:
        return list(self._items)

    # --- sync ---
    def sync(self, new_items: list[dict]) -> None:
        before = len(self._items)
        new_ids = {it["id"] for it in new_items}
        for row in range(len(self._items) - 1, -1, -1):
            if self._items[row]["id"] not in new_ids:
                self.beginRemoveRows(QModelIndex(), row, row)
                del self._items[row]
                self.endRemoveRows()
        for i, item in enumerate(new_items):
            if i < len(self._items) and self._items[i]["id"] == item["id"]:
                pass
            else:
                j = next((k for k in range(i + 1, len(self._items))
                          if self._items[k]["id"] == item["id"]), None)
                if j is not None:
                    self.beginMoveRows(QModelIndex(), j, j, QModelIndex(), i)
                    self._items.insert(i, self._items.pop(j))
                    self.endMoveRows()
                else:
                    self.beginInsertRows(QModelIndex(), i, i)
                    self._items.insert(i, dict(item))
                    self.endInsertRows()
                    continue
            if self._items[i] != item:
                self._items[i] = dict(item)
                idx = self.index(i, 0)
                self.dataChanged.emit(idx, idx)
        if len(self._items) != before:
            self.countChanged.emit()


class HistoryModel(QAbstractListModel):
    """Every completed step/task, newest first, loaded in pages as the list scrolls
    (ListView calls canFetchMore/fetchMore), so a years-long history stays fast."""
    PAGE = 60
    ROLES = ["kind", "text", "sub", "timeLabel", "section", "taskId"]
    countChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._all: list[dict] = []
        self._loaded = 0
        self._role_ids = {Qt.UserRole + 1 + i: r for i, r in enumerate(self.ROLES)}

    def reset(self, rows: list[dict]) -> None:
        self.beginResetModel()
        self._all = rows
        self._loaded = min(self.PAGE, len(rows))
        self.endResetModel()
        self.countChanged.emit()

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else self._loaded

    def canFetchMore(self, parent=QModelIndex()):
        return not parent.isValid() and self._loaded < len(self._all)

    def fetchMore(self, parent=QModelIndex()):
        if parent.isValid():
            return
        n = min(self.PAGE, len(self._all) - self._loaded)
        if n <= 0:
            return
        self.beginInsertRows(QModelIndex(), self._loaded, self._loaded + n - 1)
        self._loaded += n
        self.endInsertRows()
        self.countChanged.emit()

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid() or not (0 <= index.row() < self._loaded):
            return None
        name = self._role_ids.get(role)
        return self._all[index.row()].get(name) if name else None

    def roleNames(self):
        return {k: QByteArray(v.encode()) for k, v in self._role_ids.items()}

    count = Property(int, lambda self: self._loaded, notify=countChanged)
