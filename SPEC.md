# FocusStart: build spec (working title)

A small, local-only desktop to-do app for Windows, designed around ADHD task initiation.
Built with Python 3.12 + PySide6 (Qt Quick / QML). Launched by a `.bat` file. No network, no AI, no installers.

This document is the full design brief. Read all of it before writing code. Section 14 lists things the design author could not verify and that must be checked first.

---

## 1. Goals and non-goals

### The problem the app solves
The user stalls on vague tasks ("plan the trip"). Once the task is broken into small concrete steps, they can start with no trouble. So the app's core loop is:

1. Add a task.
2. Spend about 2 minutes listing small actionable steps.
3. Work through the steps one at a time, with satisfying feedback.
4. Each morning, see past wins, then flow straight into today's work.

### Design principles (apply to every decision)
- Fast, clean, uncluttered. Few controls on screen at once. When in doubt, remove.
- Show only what the user is doing right now. Finished steps vanish. Past wins live in the morning recap.
- No shame, ever. No overdue badges, no overdue counts, no streaks, no "you missed" messages, no loss framing.
- Rewarding through sound, motion and encouraging words. No points, levels, badges or leaderboards.
- Low friction. Adding a task or step takes seconds. Everything that completes can be undone.

### Non-goals (do NOT build)
- Network access of any kind, accounts, sync, telemetry, update checks.
- AI or LLM features.
- Reminders, notifications, alarms.
- Always-on-top window, pop-out windows, global hotkeys.
- Streaks, points, XP, levels, badges.
- An evening or end-of-day screen.
- Recurring tasks, tags, priorities, due-date and overdue concepts, sharing, collaboration, mobile.
- Native installers. The app runs from a folder via a venv.

---

## 2. Environment and constraints

- OS: Windows 11 (confirmed). Python 3.12.7 is installed, and the user already launches Python from a `.bat` file on this machine. The user cannot run installers; `pip` is allowed.
- Everything installs into a project-local venv (`.venv`). No admin rights, no system-wide installs.
- Primary stack: PySide6 >= 6.8 (6.11 was current as of Mar 2026; supports Python 3.10 to 3.14).
  - PySide6 pulls two wheels, Essentials and Addons. Addons contains QtMultimedia, which sound needs.
  - License: LGPL, fine for personal use.
