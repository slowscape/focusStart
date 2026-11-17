"""Find out why PySide6 fails to load on this PC. Read-only: changes nothing.

    .venv\\Scripts\\python.exe tools\\diagnose.py

Prints which Qt module fails, which DLL fails, and which copies of the shared
C++ runtime DLLs (msvcp140/vcruntime140) and any other Qt DLLs are being picked up.
"""
from __future__ import annotations

import os
import platform
import subprocess
import sys
from pathlib import Path

WIN = sys.platform == "win32"
MODULES = ["shiboken6", "PySide6.QtCore", "PySide6.QtGui", "PySide6.QtNetwork",
           "PySide6.QtOpenGL", "PySide6.QtQml", "PySide6.QtQuick",
           "PySide6.QtQuickControls2", "PySide6.QtMultimedia"]
INTERESTING = ("msvcp140", "vcruntime140", "concrt140", "ucrtbase", "qt6", "shiboken",
               "pyside", "d3d", "dxgi", "opengl32", "dwrite")


# ------------------------------------------------------------------ Windows helpers
def file_version(path: str) -> str:
    if not WIN:
        return "?"
    try:
        import ctypes
        from ctypes import wintypes
        ver = ctypes.WinDLL("version")
        ver.GetFileVersionInfoSizeW.argtypes = [wintypes.LPCWSTR, wintypes.LPDWORD]
        ver.GetFileVersionInfoW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p]
        ver.VerQueryValueW.argtypes = [ctypes.c_void_p, wintypes.LPCWSTR,
                                       ctypes.POINTER(ctypes.c_void_p), ctypes.POINTER(wintypes.UINT)]
        size = ver.GetFileVersionInfoSizeW(path, None)
        if not size:
            return "no version info"
        buf = ctypes.create_string_buffer(size)
        if not ver.GetFileVersionInfoW(path, 0, size, buf):
            return "unreadable"
        p = ctypes.c_void_p()
        n = wintypes.UINT()
        if not ver.VerQueryValueW(buf, "\\", ctypes.byref(p), ctypes.byref(n)):
            return "unreadable"
        ffi = ctypes.cast(p, ctypes.POINTER(wintypes.DWORD * 13)).contents
        ms, ls = ffi[2], ffi[3]
        return f"{ms >> 16}.{ms & 0xFFFF}.{ls >> 16}.{ls & 0xFFFF}"
    except Exception as e:  # noqa: BLE001
        return f"error {e}"


