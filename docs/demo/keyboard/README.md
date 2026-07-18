# 108-Key Keyboard Layout Demo

用 Bubbletea + Lipgloss 渲染的 108 键键盘布局 TUI 程序。

## 运行

```sh
cd ~/development/OMD/docs/demo/keyboard
go run .
```

## 功能

- 完整 108 键布局：主键盘 + F键行 + 编辑键 + 小键盘 + 方向键
- 方向键/回车键导航
- 按 Enter/Space 切换按键"按下"状态（红色高亮）
- Tab 在主键盘和方向键区域之间切换
- 顶部实时显示当前按键的 key code

## 操作

| 按键 | 功能 |
|------|------|
| ← → ↑ ↓ / h j k l | 移动选择光标 |
| Tab | 在主键盘和方向键区域间切换 |
| Enter / Space | 切换当前按键的按下/弹起状态 |
| q / Ctrl+C | 退出 |

## 按键状态

- **紫色边框**: 当前选中的按键
- **红色背景**: 已"按下"的按键
- **灰色背景**: 普通状态
