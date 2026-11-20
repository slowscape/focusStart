"""Build the app's small icon font from Microsoft's Fluent UI System Icons (MIT).

The full font is ~2.9 MB; the app uses ~20 icons, so we ship only those (a few KB).
Developer-only: needs fontTools (requirements-dev.txt), not needed to run the app.

1. Download from https://github.com/microsoft/fluentui-system-icons/tree/main/fonts :
   FluentSystemIcons-Regular.ttf and FluentSystemIcons-Regular.json (name -> code map).
2. python tools/subset_icons.py <folder with those two files>
3. It writes app/assets/fonts/StepTaskIcons.ttf and prints the glyph table (character and
   ink centre) for app/qml/theme/Theme.qml: paste it over the `glyphs` block.

To add an icon: find its name at https://github.com/microsoft/fluentui-system-icons
(e.g. "arrow_left"), add it to ICONS below, rerun, and use the key in QML (Icon { name: ... }).
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from fontTools import subset
from fontTools.ttLib import TTFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "app" / "assets" / "fonts" / "StepTaskIcons.ttf"
SIZE = 20  # Fluent ships 16/20/24/... variants; 20 suits the app's 10-16 px icons

# Our name (used in QML) -> Fluent icon name.
ICONS = {
    "back": "arrow_left", "next": "arrow_right",
    "play": "play", "pause": "pause", "stop": "stop", "timer": "timer",
    "more": "more_horizontal", "settings": "settings", "print": "print",
    "add": "add", "list": "list", "menu": "navigation",
    "sun": "weather_sunny", "calendar": "calendar_ltr",
    "check": "checkmark", "chevron": "chevron_down", "chevronR": "chevron_right",
    "close": "dismiss", "delete": "delete", "edit": "edit",
    "grip": "re_order_dots_vertical",
}


def main(src: Path) -> None:
    codes = json.loads((src / "FluentSystemIcons-Regular.json").read_text(encoding="utf-8"))
    table = {}
    for key, name in ICONS.items():
        full = f"ic_fluent_{name}_{SIZE}_regular"
        if full not in codes:
            sys.exit(f"not in the font: {full}")
        table[key] = codes[full]

    font = TTFont(src / "FluentSystemIcons-Regular.ttf")
    opts = subset.Options()
    opts.layout_features = []
    opts.name_IDs = ["*"]           # keep the family name (QML loads it by FontLoader.name)
    opts.notdef_outline = True
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=sorted(table.values()))
    sub.subset(font)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    font.save(OUT)
    print(f"wrote {OUT.relative_to(ROOT)} ({OUT.stat().st_size} bytes)\n")
    # Each icon's ink centre (x from the left, y up from the baseline) as a fraction of the em,
    # read from the outlines. Icon.qml centres that point: Qt's text metrics misreport this font,
    # and some Fluent glyphs sit off-centre in their em square on purpose.
    built = TTFont(OUT)
    upm = built["head"].unitsPerEm
    glyf, cmap = built["glyf"], built.getBestCmap()
    print("    readonly property var glyphs: ({")
    rows = []
    for key, code in table.items():
        g = glyf[cmap[code]]
        g.recalcBounds(glyf)
        cx = (g.xMin + g.xMax) / 2 / upm
        cy = (g.yMin + g.yMax) / 2 / upm
        rows.append(f'        "{key}":{" " * (9 - len(key))}["\\u{code:04X}", {cx:.3f}, {cy:.3f}]')
    print(",\n".join(rows))
    print("    })")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(Path(sys.argv[1]))
