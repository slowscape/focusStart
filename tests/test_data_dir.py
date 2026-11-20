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


def test_data_folder_per_system(tmp_path, monkeypatch):
    monkeypatch.delenv("APPDATA", raising=False)
    monkeypatch.setattr(main.Path, "home", classmethod(lambda cls: tmp_path))
    monkeypatch.setattr(main.sys, "platform", "darwin")
    assert main.default_data_dir() == tmp_path / "Library" / "Application Support" / "StepTask"
    monkeypatch.setattr(main.sys, "platform", "linux")
    monkeypatch.delenv("XDG_DATA_HOME", raising=False)
    assert main.default_data_dir() == tmp_path / ".local" / "share" / "StepTask"
    monkeypatch.setenv("XDG_DATA_HOME", str(tmp_path / "xdg"))
    assert main.default_data_dir() == tmp_path / "xdg" / "StepTask"


def test_mac_moves_old_folder_too(tmp_path, monkeypatch):
    monkeypatch.delenv("APPDATA", raising=False)
    monkeypatch.setattr(main.Path, "home", classmethod(lambda cls: tmp_path))
    monkeypatch.setattr(main.sys, "platform", "darwin")
    old = tmp_path / "Library" / "Application Support" / "FocusStart"
    old.mkdir(parents=True)
    assert main.default_data_dir().name == "StepTask" and not old.exists()
