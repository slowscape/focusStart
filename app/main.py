"""Entry point: logging, single-instance lock, data load, QML engine, window."""
from __future__ import annotations

import argparse
import hashlib
import logging
import logging.handlers
import os
import sys
import traceback
from pathlib import Path

APP_NAME = "FocusStart"
APP_ID = "FocusStart.App.1"  # Windows AppUserModelID
ROOT = Path(__file__).resolve().parent
log = logging.getLogger("focusstart")


def default_data_dir() -> Path:
    appdata = os.environ.get("APPDATA")
    if appdata:
        return Path(appdata) / APP_NAME
    return Path.home() / ".local" / "share" / APP_NAME


def parse_args(argv):
    p = argparse.ArgumentParser(prog=APP_NAME)
    p.add_argument("--data-dir", type=Path, default=None,
                   help=r"Data folder (default: %%APPDATA%%\FocusStart)")
    p.add_argument("--style", default=os.environ.get("FOCUSSTART_STYLE", "FluentWinUI3"),
                   help="Qt Quick Controls style (FluentWinUI3, Material, Basic)")
    args, _unknown = p.parse_known_args(argv)  # tolerate Qt's own flags
    return args


def setup_logging(data_dir: Path) -> None:
    data_dir.mkdir(parents=True, exist_ok=True)
    h = logging.handlers.RotatingFileHandler(data_dir / "app.log", maxBytes=512_000,
                                             backupCount=2, encoding="utf-8")
    h.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s: %(message)s"))
    root = logging.getLogger()
    root.setLevel(logging.INFO)
    root.addHandler(h)
    if sys.stdout is not None and sys.stderr is not None and not sys.executable.lower().endswith("pythonw.exe"):
        root.addHandler(logging.StreamHandler())

    def hook(exc_type, exc, tb):
        log.critical("uncaught exception:\n%s", "".join(traceback.format_exception(exc_type, exc, tb)))
    sys.excepthook = hook


def message_box(text: str, title: str = APP_NAME) -> None:
    """Show an error without Qt (it may be the thing that's missing)."""
    if sys.platform == "win32":
        try:
            import ctypes
            ctypes.windll.user32.MessageBoxW(None, text, title, 0x40)  # MB_ICONINFORMATION
            return
        except Exception:  # noqa: BLE001
            pass
    print(f"{title}: {text}", file=sys.stderr)


def set_app_user_model_id() -> None:
    if sys.platform == "win32":
        try:
            import ctypes
            ctypes.windll.shell32.SetCurrentProcessExplicitAppUserModelID(APP_ID)
        except Exception as e:  # noqa: BLE001
            log.warning("AppUserModelID not set: %s", e)


def allow_foreground_for_others() -> None:
    """Let the running instance bring itself to the front when we ping it."""
    if sys.platform == "win32":
        try:
            import ctypes
            ctypes.windll.user32.AllowSetForegroundWindow(-1)  # ASFW_ANY
        except Exception:  # noqa: BLE001
            pass


