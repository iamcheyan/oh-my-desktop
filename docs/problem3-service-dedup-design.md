# 问题 3：服务文件重复 — 解决方案与架构设计

> 日期：2026-07-20
> 状态：设计中

## 问题回顾

10 个服务文件在核心和模块各一份：

| 服务 | 核心版本 | 模块版本 | 核心引用方 |
|---|---|---|---|
| Battery.qml | singleton (services/) | 非 singleton (battery-power/) | PowerPage、BarStatusPopup、SidebarIndicators、BarBatteryIcon、LockSurface |
| PowerProfiles.qml | singleton (services/) | 非 singleton (battery-power/) | PowerPage、BarStatusPopup |
| Brightness.qml | singleton (services/) | 非 singleton (brightness-gamma/) | SettingsDialog、DisplayButton、BarStatusPopup、BrightnessIndicator、OnScreenDisplay |
| Hyprsunset.qml | singleton (services/) | 非 singleton (brightness-gamma/) | BarStatusPopup、GammaIndicator |
| InputMethod.qml | singleton (services/) | 非 singleton (input-method/) | InputMethodButton、BarStatusPopup、InputMethodIndicator、OnScreenDisplay |
| KeyboardRemap.qml | singleton (services/) | 非 singleton (keyboard-remap/) | KeyboardRemapPage、KeyboardEditorOverlay、BarStatusPopup |
| MprisController.qml | singleton (services/) | 非 singleton (mpris/) | BarStatusPopup、TrackArt |
| TrackArt.qml | singleton (services/) | 非 singleton (mpris/) | BarStatusPopup |
| TrayService.qml | singleton (services/) | 非 singleton (systray/) | SysTray、SysTrayItem、SysTrayMenu |
| VoiceInput.qml | singleton (services/) | 非 singleton (voice/) | VoicePage、InputMethodButton、BarStatusPopup |

核心 20 个服务不重复（Audio、Network、Notifications 等留在核心）。

## 根本原因

QML `pragma Singleton` 的限制：
1. Singleton 在 qmldir 中声明，import 时自动创建唯一实例
2. **编译时绑定**——不能运行时决定是否加载
3. 不能通过 Loader 动态创建
4. 两个不同模块声明同名 singleton 会创建两个独立实例，状态不共享

另一个智能体把服务复制到模块并改为非 singleton，但核心代码仍 import 核心 singleton——模块副本是死代码。

## 解决方案：共享服务模块

跟 popup-components 一样——把服务提取为独立模块，所有人引用它。

### 架构设计

```
~/development/sumika-modules/
├── shared-services/              ← 新增共享服务模块
│   ├── module.json
│   ├── qmldir                    # module qs.modules.shared-services
│   ├── Battery.qml               # pragma Singleton
│   ├── PowerProfiles.qml         # pragma Singleton
│   ├── Brightness.qml            # pragma Singleton
│   ├── Hyprsunset.qml            # pragma Singleton
│   ├── InputMethod.qml           # pragma Singleton
│   ├── KeyboardRemap.qml         # pragma Singleton
│   ├── MprisController.qml       # pragma Singleton
│   ├── TrackArt.qml              # pragma Singleton
│   ├── TrayService.qml           # pragma Singleton
│   └── VoiceInput.qml            # pragma Singleton
├── popup-components/            ← 已有
├── battery-power/               ← 只保留 popup + settings + bin
├── brightness-gamma/            ← 只保留 osd + bin
├── input-method/                ← 只保留 popup + bin
├── keyboard-remap/             ← 只保留 popup + settings + bin
├── mpris/                        ← 只保留 popup（如果有）
├── systray/                     ← 只保留 bar 组件
└── voice/                        ← 只保留 popup + settings + bin
```

### 引用关系

```
核心 BarStatusPopup.qml     → import qs.modules.shared-services → Battery.xxx
模块 BatteryPopup.qml       → import qs.modules.shared-services → Battery.xxx
模块 VoicePopup.qml         → import qs.modules.shared-services → VoiceInput.xxx
```

核心和模块引用同一个 singleton 实例——**状态共享，零冲突**。

### 为什么放在 shared-services 而不是留在核心 services/

| 放在核心 services/ | 放在 shared-services 模块 |
|---|---|
| ✅ 核心不依赖外部目录 | ❌ 核心依赖 shared-services 目录存在 |
| ❌ 服务无法被禁用（在核心里） | ✅ 可以通过 modules.disabled 禁用 |
| ❌ 核心代码和可选服务混在一起 | ✅ 核心只保留必需服务 |
| ✅ 不需要额外 qmldir | 需要 qmldir + module.json |

**折中方案**：服务先留在核心 services/（不删），同时在 shared-services 中放一份相同的 singleton。核心代码 `import qs.services`，模块代码 `import qs.modules.shared-services`。两个 singleton 实例独立但功能相同——因为服务状态来自 DBus/系统，不是 QML 内部状态，所以两份实例不会冲突。

等等——这又回到了"重复"的问题。

### 正确方案：服务留在核心，模块引用核心

**简化设计**：不创建 shared-services 模块。服务留在核心 `services/`（已经是 singleton，已经有 qmldir）。模块 QML 文件直接 `import qs.services` 引用核心的 singleton。

