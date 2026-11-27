"""Notes and the small markdown subset used by notes and by task/step notes. No Qt.

Supported, and nothing more: **bold**, *italic*, [text](url) links, a `---` line (horizontal
rule), "- "/"* " bullets and "[ ] "/"[x] " checkboxes. Text stays plain text in the data file.

Reading views split a text into blocks: checkbox lines become their own rows (tickable), runs of
other lines become one markdown block that Qt renders (Text.MarkdownText). Editing uses the raw
text; the toolbar transforms below act on (text, selection start, selection end).
"""
from __future__ import annotations

import re

CHECK_RE = re.compile(r"^(\s*)\[( |x|X)\] ?(.*)$")
BULLET_RE = re.compile(r"^(\s*)([-*]) (.*)$")
RULE_RE = re.compile(r"^\s*(-{3,}|\*{3,}|_{3,})\s*$")
LINK_RE = re.compile(r"\[([^\]]*)\]\(([^)\s]*)\)")
BOLD_RE = re.compile(r"\*\*(.+?)\*\*")
ITALIC_RE = re.compile(r"(?<![*\w])\*(?!\s)(.+?)(?<!\s)\*(?![*\w])")
SAFE_LINK = re.compile(r"^(https?://|mailto:)", re.IGNORECASE)


# ------------------------------------------------------------------ reading
def plain(text: str) -> str:
    """Inline markdown stripped: links keep their text, ** and * go."""
    text = LINK_RE.sub(lambda m: m.group(1) or m.group(2), text)
    text = BOLD_RE.sub(r"\1", text)
    return ITALIC_RE.sub(r"\1", text)


def line_text(line: str) -> str:
    """A line's words without its bullet/checkbox marker or inline markdown."""
    m = CHECK_RE.match(line) or BULLET_RE.match(line)
    if m:
        line = m.group(3)
    return "" if RULE_RE.match(line) else plain(line).strip()


def title_of(body: str) -> str:
    """A note's title: its first non-empty line, as plain words."""
    for line in body.splitlines():
        t = line_text(line)
        if t:
            return t
    return ""


def preview_of(body: str, limit: int = 160) -> str:
    """The words after the title, joined into one short line."""
    words, seen_title = [], False
    for line in body.splitlines():
        t = line_text(line)
        if not t:
            continue
        if not seen_title:
            seen_title = True
            continue
        words.append(t)
    out = "  ".join(words)
    return out if len(out) <= limit else out[: limit - 1].rstrip() + "…"


def checklist_counts(body: str) -> tuple[int, int]:
    """(ticked, total) checkbox lines."""
    done = total = 0
    for line in body.splitlines():
        m = CHECK_RE.match(line)
        if m:
            total += 1
            done += m.group(2) in "xX"
    return done, total


def matches(body: str, query: str, tag_names: list[str] | None = None) -> bool:
    q = query.strip().casefold()
    if not q:
        return True
    hay = plain(body).casefold() + " " + " ".join(tag_names or []).casefold()
    return all(part in hay for part in q.split())


BLANK = "\u00a0"   # a no-break space: markdown keeps a line holding only this, so empty lines show


def to_markdown(lines: list[str]) -> str:
    """Lines -> markdown that shows them as typed, one for one. Markdown would join single
    newlines into one paragraph and squash any number of empty lines into one gap, so:
    ordinary lines end with a hard break ("  "), and an empty line becomes a line holding only a
    no-break space (inside the same paragraph). After a bullet, a separating blank line is added
    first, so the list ends instead of the next line joining the last bullet."""
    out: list[str] = []
    prev = ""                                   # kind of the previous line: plain/blank/bullet/rule
    for i, line in enumerate(lines):
        nxt = lines[i + 1] if i + 1 < len(lines) else None
        nxt_kind = None if nxt is None else ("rule" if RULE_RE.match(nxt) else "bullet" if BULLET_RE.match(nxt)
                                             else "blank" if not nxt.strip() else "plain")
        joins = nxt_kind in ("plain", "blank")  # the next line continues this paragraph
        if RULE_RE.match(line):
            out.extend(["", "---", ""])          # a rule needs blank lines around it
            kind = "rule"
        elif BULLET_RE.match(line):
            out.append(line)
            kind = "bullet"
        elif not line.strip():
            if prev == "bullet":
                out.append("")                  # ends the list (Qt adds no gap after a list)
            out.append(BLANK + ("  " if joins else ""))
            kind = "blank"
        else:
            if prev == "bullet":
                out.append("")                  # don't let it join the last bullet
            out.append(line.rstrip() + ("  " if joins else ""))
            kind = "plain"
        prev = kind
    return "\n".join(out)


