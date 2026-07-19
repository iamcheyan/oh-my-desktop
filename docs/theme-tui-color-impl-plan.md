# Theme TUI Python — 颜色功能实现方案

目标文件：`/home/tetsuya/development/OMD/bin/omd-settings-theme-tui`

---

## 背景

原 Go 实现（`tui-go/internal/pages/theme/model.go`）有两个视觉功能在 Python 移植版里没有生效：

1. **壁纸像素预览** — 用 `▀` 半块字符渲染实际壁纸图片
2. **主题 tile 颜色 swatch** — 每个主题格子用该主题的 accent/bg/fg 颜色实际渲染

Python 文件里 `_render_image_preview()` 和 `_get_image_color_pair()` 的逻辑已经写好，
但 `_view()` 和 `_render_theme_grid()` 没有调用它们。

---

## 功能一：壁纸像素预览

### 现状问题

`_view()` 里渲染 Preview 框的代码（约第 612-614 行）：

```python
prev_lines = _render_preview(m, preview_w - 4, preview_h - 3)
for i, (tag, text) in enumerate(prev_lines):
    S.safe_addstr(stdscr, hero_h + 1 + i, 2, S.truncate(text, preview_w - 4), S.TAG_STYLE.get(tag, S.ATTR_TEXT))
```

`_render_preview()` 只返回文字行，没有像素图渲染。

### 实现方案

修改 `_view()` 中渲染 Preview 的部分，改为：

1. 先判断 wallpaper mode 是否为 `"color"`:
   - 若是 `"color"` 模式：保持原文字渲染逻辑（显示纯色块文字）
   - 若是 `"file"` 或 `"folder"` 模式：尝试像素图渲染

2. 像素图渲染流程：
   ```python
   inner_y = hero_h + 1        # Preview 框内起始行
   inner_x = 2                 # Preview 框内起始列（边框内 +1，padding +1）
   inner_w = preview_w - 4     # 去掉边框(2) + padding(2)
   inner_h = preview_h - 3     # 去掉边框(2) + 标题行(1)

   wp_path = m.val("wallpaper.current", "")
   # 展开 ~ 路径
   if wp_path.startswith("~/"):
       wp_path = os.path.expanduser(wp_path)

   rows = _render_image_preview(wp_path, inner_w, inner_h)
   if rows:
       _render_image_view(stdscr, inner_y, inner_x, rows)
   else:
       # fallback：显示文件名占位符
       fname = os.path.basename(wp_path) if wp_path else "No wallpaper"
       S.safe_addstr(stdscr, inner_y, inner_x, S.truncate(fname, inner_w), S.ATTR_MUTED)
   ```

3. `_render_image_view()` 已经实现（第 176-187 行），不需要修改。

### 依赖条件

- 需要 `PIL`（Pillow）已安装：`python3 -c "from PIL import Image"` 验证
- 当前壁纸路径从 `m.val("wallpaper.current", "")` 获取，值例如 `~/development/OMD/current/wallpaper`
- 支持格式：JPEG、PNG、WebP（PIL 原生支持）

---

## 功能二：主题 tile 颜色 swatch

### 现状问题

`_render_theme_grid()` 里把每一行都拼成 `(「"grid"」, line_text)` 返回，
由 `_view()` 统一用 `S.TAG_STYLE["grid"]` 渲染，**所有 tile 颜色相同**。

```python
lines.append(("grid", line_text))
```

这样无法为不同 tile 指定不同颜色。

### 实现方案

方案：把 `_render_theme_grid()` 的返回格式从「文字行列表」改为「带颜色信息的 cell 列表」，
然后在 `_view()` 里逐 cell 渲染。

#### 步骤一：新增辅助函数 `_get_theme_tile_pair()`

```python
def _get_theme_tile_pair(accent_hex, bg_hex, fg_hex, role):
    """
    为主题 tile 的某个角色（'header' or 'sample'）分配 curses color pair。
    role='header': fg=fg_hex on bg=accent_hex
    role='sample': fg=fg_hex on bg=bg_hex
    返回 curses color pair index，失败返回 0。
    """
    if role == "header":
        fg_h, bg_h = fg_hex, accent_hex
    else:
        fg_h, bg_h = fg_hex, bg_hex

    fg_rgb = _hex_to_rgb(fg_h)
    bg_rgb = _hex_to_rgb(bg_h)
    if not fg_rgb or not bg_rgb:
        return 0
    return _get_image_color_pair(fg_rgb[0], fg_rgb[1], fg_rgb[2],
                                  bg_rgb[0], bg_rgb[1], bg_rgb[2])
```

#### 步骤二：修改 `_render_theme_grid()` 返回格式

将返回类型从 `list[(tag, text)]` 改为 `list[row_spec]`，其中：

