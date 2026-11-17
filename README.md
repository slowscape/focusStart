# FocusStart

A small, local-only Windows to-do app built around task initiation: add a task, spend
2 minutes listing tiny steps, then work through them one at a time. See `SPEC.md`.

## Run (Windows 11)
Double-click `launch.bat`. The first run creates `.venv` and installs PySide6
(~115 MB download, a console window shows progress). Later runs start silently.

Data lives in `%APPDATA%\FocusStart\` (`data.json`, `backups\`, `app.log`).
Use another folder (for example OneDrive):

```bat
launch.bat --data-dir "D:\OneDrive\FocusStart"
```

If setup ever breaks, delete the `.venv` folder and run `launch.bat` again.
Editing `requirements.txt` also triggers a reinstall on the next launch.

## Tips
- **Quick-add `/list`:** type `/` to pick a list (matching ignores case). Up/Down + Enter or Tab picks;
  a name that doesn't exist yet becomes a new list, spelled exactly as typed. The list chip
  stays until you clear it with its ✕.
- **Add for another day in one click:** type the task, then click Tomorrow or pick a date.
- **Pomodoro:** starts when you press a task's Start arrow. After a break it waits for you to
  press play. Click the time to change Focus/Short/Long minutes (applies live). Turn it on/off in
  Settings or with its power button (off greys it out; turning it back on starts fresh), or for
  one task in Edit task.
- **Print:** the printer icon on My Day, or a list's "..." menu, saves a checklist PDF and opens it.
- **Focus:** click any grey segment in the step bar to work on that step next.

## Develop
```bat
.venv\Scripts\python -m pip install -r requirements-dev.txt
.venv\Scripts\python -m pytest
.venv\Scripts\python -m app          # with a console, logs also print here
```
Style override for troubleshooting: `--style Material` (or `Basic`), or set
`FOCUSSTART_STYLE`.

Regenerate assets (stdlib only): `python tools/generate_sounds.py`,
`python tools/generate_images.py`.

## Layout
- `app/core/`: pure Python, no Qt (models, store, service, dates, progress, history, pomodoro, printout, phrases). Unit-tested.
- `app/qt/`: thin bridge (backend QObject, keyed list models, sound pool).
- `app/qml/`: UI (FluentWinUI3 style).
