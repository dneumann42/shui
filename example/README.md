# Shui Runtime Example: Counter (SDL3)

This example is configured to use the `uirelays` SDL3 backend via `example/counter.nims`.

Run:

```bash
nim c -r --path:src example/counter.nim
```

If your system does not have SDL3 development libraries installed, install them first
(for example `SDL3` and `SDL3_ttf` dev packages for your distro).

Notes:
- Uses `shui/uirelay_runtime` (non-headless mode).
- Click `-`, `reset`, or `+` to update the counter.
- Text rendering:
  - Runtime auto-detects common Linux fonts.
  - On Fedora with `dejavu-sans-fonts`, `/usr/share/fonts/dejavu-sans-fonts/DejaVuSans.ttf` is used.
  - You can force a font with `SHUI_FONT_PATH=/path/to/font.ttf`.
