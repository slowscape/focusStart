"""General notes and the small markdown subset (notes and task/step notes)."""
from datetime import date

from app.core import notes as md
from app.core.models import AppData

TODAY = date(2026, 11, 16)


# ---------------- notes in the service
def test_note_crud_and_order(svc, clock):
    a = svc.add_note("Groceries\nmilk")
    clock.advance(minutes=1)
    b = svc.add_note("Ideas")
    clock.advance(minutes=1)
    svc.update_note(a.id, "Groceries\nmilk\neggs")          # edited last -> first
    assert [n.id for n in svc.notes()] == [a.id, b.id]
    svc.set_note_pinned(b.id, True)                          # pinned beats newer
    assert [n.id for n in svc.notes()] == [b.id, a.id]
    before = svc.note(a.id).updated_at
    clock.advance(minutes=1)
    svc.update_note(a.id, "Groceries\nmilk\neggs")          # no change: no new edit time
    assert svc.note(a.id).updated_at == before
    svc.delete_note(b.id)
    assert [n.id for n in svc.notes()] == [a.id]


def test_note_search_title_body_and_tags(svc):
    home = svc.add_tag("Home")
    a = svc.add_note("Garage plans\nPegboard on the **left** wall")
    b = svc.add_note("Meeting\nBudget is fine")
    svc.set_note_tags(b.id, [home.id])
    assert [n.id for n in svc.notes("pegboard left")] == [a.id]   # every word, any case, no markers
    assert [n.id for n in svc.notes("home")] == [b.id]            # tag names count
    assert svc.notes("nothing like this") == []


def test_empty_note_is_dropped_but_not_a_kept_one(svc):
    n = svc.add_note()
    assert svc.drop_note_if_empty(n.id) and svc.note(n.id) is None
    m = svc.add_note("  \n ")
    svc.set_note_pinned(m.id, True)                          # pinned on purpose: keep it
    assert not svc.drop_note_if_empty(m.id)


def test_toggle_note_check_and_tag_delete_cascade(svc):
    g = svc.add_tag("Trip")
    n = svc.add_note("Packing\n[ ] Passport\n[x] Chargers")
    svc.set_note_tags(n.id, [g.id])
    svc.toggle_note_check(n.id, 1)
    assert svc.note(n.id).body == "Packing\n[x] Passport\n[x] Chargers"
    svc.delete_tag(g.id)
    assert svc.note(n.id).tag_ids == []


def test_notes_round_trip_and_unknown_keys_kept(svc):
    n = svc.add_note("Hello\nworld")
    svc.set_note_pinned(n.id, True)
    d = svc.data.to_dict()
    d["notes"][0]["future_field"] = 42
    again = AppData.from_dict(d)
    assert again.notes[0].body == "Hello\nworld" and again.notes[0].pinned
    assert again.to_dict()["notes"][0]["future_field"] == 42
    assert AppData.from_dict({"lists": [], "tasks": []}).notes == []   # old files: no notes


# ---------------- reading helpers
def test_title_preview_counts():
    body = "**Trip** packing\n\n[x] Passport\n[ ] The *blue* jacket\n---\n- Booking: [site](https://x.y)"
    assert md.title_of(body) == "Trip packing"
    assert md.preview_of(body) == "Passport  The blue jacket  Booking: site"
    assert md.checklist_counts(body) == (1, 2)


def test_blocks_split_checks_from_markdown():
    b = md.blocks("Title\nLeave by **6:30**\nSecond line\n[ ] A\n  [x] B\n---\n- one", title_first=True)
    kinds = [x["kind"] for x in b]
    assert kinds == ["title", "md", "check", "check", "md"]
    assert b[0]["text"] == "Title"
    assert b[1]["markdown"] == "Leave by **6:30**  \nSecond line"      # hard break keeps the line
    assert (b[2]["line"], b[2]["done"], b[3]["line"], b[3]["done"], b[3]["indent"]) == (3, False, 4, True, 1)
    assert "---" in b[4]["markdown"].split("\n")
    assert [x["kind"] for x in md.blocks("Just text\n[ ] x")] == ["md", "check"]   # no title


def test_blank_lines_are_kept():
    nb = md.BLANK
    # Two empty lines between paragraphs stay two empty lines (markdown would squash them).
    assert md.to_markdown(["One", "", "", "Two"]) == f"One  \n{nb}  \n{nb}  \nTwo"
    # After a bullet, an empty line ends the list; a plain line never joins the last bullet.
    assert md.to_markdown(["- a", "", "Text"]) == f"- a\n\n{nb}  \nText"
    assert md.to_markdown(["- a", "Text"]) == "- a\n\nText"
    # Gaps between title and body, and around checkboxes, show; trailing ones don't.
    b = md.blocks("Title\n\nBody\n\n[ ] x\n\n\n", title_first=True)
    assert [x["kind"] for x in b] == ["title", "md", "check"]
    assert b[1]["markdown"] == f"{nb}  \nBody  \n{nb}"
    assert md.blocks("[ ] a\n\n[ ] b")[1] == {"kind": "md", "markdown": nb}


def test_safe_links_only():
    assert md.safe_link("https://example.com") and md.safe_link("mailto:a@b.c")
    assert not md.safe_link("file:///C:/Windows") and not md.safe_link("javascript:alert(1)")


# ---------------- editing toolbar
def test_wrap_bold_italic():
    assert md.wrap("make this bold", 5, 9, "**") == ("make **this** bold", 7, 11)
    assert md.wrap("make **this** bold", 7, 11, "**") == ("make this bold", 5, 9)   # toggles off
    assert md.wrap("ab", 1, 1, "*") == ("a**b", 2, 2)                              # empty: cursor inside


def test_insert_link_and_rule():
    assert md.insert_link("see site now", 4, 8, "https://x.y") == ("see [site](https://x.y) now", 23, 23)
    assert md.insert_link("go ", 3, 3, "https://x.y", "docs")[0] == "go [docs](https://x.y)"
    assert md.insert_rule("abc", 3) == ("abc\n---\n", 8, 8)
    assert md.insert_rule("a\nb", 2)[0] == "a\n---\nb"


def test_toggle_bullets_and_checks_over_lines():
    text = "one\ntwo\n  three"
    new, *_ = md.toggle_prefix(text, 0, len(text), "bullet")
    assert new == "- one\n- two\n  - three"
    assert md.toggle_prefix(new, 0, len(new), "bullet")[0] == text        # all had it: removed
    assert md.toggle_prefix("- one", 0, 0, "check")[0] == "[ ] one"       # bullet swapped for a box
    assert md.toggle_prefix("a\nb\nc", 2, 3, "check")[0] == "a\n[ ] b\nc"  # only the touched line