def loaded_modules() -> list[str]:
    if not WIN:
        return []
    import ctypes
    from ctypes import wintypes
    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    psapi = ctypes.WinDLL("psapi", use_last_error=True)
    k32.GetCurrentProcess.restype = wintypes.HANDLE
    psapi.EnumProcessModules.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.HMODULE),
                                         wintypes.DWORD, ctypes.POINTER(wintypes.DWORD)]
    k32.GetModuleFileNameW.argtypes = [wintypes.HMODULE, wintypes.LPWSTR, wintypes.DWORD]
    arr = (wintypes.HMODULE * 4096)()
    needed = wintypes.DWORD()
    psapi.EnumProcessModules(k32.GetCurrentProcess(), arr, ctypes.sizeof(arr), ctypes.byref(needed))
    count = min(needed.value // ctypes.sizeof(wintypes.HMODULE), 4096)
    buf = ctypes.create_unicode_buffer(1024)
    out = []
    for i in range(count):
        if k32.GetModuleFileNameW(arr[i], buf, 1024):
            out.append(buf.value)
    return out


def print_interesting_loaded():
    mods = [m for m in loaded_modules() if any(k in Path(m).name.lower() for k in INTERESTING)]
    print("    DLLs loaded in this process (relevant ones):")
    for m in sorted(mods, key=lambda p: Path(p).name.lower()):
        print(f"      {Path(m).name:<28} {file_version(m):<16} {m}")


# ------------------------------------------------------------------ child modes
def child_import(name: str) -> None:
    try:
        __import__(name)
        print(f"  OK    {name}")
    except Exception as e:  # noqa: BLE001
        print(f"  FAIL  {name}: {type(e).__name__}: {e}")
        print_interesting_loaded()


def child_dlls() -> None:
    """Load each Qt6*.dll from the PySide6 folder by full path, report which fail."""
    import ctypes
    import importlib.util
    spec = importlib.util.find_spec("PySide6")
    sspec = importlib.util.find_spec("shiboken6")
    if spec is None:
        print("  PySide6 is not installed in this Python.")
        return
    pdir = Path(list(spec.submodule_search_locations)[0])
    for d in [pdir, Path(list(sspec.submodule_search_locations)[0]) if sspec else None]:
        if d and hasattr(os, "add_dll_directory"):
            os.add_dll_directory(str(d))
    dlls = sorted(pdir.glob("Qt6*.dll"), key=lambda p: (p.name != "Qt6Core.dll", p.name.lower()))
    failed = []
    for p in dlls:
        try:
            ctypes.WinDLL(str(p))
        except OSError as e:
            failed.append((p.name, getattr(e, "winerror", None), str(e)))
    print(f"  Loaded {len(dlls) - len(failed)} of {len(dlls)} Qt DLLs.")
    for name, code, msg in failed:
        print(f"  FAIL  {name}  (winerror {code}) {msg}")
    if failed:
        print_interesting_loaded()


# ------------------------------------------------------------------ main report
def scan_path():
    print("\n== Copies of shared/Qt DLLs found on PATH (these can shadow PySide6's own) ==")
    hits = 0
    for d in os.environ.get("PATH", "").split(os.pathsep):
        try:
            p = Path(d)
            if not p.is_dir():
                continue
            for f in p.iterdir():
                n = f.name.lower()
                if n.endswith(".dll") and (n.startswith(("msvcp140", "vcruntime140", "qt6", "qt5core"))):
                    print(f"  {f.name:<28} {file_version(str(f)):<16} {f}")
                    hits += 1
        except OSError:
            continue
    if not hits:
        print("  none")


def main() -> None:
    if len(sys.argv) >= 3 and sys.argv[1] == "--child-import":
        child_import(sys.argv[2]); return
    if len(sys.argv) >= 2 and sys.argv[1] == "--child-dlls":
        child_dlls(); return

    print("== System ==")
    print(f"  Python   {sys.version.split()[0]}  {sys.executable}")
    print(f"  Windows  {platform.platform()}  build {getattr(sys, 'getwindowsversion', lambda: None)() and sys.getwindowsversion().build}")
    edition = platform.win32_edition() if WIN and hasattr(platform, "win32_edition") else "?"
    print(f"  Edition  {edition}")
    print(f"  Session  {os.environ.get('SESSIONNAME', '?')}  (RDP-Tcp#.. = Remote Desktop, ICA = Citrix)")
    try:
        from importlib.metadata import version
        for pkg in ("PySide6-Essentials", "PySide6-Addons", "shiboken6", "PySide6", "PyQt5", "PyQt6"):
            try:
                print(f"  {pkg:<20} {version(pkg)}")
            except Exception:  # noqa: BLE001
                pass
    except ImportError:
        pass
    if WIN:
        sysroot = os.environ.get("SystemRoot", r"C:\Windows")
        for n in ("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll"):
            p = Path(sysroot) / "System32" / n
            print(f"  System32\\{n:<20} {file_version(str(p)) if p.exists() else 'not present'}")
        for n in ("vcruntime140.dll", "vcruntime140_1.dll", "msvcp140.dll"):
            p = Path(sys.base_prefix) / n
            if p.exists():
                print(f"  Python dir\\{n:<18} {file_version(str(p))}")

    print("\n== Importing each module in a fresh process ==")
    for m in MODULES:
        r = subprocess.run([sys.executable, __file__, "--child-import", m],
                           capture_output=True, text=True, timeout=120)
        sys.stdout.write(r.stdout or f"  ?     {m}: no output\n")
        if r.stderr.strip():
            print("    stderr:", r.stderr.strip().splitlines()[-1])

    if WIN:
        print("\n== Loading each Qt DLL directly ==")
        r = subprocess.run([sys.executable, __file__, "--child-dlls"],
                           capture_output=True, text=True, timeout=300)
        sys.stdout.write(r.stdout)
        if r.stderr.strip():
            print("    stderr:", r.stderr.strip().splitlines()[-1])

    scan_path()
    print("\nDone. Nothing was changed on this PC.")


if __name__ == "__main__":
    main()
