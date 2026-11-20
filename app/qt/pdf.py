"""Draw a printable checklist to PDF with Qt's own PDF writer (no extra installs).

Drawn with QPainter (not rich text) so checkboxes are real squares, text wraps beside
them, and rows never split across pages.
"""
from __future__ import annotations

from PySide6.QtCore import QLocale, QMarginsF, QRectF, Qt
from PySide6.QtGui import (QColor, QFont, QFontDatabase, QFontMetricsF, QPageLayout, QPageSize, QPainter,
                           QPdfWriter, QPen)

from ..core.printout import BODY_PT, HEADING_PT, SUB_PT, PrintTask

INK = QColor("#1a1a1a")
GREY = QColor("#6b6b6b")


def write_pdf(path: str, heading: str, subheading: str, tasks: list[PrintTask]) -> None:
    writer = QPdfWriter(path)
    us = QLocale().measurementSystem() == QLocale.MeasurementSystem.ImperialUSSystem
    writer.setPageSize(QPageSize(QPageSize.PageSizeId.Letter if us else QPageSize.PageSizeId.A4))
    writer.setPageMargins(QMarginsF(18, 16, 18, 16), QPageLayout.Unit.Millimeter)
    writer.setResolution(300)
    writer.setTitle(heading)
    writer.setCreator("StepTask")

    pt = writer.resolution() / 72.0          # device pixels per point
    width, height = writer.width(), writer.height()

    def font(size, weight=QFont.Weight.Normal):
        f = QFont(QFontDatabase.systemFont(QFontDatabase.SystemFont.GeneralFont).family())
        f.setPointSizeF(size)
        f.setWeight(weight)
        return f

    f_head = font(HEADING_PT, QFont.Weight.DemiBold)
    f_sub = font(SUB_PT)
    f_task = font(BODY_PT, QFont.Weight.DemiBold)
    f_step = font(BODY_PT)

    p = QPainter(writer)
    p.setRenderHint(QPainter.RenderHint.Antialiasing)
    y = 0.0

    def text_height(f, w, text):
        fm = QFontMetricsF(f, writer)
        return fm.boundingRect(QRectF(0, 0, w, 1e7), Qt.TextFlag.TextWordWrap, text).height()

    def draw_text(f, color, x, w, text):
        h = text_height(f, w, text)
        p.setFont(f)
        p.setPen(color)
        p.drawText(QRectF(x, y, w, h), Qt.TextFlag.TextWordWrap, text)
        return h

    def fits(h):
        nonlocal y
        if y + h > height and y > 0:
            writer.newPage()
            y = 0.0

    # header
    y += draw_text(f_head, INK, 0, width, heading)
    y += draw_text(f_sub, GREY, 0, width, subheading) + 14 * pt

    box = 13 * pt                            # checkbox side, sized for 18 pt text
    gap = 10 * pt                            # box to text
    indent = 30 * pt                         # steps sit under the task text
    pen = QPen(INK)
    pen.setWidthF(1.3 * pt)

    def row(f, x, text):
        nonlocal y
        tx = x + box + gap
        h = text_height(f, width - tx, text)
        fits(h)
        line = QFontMetricsF(f, writer).height()
        p.setPen(pen)
        p.setBrush(Qt.BrushStyle.NoBrush)
        p.drawRoundedRect(QRectF(x, y + (line - box) / 2, box, box), 2 * pt, 2 * pt)
        draw_text(f, INK, tx, width - tx, text)
        y += h + 5 * pt

    if not tasks:
        draw_text(f_step, GREY, 0, width, "Nothing here right now.")
    for t in tasks:
        # keep a task title with its first step when the page is nearly full
        first = text_height(f_task, width, t.title) + (text_height(f_step, width, t.steps[0]) if t.steps else 0)
        fits(first)
        row(f_task, 0, t.title)
        for s in t.steps:
            row(f_step, indent, s)
        y += 10 * pt
    p.end()
