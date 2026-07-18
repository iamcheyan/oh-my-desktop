# Charmbracelet Bubbles Demo

展示 [Bubbles](https://github.com/charmbracelet/bubbles) 组件库中常用终端 UI 控件的演示程序。

## 运行

```sh
cd ~/development/OMD/docs/demo
go run .
```

需要终端支持 ANSI 颜色。推荐使用支持 Nerd Font 的终端（如 Kitty、Ghostty、Alacritty）以显示图标。

## 演示的控件

按数字键 1-9 切换页面：

| 页面 | 控件 |
|------|------|
| **1** | Text Input（文本输入框）、Password Input（密码输入）、Email Input、Number Input、Text Area（多行文本） |
| **2** | Buttons（按钮样式）、Status Indicators（状态指示器）、Badges/Pills（徽章）、Nerd Font Icons |
| **3** | Checkboxes（复选框）、Radio Buttons（单选按钮） |
| **4** | Toggle Switches（开关） |
| **5** | Progress Bar（进度条）、Spinner（加载动画） |
| **6** | File Picker（文件选择器） |
| **7** | List（可滚动列表） |
| **8** | Table（数据表格） |
| **9** | Viewport（可滚动内容区域） |

## 交互方式

- **Tab / Shift+Tab**: 在输入框页面切换焦点
- **Enter / Space**: 切换复选框/开关状态
- **↑ / ↓**: 在单选/开关列表中导航
- **↑ / ↓ / PgUp / PgDown**: 在列表/表格/视口中滚动
- **Ctrl+C**: 退出