- UI: QML with Qt Quick Controls, style `FluentWinUI3` (Windows 11 Fluent look; the user's reference app is Microsoft To Do).
- Data: one JSON file, local. The app makes no network calls.
- Target feel: small side-of-screen window (default 380 x 720, minimum 320 x 480), resizable, remembers size and position. It is a normal window, not always-on-top.

---

## 3. Architecture

Keep all logic in plain Python with no Qt imports, so it is unit-testable. The Qt layer is a thin bridge.

```
focusstart/
  launch.bat
  requirements.txt            # PySide6>=6.8,<7
  SPEC.md
  app/
    __main__.py / main.py     # entry; single-instance lock; engine setup
    core/                     # NO Qt imports
      models.py               # dataclasses: Task, Step, TaskList, Settings
      store.py                # load/save JSON, atomic write, backups, recovery
      service.py              # all mutations: add/complete/skip/undo/plan/date
      recap.py                # stats + positive-message selection
      dates.py                # local-date helpers, week/month bounds, rollover
      progress.py             # day-progress units, ratchet, day-complete detection
    qt/
      backend.py              # QObject exposed to QML: properties, slots, signals
      models.py               # QAbstractListModel subclasses (My Day, steps, upcoming, lists)
      sound.py                # QSoundEffect pool + sound selection logic
    qml/
      Main.qml
      Theme.qml               # singleton: spacing, radii, durations, fonts
      screens/ MorningRecap.qml  MyDay.qml  FocusView.qml  PlanSteps.qml
               Upcoming.qml  Lists.qml  TaskEditor.qml  Settings.qml
      components/ TaskCard.qml  StepRow.qml  CheckCircle.qml  StepRing.qml
                  ConfettiBurst.qml  PopBurst.qml  UndoToast.qml  StatBar.qml
                  DayBar.qml  DayCompleteOverlay.qml
    assets/sounds/            # generated WAVs (see 9)
  tools/generate_sounds.py    # writes the WAVs using only stdlib (wave, math)
  tests/                      # pytest for core/
```

Important implementation notes:
- Use proper `QAbstractListModel` row insert/remove signals (not full model resets). The "steps and tasks vanish when checked" animation depends on `ListView` `remove` / `displaced` transitions, which only run on true row removal.
- All state mutations go through `core/service.py`. The Qt layer calls service methods, then emits model changes.
- Save is debounced (about 300 ms after the last change) and also forced on exit.
- Single-instance: take a file lock in the data dir (e.g., `QLockFile`). A second launch should bring the existing window to front, or exit quietly. Never allow two writers.
- Log errors to `app.log` in the data dir. The app runs under `pythonw.exe`, so there is no console.
- Set a Windows AppUserModelID (via `ctypes`) so the taskbar shows the right icon and grouping.

---

## 4. Launcher (`launch.bat`)

```bat
@echo off
setlocal
cd /d "%~dp0"
if not exist ".venv\Scripts\pythonw.exe" (
  echo First run: setting up. This takes a minute...
  py -3.12 -m venv .venv || python -m venv .venv
  ".venv\Scripts\python.exe" -m pip install --upgrade pip
  ".venv\Scripts\python.exe" -m pip install -r requirements.txt
)
start "" ".venv\Scripts\pythonw.exe" -m app %*
```

- First run shows a console while pip installs; later runs start silently.
- Accept `--data-dir <path>` so the user can point the data folder at e.g. a OneDrive folder. Default: `%APPDATA%\FocusStart\`.
- Fail with a readable message (a small dialog or log) if Python or pip is missing.

---

## 5. Data model and storage

Single file: `<data_dir>\data.json`. Schema:

```json
{
  "schema_version": 1,
  "settings": {
    "sound": true,
    "volume": 0.7,
    "effects": "full",
    "week_starts": "monday",
    "last_recap_date": "2026-11-16",
    "day_progress": {"date": "2026-11-16", "floor": 0.0},
    "days_completed": ["2026-11-14"],
    "window": {"x": 100, "y": 100, "w": 380, "h": 720}
  },
  "lists": [{"id": "uuid", "name": "Home", "order": 0}],
  "tasks": [{
    "id": "uuid",
    "list_id": "uuid",
    "title": "Plan trip itinerary",
    "notes": "free text; where I left off",
    "planned_date": "2026-11-17",
    "created_at": "2026-11-16T11:00:00-08:00",
    "completed_at": null,
    "order": 0,
    "steps": [{
      "id": "uuid",
      "text": "Pick dates",
      "order": 0,
      "created_at": "2026-11-16T11:02:00-08:00",
      "done_at": null
    }]
  }]
}
```

Rules:
- `effects` is one of `full | calm | off`.
- `planned_date` is a local `YYYY-MM-DD` string, or null. It is the single date concept; there is no due date and no overdue.
- Timestamps are ISO 8601 with local offset. All "day" bucketing uses the local date.
- Completed steps and tasks are kept forever (never auto-deleted); recap statistics come from them. Completed items are hidden from every list view.
- Deleting an incomplete task deletes it and its steps outright. Completed tasks cannot be deleted in v1.
- Atomic write: write `data.json.tmp`, flush and fsync, then `os.replace`.
- Backups: before the first write each day, copy `data.json` to `backups\data-YYYY-MM-DD.json`; keep the newest 14.
- On load failure (corrupt or unreadable JSON): try the newest backup, show a calm one-line notice, and never silently start with an empty file when a non-empty one exists.
- `schema_version` drives future migrations; the loader must reject unknown future versions rather than overwrite them.
- A first run creates one list called "Tasks".

### Domain rules
- My Day = all incomplete tasks where `planned_date <= today`. Unfinished tasks therefore roll over automatically each day, with no action from the user and no visual flag that they rolled.
- "Add to My Day" sets `planned_date = today`.
- Upcoming = incomplete tasks where `planned_date > today`, grouped by date.
- A task with no `planned_date` lives only in its list.
- A task is complete when its last remaining step is checked. A task with zero steps has a plain checkbox.
- Completing a task by hand from the editor does not count its remaining steps as completed.
- Recap counts: "steps completed" = steps with `done_at` in the window. "Tasks completed" = tasks with `completed_at` in the window.

---

## 6. Screens and behavior

Navigation: a simple top bar with three tabs (My Day, Upcoming, Lists) and a gear icon for Settings. The Morning recap, Focus view and Plan-steps page are full-window screens with a Back button. Avoid `Drawer`, `SplitView` and `StackView` (FluentWinUI3 does not support them yet; see 14). Use plain items plus `Loader` and custom transitions.

### 6.1 My Day (home, "view A")
- Header: "My Day", today's date, and a small positive-only chip showing wins today (e.g., "3 done"). Hidden when zero.
- A list of task cards. Each card shows:
  - Title.
  - For tasks with steps: a segmented step ring or bar showing progress, and the next remaining steps inline, up to 3, with "+N more". The card expands in place to show all remaining steps and the notes preview. Expanding must NOT navigate away.
  - For tasks without steps: a circular checkbox and an "Add steps" button.
  - A play icon, "Start", which opens Focus view. A "..." menu offers edit, change date, change list, delete.
- Checking a step inline: the step plays the step effect and then animates away (fade and collapse). There is no strikethrough and no "completed" section. Checking the last step completes the task: bigger effect, then the whole card collapses away.
- Every completion shows an undo toast for about 5 seconds ("Undone" restores the step or task and cancels the animation if still running).
- Quick-add field pinned at the bottom: "Add a task…". Enter creates a task for today. A small "Tomorrow" chip next to the field toggles the date for the next add. Keep focus in the field after adding so several tasks can be added in a row.
- Empty state: calm illustration or animation plus "All clear" and a gentle "Add something for tomorrow". No guilt copy.
- Reordering by drag is nice-to-have (phase 2).

### 6.2 Add steps / plan page ("planning")
- On a task with no steps, the button reads "Add steps". It is also available in the editor and Focus view for adding more later.
- Page content: the heading **"List small actionable steps for 2 minutes"**, the task title, a 2:00 countdown ring, a step input, and the list of steps entered so far.
- The countdown starts automatically when the page opens. It is a soft timer: at 0:00 play a gentle chime and change the sub-line to something kind ("That's a real start."). Never force-stop; the user can keep adding.
- Input: Enter adds a step and keeps focus. Backspace on an empty input removes the last step. Steps can be edited or removed in the list.
- A rotating hint under the input, from a fixed pool (no AI), for vague ideas, e.g.: "What's the very first thing you'd open or touch?", "What do you need to find out?", "What's the smallest visible result?", "Is there anyone you need to ask?".
- Primary button **"Get started"**, enabled once there is at least one step. It saves the steps and opens Focus view on this task.
- Leaving without steps is fine; nothing is lost.

### 6.3 Focus view ("view C")
Opened from "Start" in My Day, from "Get started", or from the morning recap's "Start with…" button.
- Layout, top to bottom: Back, task title with list name, a segmented progress indicator (done and remaining), the current step as large text, and the notes block labeled "Where I left off" (editable inline; saves on blur).
- Primary action: a large "Done" button (also Enter/Space).
- Secondary actions:
  - **Skip step**: moves the current step to the end of this task's queue and shows the next step. Nothing is marked done. If only one step remains, this control is hidden.
  - **Skip task**: jumps to the next task in My Day order (wraps around; hidden if there is only one task).
  - "+ step": a small inline field to add a newly discovered step.
- Completing a step: step effect, the step animates out, the next step slides in, and progress fills.
- Completing the last step: task effect, then a card offering "Next up: <title>" and "Back to My Day". Do not auto-advance.
- A task with no steps shows the title, notes, a "Done" button and "Add steps".

### 6.4 Morning recap
- Shown once per calendar day, on the first window activation after the local date changes (also on a fresh launch). The app stays open for days, so check on window activation and on a 60-second timer. If the window is not active when the date changes, show the recap on next activation.
- Persist `last_recap_date` when it is shown.
- Skip the recap entirely on the very first run (no history); show a one-line welcome instead.
- Content:
  1. Greeting, time-appropriate ("Good morning" / "Welcome back").
  2. Three stat bars, in this order: **Yesterday**, **This week**, **This month**. Each shows two numbers: tasks completed and steps completed. Bar length is proportional to the user's own personal best for that period type, with no target and no label for the best. If a period is zero, show a neutral line ("Fresh start", "New week", "New month") instead of an empty bar.
  3. Two or three positive messages drawn from the data (see 6.4.1).
  4. Today preview: "Today: N tasks".
  5. Primary button **"Start with <first task in My Day>"**, which opens Focus on that task. Secondary: "See my day". If nothing is planned: "Plan today", which opens My Day with the quick-add focused.
- "This week" = from the configured week start through today inclusive. "This month" = the 1st through today inclusive.

#### 6.4.1 Positive messages
Select 2 to 3 eligible messages per recap. Prefer variety, avoid repeating a template two recaps in a row, and seed any randomness by the date so it is stable all day. Never mention failure, absence, overdue work or comparison with others. Example templates (write a pool of 3+ phrasings per template):
- Big task: "You finished "{title}", which had {n} steps. Way to stick with it."
- Planning: "You broke "{title}" into {n} steps before you started. That's the hardest part."
- Volume: "{n} steps done yesterday. That's real momentum."
- Week: "{tasks} tasks and {steps} steps so far this week."
- Month: "{tasks} tasks and {steps} steps this month."
- Cleared day (when yesterday is in `days_completed`): "You cleared your whole day yesterday. {tasks} tasks, {steps} steps."
- Quiet day: "Fresh page today." (never frame a quiet day negatively)
Fall back to week or month messages when yesterday has no data.

### 6.5 Upcoming
- Planned tasks grouped by date: "Tomorrow", then weekday names for the rest of this week, then "Later".
- Each row: title, step count. Tap opens the editor. A row action moves a task to today.
- Quick-add defaults to the selected day (tomorrow by default).

### 6.6 Lists
- User-defined lists (the user groups tasks by type). Shows incomplete counts.
- Create, rename, delete (deleting a list with tasks asks where to move them).
- Inside a list: its incomplete tasks, with quick-add defaulting to no date. Each task can be sent to My Day.
- Narrow window: a list picker (popup menu) rather than a permanent sidebar.

### 6.7 Task editor
- Fields: title, notes (multi-line plain text), date (Today, Tomorrow, pick a date, none), list.
- Steps editor: add, edit, reorder, delete incomplete steps. Completed steps are hidden; a collapsed "Completed steps (N)" disclosure lets the user restore a mistaken one. This disclosure exists only in the editor, never in My Day.
- Buttons: "Add steps" (opens the plan page), "Mark task done", "Delete task".

### 6.8 Settings
- Sound on/off, volume, effects level (Full, Calm, Off), week starts on (Monday/Sunday), data folder (display path and "Open folder").

### 6.9 Day progress bar
- A thin bar (about 6 px) pinned along the very bottom edge of the window, below the quick-add field. Visible on My Day and Focus view. Hidden on the morning recap, plan page, Upcoming, Lists, editor and settings.
- It shows progress through today's work. Units:
  - Each step is 1 unit. A task with no steps is 1 unit.
  - `done` = steps with `done_at` today + step-less tasks with `completed_at` today.
  - `remaining` = incomplete steps of incomplete tasks in My Day + each incomplete step-less task in My Day.
  - `total = done + remaining`. Steps dropped by manually completing a task, or removed by deleting a task or step, are excluded.
  - Rolled-over tasks count like any other task in My Day. Steps completed on earlier days do not count.
  - `computed = done / total` (0 when total is 0).
- **Ratchet (must implement):** the displayed fill never decreases during a day. This user routinely discovers more steps and adds more tasks mid-day, and that must not feel like losing progress. Displayed fill = `max(stored floor, computed)`. When scope grows and `computed` drops below the floor, hold at the floor and let it advance again only once real progress exceeds it. The fill reaches 100% only when `remaining == 0`. Persist `settings.day_progress = {date, floor}`; reset the floor to 0 when the date changes.
- No text and no percentage on the bar. Hover (tooltip) shows "7 of 12 steps today". An empty day (total = 0) shows a neutral empty track.
- Animation: the fill advances with a ~300 ms ease and a brief shimmer at the leading edge on each advance. Flat accent color, no gradient fills.
- Open design question for the user to revisit after trying it: steps-weighted progress (above) is smoother than task-weighted but means a long task moves the bar more than a short one.

### 6.10 Day complete
- Condition: `remaining == 0` AND `done >= 1` AND today is not in `settings.days_completed`. An empty day never triggers it.
- When it fires: play the unique Day complete celebration (section 8), append today to `days_completed`, then show an overlay card: "Day complete", "{tasks} tasks and {steps} steps today. Nice work.", with buttons "Plan tomorrow" (opens Upcoming with quick-add defaulting to tomorrow) and "Close".
- Fires at most once per day. If the user later adds tasks and clears them again the same day, the bar fills again with the normal task-done effect and a small toast "All clear again". Do not repeat the big celebration.
- Reward is immediate: trigger on completion without waiting for the undo window. If the user undoes the final completion within the undo window, dismiss the overlay and remove today from `days_completed` so it can fire again.
- Effects setting: `Full` = everything; `Calm` = fanfare sound, bar sweep and the card, no confetti; `Off` = the card only, silent.
- The next morning's recap may mention it (see 6.4.1).

---

## 7. Visual design

- Style: Qt Quick Controls `FluentWinUI3` (Windows 11 Fluent look). Follow the system light/dark theme and accent color. Typography is the system font (Segoe UI Variable on Windows 11).
- Layout: 8 px spacing grid, 8 px corner radius on cards, generous padding, one accent color. Green is reserved for completion effects.
- Keep the window narrow-friendly: single column; nothing requires horizontal scrolling at 320 px.
- Motion: 150 to 250 ms eases; never block input during animations.
- Bottom day bar (6.9): about 6 px tall, full width, rounded track, accent fill. It sits flush with the bottom window edge and must not push the quick-add field out of reach at the minimum window height.
- Fallback if FluentWinUI3 misbehaves (see 14): `Material` or `Basic` with a custom palette, keeping the same layout and spacing.

---

## 8. Completion effects (the reward system)

Reward is immediate and sensory, not numeric.

- **Step done:** short soft "pop" sound, checkmark animation, a small particle burst at the checkbox, then the row collapses out.
- **Task done:** a bigger chime (a resolving chord), a confetti burst across the card, the card collapses out. The first task completed each day gets a slightly bigger flourish.
- **Ascending pitch:** within a task, step sounds climb a pentatonic scale as steps are completed, so the user hears progress. The final step resolves to the chord.
- **Variety:** rotate among several effect variants (colors, burst shapes, 3 to 4 sound variants) so the effect does not become wallpaper. Novelty fading is the main reason ADHD users abandon apps.
- **Plan timer end:** a gentle chime.
- **Day complete (the biggest effect in the app, used nowhere else):** a longer fanfare of about 1.5 to 2 seconds (a rising arpeggio that resolves, unmistakably different from the task chime; its own file, `day_complete.wav`), a bright shimmer that sweeps the bottom bar left to right and then pulses, three waves of full-window confetti with more colors and shapes than the task confetti, then the overlay card (6.10). It is the only effect that covers the whole window.
- Implementation: confetti and bursts via `QtQuick.Particles` (`ParticleSystem`, `Emitter`, `ImageParticle`), with a `Canvas`/animated-`Rectangle` fallback if the module is unavailable. Sounds via `QSoundEffect` (low-latency, WAV) with a small pool for overlapping plays.
- Sounds are generated by `tools/generate_sounds.py` using only the standard library (`wave`, `math`): sine/triangle tones with attack and decay envelopes. Commit the generated WAVs.
- Settings: Effects `Full` (everything), `Calm` (sound and a small checkmark only), `Off` (silent and still). Sound has its own mute and volume.

### Small usage-boosting touches (all positive-only)
- Rotating encouraging micro-copy for completions ("Nice.", "One down.", "That's momentum."), never repeating back-to-back.
- Step ring fills as steps complete (segments, not one smooth bar).
- Wins-today chip in My Day.
- Smooth list-collapse animations when items vanish.
- Quick-add always focused.
- Friendly empty states.
- In-app keyboard shortcuts only: Ctrl+N new task, Enter add/confirm, Esc back, Space/Enter Done in Focus, Right arrow Skip step.

---

## 9. Positive-only guardrails (must not regress)
Never add: streak counters, overdue/late labels, red warning colors for dates, "you haven't…" messages, absence messages, goals or targets, notifications, or any comparison framing. If a feature needs one of these to work, drop the feature.

---

## 10. Testing

Unit tests (pytest, `core/` only):
- Rollover: a task planned yesterday appears in today's My Day; planned for tomorrow does not.
- Step completion and undo restore exact state; last step completes the task; undo of the last step reopens it.
- Skip step reorders only the queue and marks nothing done.
- Recap windows: yesterday, week-to-date (both week-start options), month-to-date, across DST changes and year boundaries.
- Message selection is deterministic for a given date and never emits a forbidden phrase.
- Day progress: units and `done/remaining/total` are correct for mixed step and step-less tasks and for rolled-over tasks; steps done on earlier days are excluded; dropped steps leave the total.
- Ratchet: the displayed fill never decreases within a day when steps or tasks are added; it reaches 100% only when `remaining == 0`; the floor resets on a new date and survives a restart.
- Day complete: fires once per day; an empty day never fires; undoing the final completion clears today from `days_completed`; completing again later the same day does not replay it.
- Store: atomic write survives a simulated crash (no partial file), backups rotate to 14, corrupt file recovers from backup, unknown newer schema is refused.

Manual checklist (run on the user's machine):
- Cold start from `launch.bat` on a clean clone, then a silent relaunch.
- Window remembers size and position; the minimum size is respected.
- Recap shows on the first activation after midnight with the app left open overnight.
- Every completion path plays the right sound and effect; mute and Off work.
- Second launch does not corrupt data.
- Light and dark theme both look right.
- The bottom bar advances smoothly, never visibly shrinks when a step or task is added, and the Day complete celebration plays once and only once per day (and is dismissed by undo).

---

## 11. Build order (milestones)

0. **Spike (about 30 min):** confirm the Fluent look, `QSoundEffect` playback and `QtQuick.Particles` on the user's machine (see 14). Report findings before continuing.
1. Core: models, store, service, dates, with tests.
2. Shell: window, theme, backend bridge, My Day with inline steps, quick-add.
3. Focus view and plan page, with Skip step and Skip task.
4. Effects and sounds, then the day progress bar (6.9) and Day complete celebration (6.10).
5. Morning recap and recap logic.
6. Upcoming, Lists, Editor, Settings.
7. Polish: animations, empty states, window persistence, packaging of `launch.bat`.

---

## 12. Assumptions made by the design author (confirm with the user)
- App name "FocusStart" is a placeholder.
- A single `planned_date` replaces due dates; there is no overdue concept.
- Tapping a My Day card expands it in place; the play icon opens Focus; "..." opens the editor.
- Completed steps are hidden everywhere except the editor's collapsed disclosure.
- Recap bars scale to the user's personal best; "this week/month" include today.
- Week starts Monday.
- The plan timer auto-starts and never force-stops.
- Undo toast lasts about 5 seconds.
- Day progress is steps-weighted (each step is a unit, a step-less task is one unit) with a one-way ratchet; the bar shows no text or percentage.
- The bar appears on My Day and Focus view only.
- The Day complete celebration fires once per day, immediately, and is cancelled by undo.

## 13. Out of scope for v1 (possible later)
Recurring tasks, drag-reorder polish, a history browser, export/import, custom sounds, theme options.

## 14. Unverified items: check these first (the design author could not test them)
- **FluentWinUI3 on the user's Windows version.** Qt documents it as designed for Windows 11 and above, and as "under development": Dial, Drawer, HorizontalHeaderView, SplitView, StackView, SwipeDelegate, SwipeView, TreeViewDelegate, Tumbler and VerticalHeaderView fall back to Fusion. Confirm the style name (`QQuickStyle.setStyle("FluentWinUI3")`, import `QtQuick.Controls.FluentWinUI3`, Qt 6.8+) works with the installed PySide6. The user is on Windows 11, the platform this style targets, so a good result is expected; still apply the section 7 fallback if anything looks wrong.
- **`QtQuick.Particles` availability** in the pip wheel on Windows. If missing, use the fallback in section 8.
- **`QSoundEffect` with WAV** from the pip wheel on Windows (QtMultimedia lives in the Addons wheel). Qt's own docs suggest `QMediaPlayer` if wider format support is needed.
- **Install size and time** for PySide6 (Essentials about 55 to 72 MB on Windows; Addons size not checked).
- **Python launcher**: the user already launches Python from a `.bat`. Confirm whether `py -3.12` or `python` is the working command and keep the fallback in section 4.
- **Pop-out/always-on-top** was explicitly ruled out; do not add it.
