# Terminal TUI Color Mapping

This document describes how Sumika Shell maps wallpaper and theme RGB colors
to xterm-256 colors. The implementation is used by
`bin/omd-settings-theme-tui` and the shared Python TUI helpers.

## Palette Constraints

xterm-256 contains three relevant ranges:

- `0-15`: terminal-defined base colors; their RGB values vary by theme.
- `16-231`: a stable 6 x 6 x 6 RGB cube.
- `232-255`: a stable 24-step grayscale ramp.

Generated previews avoid relying on `0-15`, because those colors are not
portable between terminal themes.

## Theme Preview Mapping

`bin/omd-settings-theme-tui::_rgb_to_xterm_index()` uses a chroma-aware direct
mapping:

1. Compute `chroma = max(r, g, b) - min(r, g, b)`.
2. If chroma is at most `12`, map the pixel to the grayscale ramp.
3. Otherwise quantize each channel into the 6-level RGB cube.
4. If quantization collapses a visibly dominant channel, raise that channel by
   one cube step where possible. This preserves the original hue.
5. Cache the result by RGB tuple.

This avoids the grayscale-attraction problem produced by globally searching
for the mathematically nearest xterm color. Dark greens, blues, and reds keep
their hue instead of collapsing to gray, while genuinely neutral pixels still
use the finer grayscale ramp.

## Shared Nearest-Color Mapping

`bin/omd_tui_framework.py::_nearest_xterm_index()` is the general-purpose mapper
for shared TUI drawing. It uses a perceptual redmean distance and handles
saturated colors separately so they are not incorrectly mapped to grayscale.

Use the shared mapper for ordinary widgets. The theme preview keeps its local
mapper because image previews need deterministic, fast per-pixel quantization
and explicit hue preservation.

## Performance

Both paths cache RGB-to-index results. Wallpaper previews contain many repeated
or quantized colors, so the expensive work is performed once per unique RGB
value rather than once per rendered cell.

## Maintenance Rules

- Keep the neutral-color threshold explicit and documented.
- Do not search terminal-defined colors `0-15` for generated previews.
- Preserve real grayscale pixels; do not force every pixel into the RGB cube.
- Test changes with dark foliage, blue sky, warm highlights, skin tones, and
  neutral shadows.
- Compare the preview with the source image before changing thresholds.