def run(argv=None) -> int:
    args = parse_args(sys.argv[1:] if argv is None else argv)
    data_dir = (args.data_dir or default_data_dir()).expanduser().resolve()
    try:
        setup_logging(data_dir)
    except OSError as e:
        message_box(f"Can't use the data folder:\n{data_dir}\n\n{e}")
        return 1
    log.info("starting; data dir %s; python %s", data_dir, sys.version.split()[0])

    try:
        from PySide6 import __version__ as pyside_version
        from PySide6.QtCore import QLockFile, QUrl, QTimer, qInstallMessageHandler, QtMsgType
        from PySide6.QtGui import QGuiApplication, QIcon
        from PySide6.QtNetwork import QLocalServer, QLocalSocket
        from PySide6.QtQml import QQmlApplicationEngine
        from PySide6.QtQuickControls2 import QQuickStyle
    except ImportError as e:
        log.exception("PySide6 import failed")
        message_box("FocusStart couldn't start because PySide6 isn't installed correctly.\n\n"
                    "Delete the .venv folder next to launch.bat and run launch.bat again.\n\n"
                    f"Details: {e}")
        return 1
    log.info("PySide6 %s", pyside_version)

    from .core import dates
    from .core.service import Service
    from .core.store import SchemaTooNewError, Store
    from .qt.backend import Backend
    from .qt.sound import SoundBank

    set_app_user_model_id()
    QGuiApplication.setApplicationName(APP_NAME)
    QGuiApplication.setOrganizationName(APP_NAME)
    QQuickStyle.setStyle(args.style)
    app = QGuiApplication(sys.argv[:1])
    app.setWindowIcon(QIcon(str(ROOT / "assets" / "images" / "icon.png")))

    def qt_messages(mode, ctx, msg):
        level = {QtMsgType.QtDebugMsg: logging.DEBUG, QtMsgType.QtInfoMsg: logging.INFO,
                 QtMsgType.QtWarningMsg: logging.WARNING}.get(mode, logging.ERROR)
        logging.getLogger("qt").log(level, "%s (%s:%s)", msg, ctx.file, ctx.line)
    qInstallMessageHandler(qt_messages)

    # ---- single instance: never two writers ----
    server_name = f"{APP_NAME}-" + hashlib.sha1(str(data_dir).lower().encode()).hexdigest()[:12]
    lock = QLockFile(str(data_dir / "app.lock"))
    if not lock.tryLock(200):
        log.info("another instance holds the lock; asking it to show itself")
        allow_foreground_for_others()
        sock = QLocalSocket()
        sock.connectToServer(server_name)
        if sock.waitForConnected(1000):
            sock.write(b"show")
            sock.waitForBytesWritten(1000)
            sock.disconnectFromServer()
        return 0

    # ---- data ----
    store = Store(data_dir)
    try:
        loaded = store.load()
    except SchemaTooNewError as e:
        log.error("%s", e)
        message_box("This data file was saved by a newer version of FocusStart, so this "
                    "version won't open it (to avoid overwriting anything).\n\n"
                    f"{data_dir}\\data.json")
        return 1
    if loaded.notice:
        log.warning("load notice: %s", loaded.notice)

    service = Service(loaded.data, dates.system_now)
    # Parented to the app so they outlive the QML engine at shutdown.
    sounds = SoundBank(ROOT / "assets" / "sounds", parent=app)
    backend = Backend(service, store, sounds, loaded.notice, loaded.is_new, parent=app)
    if loaded.is_new:
        backend.flush()

    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    engine.load(QUrl.fromLocalFile(str(ROOT / "qml" / "Main.qml")))
    if not engine.rootObjects():
        log.error("QML failed to load")
        message_box("FocusStart couldn't load its interface. Details are in app.log in:\n"
                    f"{data_dir}")
        return 1
    window = engine.rootObjects()[0]

    # ---- window geometry: restore, keep on-screen ----
    geo = service.data.settings.window
    if geo:
        from PySide6.QtCore import QRect
        want = QRect(geo["x"], geo["y"], max(320, geo["w"]), max(480, geo["h"]))
        visible = any(s.availableGeometry().intersects(want) and
                      s.availableGeometry().intersected(want).width() >= 100
                      for s in app.screens())
        window.resize(want.width(), want.height())
        if visible:
            window.setPosition(want.x(), want.y())
    window.show()

    # ---- second-launch ping: raise the window ----
    server = QLocalServer()
    QLocalServer.removeServer(server_name)
    if server.listen(server_name):
        def on_connection():
            conn = server.nextPendingConnection()
            if conn is None:
                return
            conn.readyRead.connect(lambda: (conn.readAll(), raise_window()))
            conn.disconnected.connect(conn.deleteLater)

        def raise_window():
            from PySide6.QtCore import Qt
            if window.visibility() == window.Visibility.Minimized:
                window.showNormal()
            window.show()
            window.raise_()
            window.requestActivate()
        server.newConnection.connect(on_connection)
    else:
        log.warning("local server not listening: %s", server.errorString())

    def on_quit():
        g = window.geometry()
        service.data.settings.window = {"x": g.x(), "y": g.y(), "w": g.width(), "h": g.height()}
        backend.flush()
        lock.unlock()
        log.info("exit")
    app.aboutToQuit.connect(on_quit)

    rc = app.exec()
    # Tear down QML before the backend it binds to.
    del window
    del engine
    return rc
