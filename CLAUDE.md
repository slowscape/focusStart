# FocusStart: notes for Claude Code

Local-only Windows to-do app for ADHD task initiation. Python 3.12 + PySide6 (QML, FluentWinUI3 style).
`SPEC.md` is the original brief. Where this file and SPEC.md disagree, this file wins:
the owner changed several things after trying the app (listed under "Decisions").

## Run and test
- Run: `launch.bat` (creates `.venv`, installs `requirements.txt`, starts `pythonw -m app`).
  With a console and logs: `.venv\Scripts\python -m app`. Data: `%APPDATA%\FocusStart\` (`app.log` there).
- Tests (core only, no Qt): `.venv\Scripts\python -m pip install -r requirements-dev.txt`, then `.venv\Scripts\python -m pytest`.
- Load diagnosis: `diagnose.bat` writes `diagnose.txt` (which Qt module/DLL fails, which runtime/ICU DLL copies are on PATH).
- After any QML change, run the app and check `app.log` for QML warnings (binding loops, null refs).

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
  own with one soft chime; after a break the next focus waits (`Pomodoro.waiting`) until play or a
  Start arrow. Durations editable live. On/off in Settings or the bar's power button (same flag). Off = bar
  greyed out with the power button live (never hidden); power off->on is a reset that starts a fresh
  focus session (`pomoPower`). Per task in Edit task (`extra.pomodoro_off`): no bar, no auto-start.
- The bottom day-progress bar was removed (owner didn't like it). `core/progress.py` still computes
  done/remaining for the badges and the once-a-day "Day complete" celebration; its ratchet "floor"
  no longer drives any UI.
- Focus layout: the step text area has a fixed height (long text shrinks to fit); notes fill the
  middle; the action row and Done are pinned to the bottom so nothing shifts under the cursor.
- My Day shows "N Steps Done" and "N Tasks Done" badges. History tab lists every completion.
- History rows open their task. A finished task shows read-only (notes, completed steps) with
  "Delete from history" (confirmed; `delete_task(..., include_completed=True)`). No bulk clear.
- Notes are labelled "Task Notes", no placeholder text.
- **No morning recap** (removed with its logic; old `last_recap_date`/`recap_history` keys sit in `extra`).
- App icon (`tools/generate_images.py`): the My Day progress ring, 3 segments, 2 green, on a dark disc.
- Focus primary button: "Step Complete" ("Task Complete" on a step-less task).
- Print: My Day header print icon, Lists "..." menu. Saves a checklist PDF (18 pt, empty checkbox per
  task and remaining step) via a save dialog (default Documents), then opens it in the PDF viewer.
- Pomodoro limits live in `core/pomodoro.LIMITS` (Focus 180, Short 60, Long 120); UI uses the same.
- Positive-only guardrails from SPEC.md section 9 still apply (no streaks, overdue, red, guilt copy).

## Open question for the owner
- "Click a done step to refer to its notes": steps have no notes field today (only the task's
  "Task Notes"). Ask whether they want per-step notes before building it.