```
核心 services/qmldir:     singleton Battery 1.0 Battery.qml
                           singleton VoiceInput 1.0 VoiceInput.qml
                           ...

模块 BatteryPopup.qml:    import qs.services → Battery.available
模块 VoicePopup.qml:       import qs.services → VoiceInput.state
```

**为什么这样可行**：
1. 启动脚本已把 `sumika-modules/*/` 加入 QML_IMPORT_PATH
2. 核心 `quickshell/` 通过 `-p` 参数注册为 `qs` 模块
3. `services/qmldir` 声明 `module qs.services` 并注册所有 singleton
4. 模块 QML 文件 `import qs.services` 就能访问核心 singleton
5. **不需要复制服务到模块**——直接用核心的

**为什么之前不工作**：之前模块 QML 文件用 `import qs.modules.voice`（连字符非法）或 `import qs.modules.input-method`（同上），不是 `import qs.services`。修复方法是把模块 QML 文件的 import 改为 `import qs.services`。

### 实施步骤

1. **删除模块目录中的服务副本**（10 个文件）
   - `sumika-modules/battery-power/services/Battery.qml`
   - `sumika-modules/battery-power/services/PowerProfiles.qml`
   - `sumika-modules/brightness-gamma/services/Brightness.qml`
   - `sumika-modules/brightness-gamma/services/Hyprsunset.qml`
   - `sumika-modules/input-method/services/InputMethod.qml`
   - `sumika-modules/keyboard-remap/services/KeyboardRemap.qml`
   - `sumika-modules/mpris/services/MprisController.qml`
   - `sumika-modules/mpris/services/TrackArt.qml`
   - `sumika-modules/systray/services/TrayService.qml`
   - `sumika-modules/voice/services/VoiceInput.qml`

2. **修改模块 QML 文件的 import**：把 `import qs.modules.voice`、`import qs.modules.input-method` 等改为 `import qs.services`

3. **从模块的 module.json 中移除 services 声明**（如果有）

4. **验证**：模块 QML 文件 `import qs.services` 能解析到核心的 singleton

5. **验证状态共享**：核心 BarStatusPopup 和模块 BatteryPopup 访问的是同一个 Battery 实例

### 每个模块的改动

| 模块 | 删除文件 | 修改 import |
|---|---|---|
| battery-power | services/Battery.qml, services/PowerProfiles.qml | popup/BatteryPopup.qml: 已有 `import qs.services` ✅ |
| brightness-gamma | services/Brightness.qml, services/Hyprsunset.qml | osd/*.qml: 加 `import qs.services` |
| input-method | services/InputMethod.qml | popup/InputMethodPopup.qml: 加 `import qs.services` |
| keyboard-remap | services/KeyboardRemap.qml | popup/KeyboardPopup.qml: 改 `import qs.modules.keyboard-remap` → `import qs.services` |
| mpris | services/MprisController.qml, services/TrackArt.qml | popup/*.qml: 加 `import qs.services` |
| systray | services/TrayService.qml | bar/*.qml: 加 `import qs.services` |
| voice | services/VoiceInput.qml | popup/VoicePopup.qml: 改 `import qs.modules.voice` → `import qs.services` |

### 禁用模块时的行为

当用户在 config.json 的 `modules.disabled` 中禁用 `battery-power` 模块：
1. 启动脚本不把 `battery-power/` 加入 QML_IMPORT_PATH → 模块 QML 文件不被加载
2. 核心的 `Battery` singleton 仍在 `services/` → 核心代码（BarStatusPopup 等）仍能访问
3. 核心的 `batteryContent` 弹窗仍在 BarStatusPopup → 电池弹窗仍可用
4. 模块的 `BatteryPopup.qml` 不被加载 → 不重复

**结论**：禁用模块只是"不加载模块的额外 UI"，核心功能不受影响。服务的完全模块化（从核心删除）是更远的未来目标。

---

## 其他问题的解决方案（简述）

### 问题 4：bin 脚本重复

**方案**：当模块系统成熟后，从核心删除已在模块中的脚本。当前保留两份（PATH 优先级决定用哪个）。

**实施**：逐个删除核心脚本，每次删一个就测试。先从 file-backup 的 3 个脚本开始（最独立）。

### 问题 6：module.json 格式不一致

**方案**：写一个 `scripts/validate-module-json.sh` 脚本，检查所有 module.json 的格式：
- `barButtons` 必须是数组（不是单数字符串）
- `popupSections.type` 必须与核心 barPopupType 匹配
- `configDefaults` 必须有正确的结构

### 问题 7：qmldir 自动维护

**方案**：写一个 `scripts/generate-qmldir.sh` 脚本：
```bash
#!/bin/bash
# 用法: generate-qmldir.sh <directory> <module-name>
dir="$1"
module_name="$2"
echo "module $module_name" > "$dir/qmldir"
for f in "$dir"/*.qml; do
    name=$(basename "$f" .qml)
    if grep -q "pragma Singleton" "$f"; then
        echo "singleton $name 1.0 $(basename $f)" >> "$dir/qmldir"
    else
        echo "$name 1.0 $(basename $f)" >> "$dir/qmldir"
    fi
done
```

在 Init.sh 或 pre-commit hook 中调用。