def blocks(body: str, title_first: bool = False) -> list[dict]:
    """Reading-view blocks, in order:
    {"kind": "title", "text"}                       (title_first: the first non-empty line)
    {"kind": "md", "markdown"}                       a run of ordinary lines (bullets, rules...)
    {"kind": "check", "line", "done", "markdown", "indent"}  one checkbox line (line = its index)
    Empty lines are kept (they show as empty lines), except at the very end."""
    lines = body.splitlines()
    while lines and not lines[-1].strip():
        lines.pop()
    out: list[dict] = []
    run: list[str] = []

    def flush():
        if run:
            out.append({"kind": "md", "markdown": to_markdown(run)})
        run.clear()

    titled = not title_first
    for i, line in enumerate(lines):
        if not titled:
            if line.strip():
                titled = True
                out.append({"kind": "title", "text": line_text(line) or line.strip()})
            continue
        m = CHECK_RE.match(line)
        if m:
            flush()
            out.append({"kind": "check", "line": i, "done": m.group(2) in "xX",
                        "markdown": m.group(3), "indent": len(m.group(1).expandtabs(4)) // 2})
        else:
            run.append(line)
    flush()
    return out


def toggle_check(body: str, line_index: int) -> str:
    lines = body.split("\n")
    if 0 <= line_index < len(lines):
        m = CHECK_RE.match(lines[line_index])
        if m:
            mark = " " if m.group(2) in "xX" else "x"
            lines[line_index] = f"{m.group(1)}[{mark}] {m.group(3)}"
    return "\n".join(lines)


def safe_link(url: str) -> bool:
    """Only web and mail links open from notes."""
    return bool(SAFE_LINK.match(url.strip()))


# ------------------------------------------------------------------ editing toolbar
# Each returns (new_text, new_selection_start, new_selection_end).
def wrap(text: str, start: int, end: int, marker: str) -> tuple[str, int, int]:
    """Bold (**) / italic (*): wrap the selection; with no selection insert the pair and put the
    cursor between. Wrapping an already-wrapped selection unwraps it."""
    start, end = sorted((max(0, start), min(len(text), end)))
    sel = text[start:end]
    n = len(marker)
    if sel and text[max(0, start - n):start] == marker and text[end:end + n] == marker:
        return text[:start - n] + sel + text[end + n:], start - n, end - n
    if len(sel) > 2 * n and sel.startswith(marker) and sel.endswith(marker):
        inner = sel[n:-n]
        return text[:start] + inner + text[end:], start, start + len(inner)
    new = text[:start] + marker + sel + marker + text[end:]
    return new, start + n, end + n


def insert_link(text: str, start: int, end: int, url: str, label: str = "") -> tuple[str, int, int]:
    start, end = sorted((max(0, start), min(len(text), end)))
    shown = text[start:end] or label.strip() or url.strip()
    piece = f"[{shown}]({url.strip()})"
    return text[:start] + piece + text[end:], start + len(piece), start + len(piece)


def insert_rule(text: str, pos: int) -> tuple[str, int, int]:
    """A `---` line of its own at the cursor; the cursor ends on the line after it."""
    pos = max(0, min(len(text), pos))
    piece = ("" if pos == 0 or text[pos - 1] == "\n" else "\n") + "---\n"
    return text[:pos] + piece + text[pos:], pos + len(piece), pos + len(piece)


def toggle_prefix(text: str, start: int, end: int, kind: str) -> tuple[str, int, int]:
    """kind "bullet" ("- ") or "check" ("[ ] ") on every line the selection touches: added to all,
    or removed from all when every line already has it. Indentation is kept."""
    start, end = sorted((max(0, start), min(len(text), end)))
    if end > start and text[end - 1] == "\n":   # a selection ending at a line break
        end -= 1                                  # doesn't take in the next line
    first = text.rfind("\n", 0, start) + 1
    last = text.find("\n", end)
    last = len(text) if last < 0 else last
    lines = text[first:last].split("\n")
    rx = BULLET_RE if kind == "bullet" else CHECK_RE
    mark = "- " if kind == "bullet" else "[ ] "
    has_all = all(rx.match(l) for l in lines if l.strip()) and any(l.strip() for l in lines)
    new_lines = []
    for l in lines:
        indent = l[: len(l) - len(l.lstrip())]
        body = l[len(indent):]
        if has_all:
            m = rx.match(l)
            new_lines.append(indent + (m.group(3) if m else body))
        else:
            other = CHECK_RE.match(l) if kind == "bullet" else BULLET_RE.match(l)
            if other:                       # swap a bullet for a checkbox (or back)
                body = other.group(3)
            new_lines.append(indent + mark + body if (body or len(lines) == 1) else l)
    block = "\n".join(new_lines)
    new = text[:first] + block + text[last:]
    return new, first + len(block), first + len(block)
