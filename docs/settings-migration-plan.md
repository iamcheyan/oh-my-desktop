# DMS → OMD Settings Center 迁移执行计划

## 核心原则
- **功能用 DMS 的**，布局结构也参考 DMS
- **样式用 OMD 的**（TuiStyle + common/widgets/）
- **有冲突的功能直接用 DMS 替换 OMD**
- **DMS 依赖 DMS daemon 的功能跳过**（Display gamma、wlr-output）
- **每个 service 替换后必须验证可运行**

## 当前状态
- OMD SettingsCenter 是单文件 1916 行，11 个页面，自定义 `cosmic*` 色板
- OMD 有 98 个 common/widgets/ 但 SettingsCenter 没用，自己重造了 SettingsCard/Button/Slider 等
- DMS 有 44 个设置 tab，成熟但耦合 DMS 架构

## 迁移批次

### 批次 0：基础设施 — Service 层移植 + widget 扩充
**目标**：把 DMS 的 service 功能移植到 OMD，扩充缺失的 widget

#### 0.1 Service 替换/扩展
| OMD Service | 动作 | 来源 |
|---|---|---|
| `Audio.qml` | 扩展：设备列表、默认设备切换、设备重命名(WirePlumber)、cycleAudioOutput、displayName | DMS AudioService |
| `Network.qml` | 扩展：WiFi 扫描结果增强、连接详情、信号强度、IP 地址、忘记网络 | DMS LegacyNetworkService 模式 |
| `BluetoothStatus.qml` | 扩展：设备连接/断开、配对、信号强度、设备图标分类 | DMS BluetoothService（去掉 DMS daemon 依赖） |
| `Battery.qml` | 扩展：电池健康、时间剩余、充电限制、蓝牙设备电池 | DMS BatteryService |
| `PowerProfiles.qml` | 保留现有，加 profileChanged signal | 已够用 |
| `Idle.qml` | 扩展：超时配置写入 hypridle.conf | DMS IdleService 模式 |
| `Notifications.qml` | 扩展：超时配置、规则、历史设置 | DMS NotificationService |
| `Hyprsunset.qml` | 保留，色温调节已够用 | — |

#### 0.2 Widget 扩充
需要新建的 OMD widget（参考 DMS 但用 TuiStyle）：
| Widget | 用途 | DMS 参考 |
|---|---|---|
| `SettingsDropdownRow` | 带标签的下拉行 | DMS SettingsDropdownRow |
| `SettingsSliderCard` | 卡片内滑块 | DMS SettingsSliderCard |
| `SettingsToggleCard` | 带展开内容的开关卡片 | DMS SettingsToggleCard |
| `SettingsButtonGroup` | 分段按钮组 | DMS SettingsButtonGroupRow |
| `SettingsTextField` | 带标签的文本输入行 | DMS DankTextField 封装 |

已有可复用的 OMD widget：
- `RippleButton` → 按钮
- `StyledSwitch` → 开关
- `StyledSlider` → 滑块
- `StyledComboBox` → 下拉
- `StyledTextInput` / `MaterialTextField` → 文本输入
- `TuiMeterBar` → 进度条
- `StyledFlickable` → 滚动
- `SelectionGroupButton` / `ButtonGroup` → 按钮组

---

### 批次 1：P0 功能页面（8个）
每个页面用 DMS 的功能逻辑 + OMD 的 TuiStyle 样式

#### 1.1 Audio 页面（替换现有 sound 页）
**DMS 来源**：`AudioTab.qml` + `AudioService.qml`
**功能**：
- 输出设备列表（设备名、别名、隐藏、每设备最大音量滑块）
- 输入设备列表（同上）
- 默认 sink/source 选择
- 设备重命名（写入 WirePlumber config → reload）
- WirePlumber reload 加载状态
**OMD Service 改动**：扩展 `Audio.qml` 加入 deviceAliases、setDeviceAlias、cycleAudioOutput、displayName

#### 1.2 Notifications 页面（替换现有 session 页的通知部分）
**DMS 来源**：`NotificationsTab.qml`
**功能**：
- 弹窗超时（低/普通/紧急）
- DnD 开关
- 通知规则（pattern/field/type/action）
- 静音应用列表
- 锁屏通知模式
- 历史设置（启用/最大数/保留天数/按优先级保存）

#### 1.3 OSD 页面（新增）
**DMS 来源**：`OSDTab.qml`
**功能**：
- OSD 位置（8选项）
- 始终显示百分比
- 每 OSD 类型开关（音量/媒体/亮度/idle/麦克风/caps lock/电源 profile/音频输出切换）

#### 1.4 Battery/Power 页面（替换现有 power 页）
**DMS 来源**：`BatteryTab.qml`
**功能**：
- 电池状态卡（电源来源/电量/状态/时间/健康）
- 电池保护卡（充电限制滑块 + 硬件应用 + 通知 + 低电量阈值 + 自动省电 + 临界阈值）
- 电源 profile 自动切换（AC/电池各选 profile）

#### 1.5 Idle/锁屏超时页面（新增到 power 页或独立）
**DMS 来源**：`PowerSleepTab.qml`
**功能**：
- AC/电池分别设超时（锁屏/关屏/关屏后锁/挂起）
- 淡出到锁屏/关屏
- 锁屏前挂起
- 挂起行为（suspend/hibernate/suspend-then-hibernate）

#### 1.6 Night Light 页面（替换现有 display 页的 night light 部分）
**DMS 来源**：`GammaControlTab.qml`（适配到 Hyprsunset）
**功能**：
- 夜间模式开关
- 色温滑块（夜间 2500-6000K，白天 2500-10000K）
- 自动控制（时间模式/位置模式）
- 时间模式：开始/结束时间
- 位置模式：IP 定位/手动坐标
- 当前状态显示（温度/时段/日出日落）

#### 1.7 WiFi 管理页面（替换现有 network 页）
**DMS 来源**：`NetworkWifiTab.qml`
**功能**：
- WiFi 开关 + 状态
- 可用网络列表（信号/锁/已保存/连接中）
- 连接/断开/忘记网络
- 已保存网络列表
- 信号强度 + IP 地址
- 网络详情（频率/信道/速率/BSSID/安全）

#### 1.8 Bluetooth 页面（替换现有 bluetooth 页）
**DMS 来源**：`BluetoothPairingModal.qml` + `BluetoothService.qml`
**功能**：
- 蓝牙开关 + 发现模式
- 设备列表（已连接/已配对/新设备）
- 连接/断开/配对
- 信号强度 + 设备图标
- 音频 codec 选择（pactl）

---

### 批次 2：P1 功能页面（按需）
- Display 配置（分辨率/刷新率/缩放）— 需要新建 WlrOutput 或 hyprctl 封装
- Autostart 管理
- Window Rules 编辑器
- 壁纸增强（每显示器/填充模式/循环）
- 音效设置
- 默认应用选择

---

## 执行顺序

1. **批次 0**：先建 widget + 扩展 service（这是所有页面的基础）
2. **批次 1.1-1.8**：逐页移植，每页完成后验证 bar 能加载
3. **批次 2**：按需进行

## 验证标准
每个页面完成后：
- `bash scripts/reload-quickshell` 成功
- `cat /tmp/omd-bar.log | grep ERROR` 无输出
- 打开 SettingsCenter → 对应页面 → 功能可操作