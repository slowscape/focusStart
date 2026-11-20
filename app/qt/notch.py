"""Lift the Pomodoro notch window above the macOS menu bar, without extra installs.

Qt's WindowStaysOnTopHint gives NSFloatingWindowLevel, which sits *below* the menu bar, so the
pill would land just under it. Here the NSWindow behind the QWindow is raised to the status-bar
level and allowed on every Space (and next to full-screen apps) through the Objective-C runtime
via ctypes. Anywhere else this does nothing; the pill then simply sits at the top of the screen.
"""
from __future__ import annotations

import ctypes
import ctypes.util
import logging
import sys

log = logging.getLogger(__name__)

NS_STATUS_WINDOW_LEVEL = 25
# NSWindowCollectionBehavior: CanJoinAllSpaces | Stationary | IgnoresCycle | FullScreenAuxiliary
COLLECTION = (1 << 0) | (1 << 4) | (1 << 6) | (1 << 8)

_objc = None


def _lib():
    global _objc
    if _objc is None:
        _objc = ctypes.cdll.LoadLibrary(ctypes.util.find_library("objc") or "/usr/lib/libobjc.A.dylib")
        _objc.sel_registerName.restype = ctypes.c_void_p
        _objc.sel_registerName.argtypes = [ctypes.c_char_p]
    return _objc


def _send(obj: int, sel: str, arg=None, argtype=None, restype=ctypes.c_void_p):
    """objc_msgSend with an explicit prototype (required on Apple silicon)."""
    lib = _lib()
    argtypes = [ctypes.c_void_p, ctypes.c_void_p] + ([argtype] if argtype else [])
    fn = ctypes.CFUNCTYPE(restype, *argtypes)(("objc_msgSend", lib))
    args = [ctypes.c_void_p(obj), ctypes.c_void_p(lib.sel_registerName(sel.encode()))]
    if argtype:
        args.append(arg)
    return fn(*args)


def elevate(win_id: int) -> bool:
    """win_id is QWindow.winId(): on macOS, a pointer to the window's NSView."""
    if sys.platform != "darwin" or not win_id:
        return False
    window = _send(win_id, "window")
    if not window:
        log.warning("notch: no NSWindow for the view yet")
        return False
    _send(window, "setLevel:", ctypes.c_long(NS_STATUS_WINDOW_LEVEL), ctypes.c_long, None)
    _send(window, "setCollectionBehavior:", ctypes.c_ulong(COLLECTION), ctypes.c_ulong, None)
    _send(window, "setHasShadow:", ctypes.c_bool(False), ctypes.c_bool, None)
    # Qt.Tool windows are NSPanels that hide whenever StepTask isn't the active app.
    _send(window, "setHidesOnDeactivate:", ctypes.c_bool(False), ctypes.c_bool, None)
    return True
