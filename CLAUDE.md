# StepTask (formerly FocusStart): notes for Claude Code

Local-only to-do app for ADHD task initiation (Windows; macOS/Linux experimental on branch
`mac-fluent-icons`). Python 3.12 + PySide6 (QML, FluentWinUI3 style).
`SPEC.md` is the original brief. Where this file and SPEC.md disagree, this file wins:
the owner changed several things after trying the app (listed under "Decisions").

## Run and test
- Run: `launch.bat` on Windows, `launch.sh` / `launch.command` (double-click) on macOS/Linux (creates `.venv`, installs `requirements.txt`, starts `pythonw -m app`).
  With a console and logs: `.venv\Scripts\python -m app`. Data: `%APPDATA%\StepTask\` (`app.log` there;
  a legacy `%APPDATA%\FocusStart` folder is renamed to it on first run, see `main.default_data_dir`).
- Tests (core only, no Qt): `.venv\Scripts\python -m pip install -r requirements-dev.txt`, then `.venv\Scripts\python -m pytest`.
- After any QML change, run the app and check `app.log` for QML warnings (binding loops, null refs).
- Scripted screenshots: set `QSG_RENDER_LOOP=basic`. With the default threaded loop, animations don't
  advance while the display is off/locked, so fades, the tab underline and toasts look stuck.

## Architecture
- `app/core/`: pure Python, no Qt. All mutations go through `service.py`. `models.py` keeps unknown
  JSON keys in `extra` (forward compatibility). `store.py`: atomic writes, daily backups (14 kept),
  corrupt-file recovery, refuses newer `schema_version`. `progress.py`: today's done/remaining units (badges, Day complete).
  `history.py`, `pomodoro.py` (pure timer logic, time passed in), `printout.py` (what goes on a
  printed checklist; `qt/pdf.py` draws it with QPainter + QPdfWriter, no extra installs).
- `app/qt/`: thin bridge. `backend.py` is the QObject exposed to QML as `backend`. `models.py`:
  `KeyedListModel.sync()` emits real insert/remove/move rows (never resets; ListView transitions need
  that). `HistoryModel` pages rows via canFetchMore/fetchMore.
- `app/qml/`: `Main.qml` (navigation via a Loader; `appWindow` id is used by screens),
  `screens/`, `components/`, `theme/Theme.qml` (singleton: spacing, colours, motion, icon glyphs).

## Hard-won gotchas (do not regress)
- **PySide6 must stay below 6.10** (`requirements.txt`). From 6.10, Qt6Core imports `ucnv_open` from
  Windows' `icuuc.dll`; on the owner's work PC that fails ("procedure entry point ucnv_open could not
  be located"). 6.9.x has no ICU import. Use `PySide6-Essentials` + `PySide6-Addons`, not the `PySide6`
  meta-package (it drags in WebEngine/Pdf, ~135 MB).
- The work PC allows no installers. Only pip into `.venv`.
- **Never animate a whole page's opacity** (it reads as the window flashing). Inside an animation,
  `target: parent` resolves to the page, not the item. Name targets explicitly.
- **Don't combine a `displaced` transition with rows that collapse their own height** on remove
  (`ListView.delayRemove`): rows jump behind the header, then drop. Lists using delayRemove collapse
  have no `displaced` transition on purpose.
- Particles: `ImageParticle` colours can't change at runtime, and each painter's first burst is
  uncoloured, so painters are fixed per colour family and primed off-screen at startup. The particle
  system is `paused` while idle. Qt's software renderer (VMs, Remote Desktop) can't draw particles,
  so `Main.qml` falls back to `FallbackEffects.qml` when `GraphicsInfo.api` is Software.
- FluentWinUI3 adds its own Popup padding/insets. Set them all explicitly or content gets squeezed.
- Fluent `TextArea`/`TabButton` have style minimum sizes. `StepInput` overrides `implicitHeight`; tab
  widths derive from `appWindow.width` (deriving them from the TabBar caused a binding loop).
  The four tab widths must sum to <= the TabBar's availableWidth (`appWindow.tabSpace` subtracts its
  4+4 px padding); otherwise the bar scrolls a few px per selected tab and the tabs shift on switch.
- Avoid `Drawer`, `StackView`, `SplitView`, `SwipeView` (Fluent falls back to Fusion). The Lists side
  panel is a custom slide-out.
- Text fields must not save only on blur: `IconButton` is TabFocus and Done/Skip are NoFocus, so
  Back/Skip task destroy or retarget a still-focused field. `NotesArea.qml` debounces saves, saves
  to the task the text belongs to, and flushes on destruction and on `appWindow.flushEdits()` (window close).
- Header rows must fit 320 px: a RowLayout wider than the window pushes the whole page past the
  right edge (cards cut off). My Day's Done badges are compact Chips in a shrinkable right-to-left
  `Flow` between the title and Print, so they stack instead of widening the row.
- Tab buttons are `focusPolicy: Qt.NoFocus`: closing a Menu by clicking a tab left Fluent's white
  focus ring on it.
- Drag and drop uses `ReorderArea.qml` (a MouseArea with preventStealing over a title/step text):
  click = click, drag past 6 px = reorder. Delegates bind `transform: Translate { y: area.offset }`;
  the ListView exposes `property Item dropLine` for the accent drop line. Don't use DragHandler on
  cards: the ListView (a Flickable) steals the drag. `reorder_tasks(ids)` re-deals the order slots
  the given tasks already hold, so other views keep their order.
- `NotesArea` pins its TextArea to `availableWidth` (contentWidth too): otherwise the ScrollView
  can size from the first layout and clip notes on the right until the window is resized.
- Empty states bind to the *model's* `count` (e.g. `backend.myDayModel.count`): it changes at once,
  while the ListView's count waits for the delayRemove fade-outs to finish.
- Icons: bundled `app/assets/fonts/StepTaskIcons.ttf` (Fluent UI System Icons, MIT, 20 px regular),
  only the glyphs in `tools/subset_icons.py` ICONS. Adding an icon = add it there, rerun the tool,
  paste the printed table into `Theme.glyphs`. Don't rely on Windows' Segoe Fluent Icons.
- `launch.sh`/`launch.command` must keep LF line endings (`.gitattributes`) and the git executable bit.
- `main.pick_style` falls back to Fusion if this PySide6 build lacks FluentWinUI3, so the window still
  opens. Data folder per OS in `main.data_base_dir` (macOS Application Support, Linux XDG).
- Esc: Main's Esc shortcut is enabled only off tab screens, so screen-level Esc shortcuts never clash
  (two enabled shortcuts with the same key both stop working).

## Decisions made with the owner (differ from SPEC.md)
- Completed steps roll up into a per-task "Completed (N)" section in My Day. Its open/closed state
  persists per task (`extra.completed_open`); new tasks start closed. Clicking a done check restores it.
- **Done steps never move.** Step `order` is positional. `move_step` re-deals remaining steps into the
  slots they already hold; `restore_step` keeps position. There is no `skip_step`: in Focus, Skip and
  Left/Right just change the selected step, cycling through to-do steps only.
- Focus step bar: one segment per step in order; the current step is taller (no colour change);
  green = done, grey = to-do. Done steps are clickable (view only + "Mark not done").
- No Backspace-deletes-last-step on the plan page (holding Backspace deleted steps).
- Plan page prompt is static: "List actionable steps".
- Steps edit in wrapping fields; drag the grip to reorder (Alt+Up/Down while editing).
- Quick-add `/list`: case-insensitive match; a new name becomes a list exactly as typed; chip is sticky.
  The list chip has its own row above the field; the field row is pinned to the bottom and never
  moves or narrows (QuickAdd grows upward). Screens expose `bottomInset` so toasts sit above it.
- Quick-add dates: with a task typed, Tomorrow / the calendar (My Day) or a day menu pick (Upcoming)
  adds it for that date at once (one-off, `submit(when)`); with an empty field they set the sticky date.
- Pomodoro: 25/5/15, long break every 4; starts from a Start arrow. Focus -> break advances on its
  own with one soft chime. When a break ends, a full-window prompt (`BreakOverOverlay`, via the
  `breakOver` signal) asks "Continue <task> <step>?": Continue reopens Focus and resumes; End Task
  stops the timer and goes to My Day. The bar's square stop button stops and resets (`pomoStop`).
  Turning the timer off is only in Settings (hidden everywhere) or Edit task (`extra.pomodoro_off`).
- The bottom day-progress bar was removed (owner didn't like it). `core/progress.py` still computes
  done/remaining for the badges and the once-a-day "Day complete" celebration; its ratchet "floor"
  no longer drives any UI.
- Focus layout: the step text area has a fixed height (long text shrinks to fit); notes fill the
  middle; the action row and Done are pinned to the bottom so nothing shifts under the cursor.
- My Day shows "N Steps Done" and "N Tasks Done" badges. History tab lists every completion.
- History rows open their task. A finished task shows read-only (notes, completed steps) with
  "Delete from history" (confirmed; `delete_task(..., include_completed=True)`). No bulk clear.
- Notes: each step has its own notes (`Step.notes`, written only when non-empty); Focus shows the
  current step's "Step Notes" (fills the middle) and the smaller "Task Notes" below. Step-less tasks
  have task notes only. The finished-task page lists completed steps with their notes.
- No truncation of task or step text anywhere (cards grow; the editor title wraps). Only the Focus
  step text shrinks to fit its fixed area.
- Cards (My Day, Lists): click the title or a step to edit its words in place (`InlineText`); drag
  them to reorder; click the card's edge/empty space or its progress ring to open Focus without the
  timer; the play arrow opens Focus and starts it. "+ Step" (right, greyed) adds steps in the card,
  on the same line as "Completed (N)" (left). Focus: click the title or the big step text to edit.
  My Day's Done pills open History.
- Lists tab uses the same TaskCard as My Day. Its quick-add has Tomorrow/calendar (default: no date)
  and no "/" list command (always the shown list). Upcoming ends with a "No date" section.
- Drag and drop: My Day and list cards, steps inside cards, lists in the Lists panel, Upcoming rows
  (dropping among another day's tasks changes the date; "No date" clears it). Not tabs, not History.
- Tags: `AppData.tags` (id, name, colour from `TAG_COLORS`, no red); tasks hold `extra.tags`.
  Managed in Settings (rename, colour, delete). "#name" in quick-add picks/creates (sticky chips).
  Coloured dots sit inline just before the title text (styled-text prefix, so they line up).
- Repeat (Edit task): Daily / Weekdays / Weekly / Monthly in `extra.repeat`. Completing the task plans
  a fresh copy (steps unchecked, notes and tags kept) via `dates.next_occurrence`; undo removes it.
- Pomodoro is owned by the task whose Start began it; when that task completes the timer stops and
  the top strip goes away.
- History shows totals: this week, month, year, all time (`history.totals`).
- Background: Settings > Background picks a folder; shown on My Day only, true colours (no wash),
  cropped to fill, 0.1 s crossfade; rotates every 5/15/60 min or daily (deterministic by time).
- Cards are solid (`Theme.card`) everywhere; only My Day's are very slightly see-through
  (`Theme.cardSoft`, ListView `softCards`) and turn solid on hover (never darker).
- "All clear": the app ring with all three segments green over a green breathing halo.
- Tab switches slide the header and list only (`enterOffset` on My Day/Upcoming/Lists); the bottom
  add bar stays still. Upcoming rows show the task's list next to "N of M steps left".
- **No morning recap** (removed with its logic; old `last_recap_date`/`recap_history` keys sit in `extra`).
- App icon (`tools/generate_images.py`): the My Day progress ring, 3 segments, 2 green, on a dark disc.
- Focus primary button: "Step Complete" ("Task Complete" on a step-less task).
- Print: My Day header print icon, Lists "..." menu. Saves a checklist PDF (18 pt, empty checkbox per
  task and remaining step) via a save dialog (default Documents), then opens it in the PDF viewer.
- Pomodoro limits live in `core/pomodoro.LIMITS` (Focus 180, Short 60, Long 120); UI uses the same.
- Renamed FocusStart -> **StepTask** (window title, messages, PDF). The GitHub repo/folder keep the old
  name. `main.default_data_dir` renames a legacy `FocusStart` data folder on first run (falls back to it
  if the rename fails, e.g. the old app is open).
- Break-over prompt shows the task's own step ring and "N of M steps done" (none for step-less tasks).
- Notes auto-bullets: a line starting "- " or "* " (any indent) continues on Enter; Enter on an empty
  bullet ends the list; Shift+Enter is a plain newline (`NotesArea` Keys.onPressed).
- Undo toast: 3 s (paused on hover); clicking it dismisses it; Undo still works.
- Settings > Appearance: System / Light / Dark (`settings.appearance`), applied via
  `QStyleHints.setColorScheme` (Qt 6.8+); the Fluent style and palette follow live.
- Positive-only guardrails from SPEC.md section 9 still apply (no streaks, overdue, red, guilt copy).

## Open issue
- Owner once saw a task added in Lists also appear in the default list (a real duplicate after
  editing). Not reproduced; data had no duplicates. `addTask` now logs list position/date/tag count
  (no titles) to app.log so a repeat can be traced.
