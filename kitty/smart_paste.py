# ★ 8155 – schlaues Strg+V für kitty
#   Text in der Zwischenablage  → kitty fügt ihn ein
#   Bild in der Zwischenablage  → Strg+V geht ans Programm durch
#                                 (z. B. Claude Code fügt dann den Screenshot ein)
import subprocess

from kittens.tui.handler import result_handler
from kitty.clipboard import get_clipboard_string

PLAIN_TEXT = ("text/plain", "text/plain;charset=utf-8", "UTF8_STRING", "STRING", "TEXT")


def main(args):
    pass


def clipboard_types():
    try:
        out = subprocess.run(["wl-paste", "--list-types"], capture_output=True, text=True, timeout=1)
        return out.stdout.split()
    except Exception:
        return []


@result_handler(no_ui=True)
def handle_result(args, answer, target_window_id, boss):
    w = boss.window_id_map.get(target_window_id)
    if w is None:
        return
    types = clipboard_types()
    has_image = any(t.startswith("image/") for t in types)
    has_text = any(t in PLAIN_TEXT for t in types)
    if has_image and not has_text:
        w.send_key("ctrl+v")
        return
    try:
        text = subprocess.run(["wl-paste", "--no-newline", "--type", "text"],
                              capture_output=True, text=True, timeout=2).stdout
    except Exception:
        text = get_clipboard_string()
    if text:
        w.paste_with_actions(text)
