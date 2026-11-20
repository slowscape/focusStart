"""The app was renamed FocusStart -> StepTask: the old data folder must carry over."""
from app import main


def test_old_folder_is_moved_to_new_name(tmp_path, monkeypatch):
    monkeypatch.setenv("APPDATA", str(tmp_path))
    old = tmp_path / "FocusStart"
    (old / "backups").mkdir(parents=True)
    (old / "data.json").write_text("{}", encoding="utf-8")
    d = main.default_data_dir()
    assert d == tmp_path / "StepTask"
    assert (d / "data.json").read_text(encoding="utf-8") == "{}"
    assert (d / "backups").is_dir() and not old.exists()


def test_existing_new_folder_wins(tmp_path, monkeypatch):
    monkeypatch.setenv("APPDATA", str(tmp_path))
    (tmp_path / "FocusStart").mkdir()
    (tmp_path / "StepTask").mkdir()
    assert main.default_data_dir() == tmp_path / "StepTask"
    assert (tmp_path / "FocusStart").exists()          # left alone


def test_fresh_install(tmp_path, monkeypatch):
    monkeypatch.setenv("APPDATA", str(tmp_path))
    assert main.default_data_dir() == tmp_path / "StepTask"