- 普通文字行保持 `("text_tag", text_str)` 格式不变（section/muted/text）
- 主题 tile 行改为 `("tile_row", cells)` 格式，cells 是列表，每个 cell 为：
  ```python
  {
    "text": str,           # 显示文字
    "pair": int,           # curses color pair index（0 = 默认）
    "width": int,          # 字符宽度
    "bold": bool,          # 是否加粗
  }
  ```

具体改动（替换现有 `for sub_row in range(5):` 块）：

```python
for row in range(start_row, end_row):
    # 每行 5 个 sub_row，拼成 cells 列表
    for sub_row in range(5):
        cells = []
        for col in range(cols):
            idx = row * cols + col
            if idx >= len(model.themes):
                cells.append({"text": " " * (tw + 2), "pair": 0, "width": tw + 2, "bold": False})
                continue
            theme = model.themes[idx]
            is_selected = (idx == model.selected)

            accent = theme.accent or "#444444"
            bg     = theme.background or "#111111"
            fg     = theme.foreground or "#eeeeee"

            if sub_row == 0:
                # Header: accent 背景，fg 前景
                marker = "▶" if is_selected else ("*" if theme.current else " ")
                text = (marker + " " + " " * tw)[:tw]
                pair = _get_theme_tile_pair(accent, bg, fg, "header")
                bold = is_selected
            elif sub_row == 1:
                # Sample: bg 背景，fg 前景
                text = ("Ag" + " " * tw)[:tw]
                pair = _get_theme_tile_pair(accent, bg, fg, "sample")
                bold = False
            elif sub_row == 2:
                # 主题名：默认颜色
                text = S.truncate(theme.name, tw).ljust(tw)
                pair = 0
                bold = is_selected
            elif sub_row == 3:
                text = "─" * tw
                pair = 0
                bold = False
            else:
                text = " " * tw
                pair = 0
                bold = False

            cells.append({"text": text, "pair": pair, "width": tw, "bold": bold})
            # gap between tiles
            if col < cols - 1:
                cells.append({"text": "  ", "pair": 0, "width": 2, "bold": False})

        lines.append(("tile_row", cells))
```

#### 步骤三：修改 `_view()` 里的 grid 渲染

把原来的：
```python
for i, (tag, text) in enumerate(grid_lines):
    if i >= avail_h - 4:
        break
    S.safe_addstr(stdscr, hero_h + 1 + i, preview_w + 3, ...)
```

改为处理两种格式：

```python
for i, item in enumerate(grid_lines):
    if i >= avail_h - 4:
        break
    tag = item[0]
    if tag == "tile_row":
        cells = item[1]
        cur_x = grid_start_x   # 即原来的 preview_w + 3 或 2
        for cell in cells:
            attr = curses.color_pair(cell["pair"])
            if cell["bold"]:
                attr |= curses.A_BOLD
            S.safe_addstr(stdscr, hero_h + 1 + i, cur_x, cell["text"], attr)
            cur_x += cell["width"]
    else:
        text = item[1]
        S.safe_addstr(stdscr, hero_h + 1 + i, grid_start_x,
                      S.truncate(text, grid_w_available), S.TAG_STYLE.get(tag, S.ATTR_TEXT))
```

`grid_start_x` 在 show_right 分支里是 `preview_w + 3`，在单列分支里是 `2`。
`grid_w_available` 对应是 `grid_w - preview_w - 4` 或 `content_w - 4`。

**注意**：single-column 分支里也有同样的 grid 渲染代码，需要同步修改。

---

## 注意事项

1. **Color pair 数量限制**：curses 最多 256 个 color pair（终端依赖）。
   `_get_image_color_pair()` 已经做了 5 阶量化 + 数量上限控制（`_MAX_COLOR_PAIRS = 200`）。
   主题 tile 的颜色使用同一套 pair 池，不超限。

2. **PIL 不可用时的 fallback**：`_render_image_preview()` 在 `ImportError` 时返回 `[]`，
   代码要判断 `if rows:` 再调用 `_render_image_view()`，否则走文字 fallback。

3. **terminfo COLORS 检查**：`_get_image_color_pair()` 里已经检查 `curses.COLORS < 256`
   时返回默认 pair，主题颜色 swatch 也受此保护，256 色以下终端自动降级为默认色。

4. **不要修改 `_render_image_preview()` 和 `_render_image_view()`** — 这两个函数逻辑正确，
   只需在 `_view()` 里正确调用它们。

5. **共享库 `omd_tui_shared.py`** 不需要修改。

---

## 验证方法

```bash
# 1. 检查 PIL 可用
python3 -c "from PIL import Image; print('PIL OK')"

# 2. 运行 TUI
~/.config/omd/bin/omd-settings-theme-tui

# 3. 预期效果：
#    - Preview 框内应显示当前壁纸的像素渲染（▀ 字符，有颜色）
#    - 主题列表每个 tile 的第一行应有 accent 色背景
#    - tile 第二行 "Ag" 应有该主题的 bg/fg 颜色
```
