# 调查任务：omp 在 bracketed paste 时重复插入 Wayland 剪贴板内容

> 这是一份**交接给低成本模型**的调查文档。请按文末"给调查模型的指令"执行，
> 把结论回填到本文档的"调查结论"一节，并附上关键源码行号/链接。

## 一句话现状

OMD 的语音输入和剪贴板程序往 omp 里粘贴时会**重复粘贴两次**。已经定位到根因
和一处可用修复，但当前修复"发送前清空剪贴板、发送后恢复"不够优雅。本任务是
寻找**更优雅**的方案，优先从 omp 源码里找根因解释或开关。

---

## 1. 环境

- OMD 仓库：`~/development/OMD`（Hyprland + Quickshell 桌面配置）
- omp 安装路径：`~/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/`
  - **源码就在包里**（非 minified）：`~/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/src/`
  - omp 版本：`17.0.5`
  - 上游仓库：`https://github.com/can1357/oh-my-pi`，包路径 `packages/coding-agent`
  - omp 是 `@oh-my-pi/pi-coding-agent`，TUI 部分依赖 `@oh-my-pi/pi-tui`（源码在
    `~/.bun/install/global/node_modules/@oh-my-pi/pi-tui/src/`）
- 终端：kitty（`kitty 0.47.1`），用户在 tmux 里跑 omp（`tmux 3.6b`）
- omp 通过 `bun ~/.bun/bin/omp` 启动
- Wayland 合成器：Hyprland

## 2. 已确认的根因（empirical，已反复复现）

**omp 在每次收到 bracketed paste 时，除了插入粘贴内容，还会把 Wayland 剪贴板的
内容再插一遍。**

关键实验（在全新 omp 窗口里）：
- 把 Wayland 剪贴板设成 `UNIQA_CLIP_12345`（`printf 'UNIQA_CLIP_12345' | wl-copy`）
- 用 `kitty @ send-text --from-file <file> --bracketed-paste enable` 发送文件内容
  `UNIQB_FILE_67890`
- omp 输入框结果：`UNIQB_FILE_67890UNIQA_CLIP_12345`（payload + 剪贴板，两份）

对照实验：
- 同样操作发给 **bash**（也启用 bracketed paste）：bash 只收到 `UNIQB_FILE_67890`，
  **没有**剪贴板内容。→ 所以**不是 kitty 的行为，是 omp 的行为**。
- omp 在 tmux 里和 tmux 外**都**重复。→ **不是 tmux 的行为**。

## 3. 已确认的触发条件（关键！）

重复**只在发送 bracketed paste 标记时**发生，与剪贴板内容是否等于 payload 无关：

| `kitty @ send-text` 的 `--bracketed-paste` 值 | 是否发送 `\e[200~...\e[201~` 标记 | omp 是否重复插入剪贴板 |
|---|---|---|
| `enable`（强制带标记） | 是 | **是**（payload + 剪贴板） |
| `auto`（程序启用了 bracketed paste 就带标记） | 是（omp 启用了） | **是** |
| `disable`（原始字节，无标记） | 否 | **否**（只有 payload） |

`--bracketed-paste` 只有这三个合法值（`disable` / `auto` / `enable`），见
`kitty @ send-text --help`。

**推论**：omp 启用了 kitty 的 **OSC 5522 enhanced paste**（omp 源码
`terminal.ts` 关闭时会发 `\x1b[?5522l`）。带 bracketed paste 标记的 send-text
会触发 kitty 走 enhanced paste 协议，把**剪贴板内容**也一并推给 omp。用
`disable`（不带标记）就不会触发 enhanced paste。

## 4. OMD 的粘贴流程（为什么会撞上这个）

所有程序化粘贴都走中央脚本 `share/bin/omarchy-paste-at-cursor`。调用方在调用前
都会先 `wl-copy < payload` 把 Wayland 剪贴板同步成 payload（设计意图：剪贴板和
粘贴内容保持一致）。

- 语音：`quickshell/services/VoiceInput.qml` 的 `onTranscriptionResult` →
  `wl-copy < payload && OMD_PASTE_SOURCE=voice omd-paste-at-cursor --file "$payload" auto kitty address:...`
- 剪贴板程序：`apps/omd-clipboard/services/Cliphist.qml` 的 `paste()` →
  `wl-copy < payload && OMD_PASTE_SOURCE=clipboard omd-paste-at-cursor --file "$payload" auto`

所以粘贴瞬间：剪贴板 = payload，omp 收到 bracketed paste（payload）+ enhanced
paste 推送的剪贴板（payload）= **payload 贴两遍**。

helper 走 kitty 分支时用的是 `kitty @ send-text --match id:$win_id --from-file
"$PAYLOAD_FILE" --bracketed-paste auto`（`share/bin/omarchy-paste-at-cursor`
里 `paste_kitty_remote` → `send_to_kitty`）。

## 5. 我在 omp 源码里已经看到的关键位置（省得你重新找）

### 5.1 bracketed paste 的编辑器层处理（**这里没有读剪贴板**）

`src/modes/components/custom-editor.ts` 的 `handleInput`（约 728–756 行）：
```ts
const paste = this.#pasteHandler.process(data);   // BracketedPasteHandler
if (paste.handled) {
    if (paste.pasteContent === undefined) return;   // 还在缓冲，等结束标记
    const content = paste.pasteContent;
    if (remaining.length > 0) this.#pendingInput.push(remaining);
    if (content.length === 0 && this.onPasteImage) {
        this.#trackAsyncPaste(Promise.resolve(this.onPasteImage()));  // 空 paste → 读剪贴板
        return;
    }
    const imagePaths = extractImagePastePathsFromText(content);
    if (imagePaths && this.onPasteImagePath) {
        this.#trackAsyncPaste((async () => {
            for (const p of imagePaths) await this.onPasteImagePath?.(p);
        })());
        return;
    }
    this.pasteText(content);   // ← 非空普通文本：只插入内容，没读剪贴板
    ...
}
```
注释明确写了：空 paste → `onPasteImage`；图片路径 → `onPasteImagePath`；其它 →
`pasteText(content)`。

**矛盾点**：实验里 omp 对**非空**普通文本 payload 也插入了剪贴板内容，但这里的
`pasteText(content)` 并不读剪贴板。所以"插入剪贴板"这件事**不在这个编辑器分支**，
而是在更上游 —— 怀疑是 enhanced paste（OSC 5522）路径在 `custom-editor.handleInput`
**之前**就把剪贴板内容作为一次独立的 `pasteText` 注入了。需要你顺着
`EnhancedPasteController` 把这条链补完。

### 5.2 Enhanced paste（OSC 5522）—— 头号嫌疑

`src/utils/enhanced-paste.ts`：
- `enable()` 发 `\x1b[?5522h`（开启 enhanced paste）
- `handleInput(data)` 解析 `\x1b]5522;...` 包，处理 `type=read` 请求
- `#handleDone()`：读到文本就 `this.#handlers.pasteText(bytes.toString("utf8"))`
  —— **这里会把剪贴板文本作为一次 `pasteText` 注入编辑器**

在 `src/modes/controllers/input-controller.ts` 里：
- 约 173 行：`#enhancedPaste?: EnhancedPasteController;`
- 约 561–588 行：`this.#enhancedPaste = new EnhancedPasteController({...})`，
  `this.ctx.ui.addInputListener(data => (this.#enhancedPaste?.handleInput(data) ? { consume: true } : undefined))`
- 注入文本的 handler（约 566 行）："Route enhanced-paste text to the currently
  focused component"

**待查**：enhanced paste 的 OSC 5522 包是 kitty 在**每次** bracketed paste 时都会
发的吗？还是只在用户真实 Ctrl+V 时发？如果是前者，就解释了为什么带标记的
send-text 会触发剪贴板注入。请通读 `enhanced-paste.ts` 全文 + `input-controller.ts`
里 `EnhancedPasteController` 的接入处（约 555–595 行），把触发链画清楚。

### 5.3 stdin 层（StdinBuffer / ProcessTerminal）

`@oh-my-pi/pi-tui/src/terminal.ts`（约 1043–1047 行）：
```ts
// Re-wrap paste content with bracketed paste markers for existing editor handling
this.#stdinBuffer.on("paste", (content: string) => {
    if (this.#inputHandler) {
        this.#inputHandler(`\x1b[200~${content}\x1b[201~`);
    }
});
```
`@oh-my-pi/pi-tui/src/stdin-buffer.ts` 的 `process()` 负责 bracketed paste 缓冲，收
到完整 paste 就 `emit("paste", pastedContent)`。这里**不读剪贴板**。

`terminal.ts` 启动时发 `\x1b[?2004h`（开 bracketed paste）和（在
`EnhancedPasteController.enable()` 里）`\x1b[?5522h`（开 enhanced paste）。

### 5.4 `handleImagePaste`（Ctrl+V / 空 paste 的路径，确认会读剪贴板文本）

`src/modes/controllers/input-controller.ts` 约 1559 行起：
```ts
async handleImagePaste(): Promise<boolean> {
    const image = await this.clipboard.readImage(); if (image) return ...;
    const fileUrls = (await this.clipboard.readMacFileUrls?.()) ?? []; ...;
    const text = await this.clipboard.readText();            // ← 读 Wayland 剪贴板文本
    if (!text) { this.ctx.showStatus("Clipboard is empty"); return false; }
    const imagePath = extractImagePathFromText(text);
    if (imagePath) { await this.handleImagePathPaste(imagePath); return true; }
    const focused = this.ctx.ui.getFocused();
    const target = focused && focused !== this.ctx.editor && hasPasteText(focused) ? focused : this.ctx.editor;
    target.pasteText(text);                                  // ← 把剪贴板文本插进编辑器
    ...
}
```
注释里提到 "Smart paste (#1628)"、"#2127"、"host that pre-empt the terminal's own
paste (VS Code integrated terminal, Win+V)"。**强烈建议把这些 issue 号拿到
omp 上游仓库（`github.com/can1357/oh-my-pi`）和 CHANGELOG.md
（`~/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/CHANGELOG.md`）
里搜**，看作者怎么描述这套行为、是不是已知、有没有配置开关。

## 6. 已经排除的假设（别再花时间）

- ❌ 不是 `kitty @ send-text --match state:focused` 多窗口投递（那个是另一个 bug，
  我已用 `--match id:$win_id` 修掉，见 `share/bin/omarchy-paste-at-cursor` 的
  `resolve_kitty_window_id`）。和本次双贴无关。
- ❌ 不是 tmux（tmux 外的 omp 也重复）。
- ❌ 不是 kitty `send-text` 把剪贴板塞进 file 内容（bash 对照实验没有剪贴板内容）。
- ❌ 不是 OMD 的去重逻辑（helper 一次调用只 `inject` 一次；事件日志
  `$XDG_RUNTIME_DIR/omd-paste/events.log` 确认）。
- ❌ 不是 `wl-copy` 本身触发（不 wl-copy、只设剪贴板内容后用 send-text，omp 仍重复）。

## 7. 当前可用的修复（在位，但用户觉得不优雅）

`share/bin/omarchy-paste-at-cursor` 的 `send_to_kitty()`：
1. `send-text` 前 `wl-copy -c` 清空 Wayland 剪贴板（omp 读到的就是空，enhanced
   paste 推送空 → 不追加）
2. `send-text` 后 `sleep 0.05; wl-copy < "$PAYLOAD_FILE"` 恢复剪贴板为 payload
   （保持剪贴板同步）
3. 即使 send 失败也恢复，避免留下空剪贴板

实测 10 次危险场景（剪贴板=payload）0 次双贴、剪贴板每次都同步。

**不优雅的点**：
- 临时清空剪贴板，会触发 `omd-clipboard-store`（`bin/omd-clipboard-store`，一个
  `wl-paste --watch` 守护进程）多跑一次（清空被拒、恢复时再 store 一次）
- 短暂的"剪贴板空"窗口，别的应用若此刻读剪贴板会读到空
- 如果 helper 在 clear 和 restore 之间异常退出，剪贴板会留在空状态（已用
  "always restore" 缓解）
- 本质是在和 omp 的行为打补丁，治标

## 8. 复现方法（供调查模型验证）

```sh
# 1. 开一个全新 omp 窗口（避免输入框有残留）
kitty @ --to unix:/tmp/mykitty-<PID> launch --type=window --title=probe omp
# 等 ~2s，记下它的 kitty window id（用 kitty @ ... ls 看）
WID=<那个 id>
kitty @ --to unix:/tmp/mykitty-<PID> focus-window --match id:$WID

# 2. 剪贴板设成 A，文件内容设成 B
printf 'CLIP_A' | wl-copy
printf 'FILE_B' > /tmp/p.txt

# 3. 带标记发送（复现双贴）
kitty @ --to unix:/tmp/mykitty-<PID> send-text --match id:$WID \
    --from-file /tmp/p.txt --bracketed-paste enable
sleep 0.6
kitty @ --to unix:/tmp/mykitty-<PID> get-text --match id:$WID | grep -c CLIP_A   # 期望看到 1（说明剪贴板被注入了）

# 4. 对照：不带标记（不双贴）
kitty @ --to unix:/tmp/mykitty-<PID> send-text --match id:$WID $'\x1b' 2>/dev/null  # 清输入
printf 'CLIP_C' | wl-copy
printf 'FILE_D' > /tmp/p2.txt
kitty @ --to unix:/tmp/mykitty-<PID> send-text --match id:$WID \
    --from-file /tmp/p2.txt --bracketed-paste disable
sleep 0.6
kitty @ --to unix:/tmp/mykitty-<PID> get-text --match id:$WID | grep -c CLIP_C   # 期望 0
```
> 注意：`get-text` 对长行会自动折行，grep 计数可能偏低；用短标记串更准。omp 的
> 输入框用 `╰─ ... ─╯` 包着，可以 `sed -n '/╰─/,/─╯/p'` 取出来再看。omp 输入框
> 用 Escape(`$'\x1b'`) 可以清空（不是 Ctrl+U）。

## 9. 需要调查的三个方向

### 方向 A：搞清楚 omp 为什么这么做（源码层面）

顺着 `EnhancedPasteController`（`src/utils/enhanced-paste.ts`）和它在
`input-controller.ts`（约 555–595 行）的接入处，回答：
1. OSC 5522 的 `type=read` 包是 kitty 在**每次**带标记的 bracketed paste 时都会
   发的，还是只在用户真实 Ctrl+V 时发？（决定带标记的 `send-text` 是否必然触发
   剪贴板注入）
2. enhanced paste 注入文本的 handler（约 566 行）和 `custom-editor.handleInput` 的
   `pasteText(content)` 是**两次独立插入**吗？这就是双贴的直接来源吗？
3. 读 `CHANGELOG.md` 里搜 `enhanced paste`、`OSC 5522`、`#1628`、`#2127`、
   `smart paste`、`bracketed paste`，看作者的设计意图和有没有提到"程序化粘贴"
   的场景。
4. 上游仓库 `github.com/can1357/oh-my-pi` 的 issues / PR 搜 `paste twice`、
   `double paste`、`enhanced paste`、`OSC 5522`、`send-text`，看有没有人报告过
   同样问题、作者怎么回应。

### 方向 B：找 omp 的开关/设置/环境变量来关掉这个行为

重点查：
1. `src/config/settings-schema.ts` 里所有 paste 相关项（已知有
   `paste.largeMenuThreshold`）。有没有 `enhancedPaste` / `smartPaste` /
   `clipboardPaste` / `paste.enhanced` 之类的布尔开关？
2. `src/config/keybindings.ts` 里 `app.clipboard.pasteImage`（默认 Ctrl+V）和
   `app.clipboard.pasteTextRaw`（默认 Ctrl+Shift+V）。能不能改键绑定绕开？不行——
   问题不在键绑定，在 enhanced paste 协议。但确认一下 enhanced paste 是不是被
   `app.clipboard.pasteImage` 这个动作驱动的。
3. 环境变量：grep 源码里 `process.env` / `$env` 搜 `5522`、`ENHANCED_PASTE`、
   `PASTE`、`OMP_`、`PI_`、`NO_ENHANCED`。有没有禁用 enhanced paste 的 env 开关？
4. omp 的 `~/.omp/` 配置目录（如果存在）和 `omp --help` / `omp config` 看有没有
   相关项。

### 方向 C：如果 A、B 都没结论，往哪个方向修（要考虑行业通用性）

前提：enhanced paste / smart paste 不是 omp 独有，**kitty 自己、WezTerm、其它
OSC-5522 支持的终端**也可能有类似"bracketed paste 同时读剪贴板"的行为。所以
OMD 的修复要尽量不假设"只有 omp 这样"。

候选方向（按优雅度排序，请评估每个的权衡）：

1. **`--bracketed-paste disable`（原始字节发送）**
   - 优点：不带标记 → 不触发 enhanced paste → 不双贴；不需要任何剪贴板操作；
     多行内容实测会作为多行插入 omp 输入框（不会触发提交）。
   - 缺点/风险：原始字节会被 omp 当作**按键**逐个解析。若 payload 含控制字符
     （`\x03` Ctrl+C、`\x04`、`\x1a`、`\x1b` ESC 等），可能被解释成快捷键/转义
     序列。语音转写（纯文本）安全；剪贴板条目**可能**含控制字符（罕见但存在，
     例如有人复制了带 ANSI 颜色码的终端输出）。需要评估这个风险多大、能不能
     接受，或者能不能"payload 无控制字符时用 disable，有时回退到带标记+清空"。

2. **空 bracketed paste + 剪贴板=payload（让 omp 的 smart paste 自己拉）**
   - 调用方已经 `wl-copy < payload`。helper 改成发一个**空**文件的 bracketed
     paste，omp 的空 paste → `onPasteImage` → `handleImagePaste` → 读剪贴板文本
     → 插入一次。实测**单次成功**，剪贴板保持同步。
   - 优点：完全顺势而为，不发 payload 字节，不操作剪贴板，多行/特殊字符都由
     omp 自己从剪贴板读（安全）。
   - 缺点：**只对支持 smart-paste 的程序（omp）有效**。对普通 bash kitty 窗口，
     空 bracketed paste = 什么也不插入 → 粘贴失败。需要能区分目标是不是
     smart-paste 程序（`kitty @ ls` 的 `cmdline`/`foreground_processes` 能看到
     `omp`，但不可靠，别的 TUI 也可能这样）。可考虑"先空 paste 试，检测到没
     插入再回退发内容"——但检测"没插入"很难。

3. **保留当前清空+恢复方案**（已实现，治标但稳）
   - 通用（对 omp 和非 omp 都安全）、对任意 payload 安全（带标记）。
   - 不优雅的副作用见第 7 节。

4. **检测并禁用 omp 的 enhanced paste**（如果方向 B 找到开关）
   - 最优雅：在 omp 配置/环境里关掉 enhanced paste，helper 继续用带标记的
     send-text，安全且无副作用。但属于"改 omp 行为"，且只在 omp 生效。

请对 1、2 给出**明确推荐或否决理由**；如果方向 B 找到开关，优先推荐 4。

## 10. 给调查模型的指令

1. 不要重新做环境搭建。omp 源码就在
   `~/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/src/`，
   pi-tui 源码在 `~/.bun/install/global/node_modules/@oh-my-pi/pi-tui/src/`，
   CHANGELOG 在 `~/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/CHANGELOG.md`。
2. 按方向 A → B → C 顺序查。A、B 是源码/grep/读 CHANGELOG/看上游 issue 的活，
   用 `grep -rn` / `read` 即可，不要乱跑实验（实验我已经做完了，结论在第 2、3、5 节）。
3. 关键回答这几个问题（逐条给结论 + 证据行号/链接）：
   - Q1：带标记的 `kitty @ send-text` 是否**必然**触发 omp 的 enhanced paste
     剪贴板注入？触发链是什么？
   - Q2：omp 有没有配置项/环境变量/键绑定能关掉 enhanced paste 或这个剪贴板注入？
     （方向 B）
   - Q3：上游有没有人报告过同样的双贴问题？作者怎么说？
   - Q4：方向 C 的方案 1（原始字节）和方案 2（空 paste + smart paste），哪个更值得
     做？控制字符风险有多大、能不能规避？
4. 不要改 `share/bin/omarchy-paste-at-cursor` 或任何运行文件。只读、只调查。
5. 把结论填到下面的"调查结论"一节，附上关键源码行号和（如果用到的）上游 issue 链接。

## 11. 调查结论

### Q1：带标记的 `kitty @ send-text` 是否必然触发 omp 的 enhanced paste 剪贴板注入？触发链是什么？

**是。** 触发链：

**前置状态**（omp 启动时建立）：
- `terminal.ts:1372` 发 `\x1b[?2004h` 启用 bracketed paste
- `EnhancedPasteController.enable()`（`enhanced-paste.ts:92`）发 `\x1b[?5522h` 启用 OSC 5522 enhanced paste
- `input-controller.ts:588` 注册输入监听：`addInputListener(data => this.#enhancedPaste?.handleInput(data))`

**send-text 触发时**：
1. `kitty @ send-text --bracketed-paste enable/auto` 向 PTY 写入 `\x1b[200~FILE_B\x1b[201~`
2. kitty 因终端已启用 `\x1b[?5522h`，额外向 PTY 发送 OSC 5522 包（`\x1b]5522;type=read:status=OK;…\x1b\\` 系列），携带剪贴板内容
3. omp 的 `StdinBuffer`（`stdin-buffer.ts:479-509`）检测到 bracketed paste 标记，剥离后 emit `"paste"` 事件
4. `terminal.ts:1045-1047` 重新包装为 `\x1b[200~FILE_B\x1b[201~` 并调用 `#inputHandler`
5. `TUI.#handleInput`（`tui.ts:2359`）先过 input listeners，EnhancedPasteController 判断非 OSC 5522 → 不消费
6. 数据到达 `CustomEditor.handleInput`（`custom-editor.ts:733-755`），检测 bracketed paste 标记 → `this.pasteText("FILE_B")` → **第一次插入**
7. 同一批 PTY 写入中的 OSC 5522 包经 `StdinBuffer` 作为普通 `"data"` 事件发出 → `terminal.ts:1038-1040` → `#inputHandler` → `TUI.#handleInput`
8. `EnhancedPasteController.handleInput`（`enhanced-paste.ts:100-105`）识别 OSC 5522 包，启动多步协议（listing → request → data chunk → done）
9. `#handleDone()`（`enhanced-paste.ts:178-200`）：`this.#handlers.pasteText(clipboard内容)` → handler（`input-controller.ts:565-575`）调用 `target.pasteText(clipboard)` → **第二次插入**

两次独立 `pasteText` 调用构成了双贴。不带标记（`--bracketed-paste disable`）不发 bracketed paste → kitty 不触发 OSC 5522 → 无双贴。

### Q2：omp 有没有配置项/环境变量/键绑定能关掉 enhanced paste 或剪贴板注入？

**没有可用的关闭手段。** 具体查证结果：

- **settings-schema.ts**：仅有的 paste 相关设置是 `paste.largeMenuThreshold`（行 1624），控制大粘贴时显示菜单的行数阈值。无 `enhancedPaste` / `smartPaste` / `clipboardPaste` 等开关。
- **环境变量**：grep 全量 `process.env` 引用，无 `OMP_ENHANCED_PASTE`、`PI_5522`、`KITTY_PASTE` 或类似变量。`PI_COMPILED`、`OMP_PROFILE`、`PI_PACKAGE_DIR` 等均为打包/配置路径，与 paste 无关。
- **键绑定**：`app.clipboard.pasteImage`（Ctrl+V）和 `app.clipboard.pasteTextRaw`（Ctrl+Shift+V）存在，但它们是**用户按键**路径。双贴问题在 OSC 5522 协议注入，改键绑定不影响。
- **运行时关闭**：`EnhancedPasteController.disable()`（`enhanced-paste.ts:95-98`）会发 `\x1b[?5522l`，但 `input-controller.ts` 中**从未调用**。唯一发 `\x1b[?5522l` 的地方是 `terminal.ts:1373`（仅终端 stop/cleanup 时）。
- **配置文件**：`~/.omp/` 目录的 config 由 `settings-schema.ts` 定义，不含 paste 增强项。

**结论**：要关掉 enhanced paste 需要改 omp 源码，在 `#setupEnhancedPaste()`（`input-controller.ts:560`）中加条件判断或暴露设置项。

### Q3：上游有没有人报告过同样的双贴问题？作者怎么说？

**没有找到。** 在上游仓库 `can1357/oh-my-pi` 的 issues 和 PR 中搜索 `paste twice`、`double paste`、`send-text`、`bracketed paste OSC 5522`，无相关报告。

相关 PR 记录的是 enhanced paste 的其他问题：
- **#2053**（已合入）：fix kitty OSC 5522 dot-listing MIME 解析 —— 修的是"enhanced paste 误判无支持的 MIME 类型"，跟双贴无关。
- **#2248**（已合入）：`app.clipboard.pasteImage` 增加文本回退（smart paste，#1628），让 Ctrl+V 在无图片时读剪贴板文本插入。这是用户按键路径，不涉及双贴。
- **#2127**（代码引用）：enhanced paste 文本路由到聚焦的模态 Input。不涉及双贴。

CHANGELOG 条目（`#3261: Added OSC 5522 enhanced paste handling`、`#2051: Fixed Kitty OSC 5522 paste rejecting plain text`）均描述 enhanced paste 的**功能实现**，无人报告过 `send-text` 触发双贴。

**推论**：OMD 的使用方式（`kitty @ send-text` + Wayland 剪贴板同步）在上游中未见报道，可能是 omp 设计时未考虑到的程序化粘贴场景。

### Q4：方向 C 的方案 1（原始字节）和方案 2（空 paste + smart paste），哪个更值得做？

> **2026-07-20 update:** 本节保留的是历史调查结论。实际使用发现方案 1 会让部分
> raw-input CLI/TUI 把大段正文逐字处理，性能和体验不可接受。当前实现已经改为
> `kitty @ action ... paste_from_clipboard` 原生整块粘贴；仅在 action 不可用时使用
> `send-text --bracketed-paste auto` + 临时清空/恢复剪贴板。禁止重新启用正文
> `--bracketed-paste disable` 路径。

**历史推荐方案 1（已废弃）：`--bracketed-paste disable` + 控制字符安全检测。**

| 维度 | 方案 1：原始字节 | 方案 2：空 paste + smart paste |
|------|-----------------|-------------------------------|
| 通用性 | 对所有程序有效（omp / bash / 其他 TUI） | **仅对 omp 有效**，bash 下空 paste = 无响应 |
| 控制字符风险 | 有风险但可控。语音输入纯文本无风险；剪贴板条目极少含控制符 | 无风险（smart paste 从剪贴板读） |
| 剪贴板副作用 | 无需操作剪贴板 | 需调用方提前 `wl-copy` 同步 |
| 异步回调风险 | 无 | 需检测目标是否支持 smart paste（不可靠） |
| 实现复杂度 | 低：改参数值 + 可选 payload 安全扫描 | 高：发空 paste → 检测是否插入 → 回退 |

**方案 2 的致命缺陷**：无法可靠区分目标是否支持 smart paste。`kitty @ ls` 的 `foreground_processes`/`cmdline` 不够可靠，且检测"paste 没插入"在 kitty 协议层面无可行手段。对 bash 发空 paste 会导致粘贴静默失败。

**控制字符风险的缓解**：在 `send_to_kitty()` 中对 payload 扫描 `\x00-\x1f`（保留 `\n\r\t`），若含控制字符则回退到带标记+清空方案。语音转写和绝大多数剪贴板内容都不会触发此回退。

**结论**：优先采用方案 1，在 `send_to_kitty()` 中对 payload 做控制字符扫描后决策。

### 排查过程留档

第 7 节"当前修复"中 `wl-copy -c` 清空 + 恢复的方案是安全的治标方案。如要改优雅方案，可参考 Q4 建议实现方案 1。

### 推荐修复实现

在 `send_to_kitty()` 中做控制字符扫描，分两路决策：

```bash
is_control_char_free() {
    # 允许 \t \n \r，拒绝 \x00-\x08 \x0b \x0c \x0e-\x1f
    awk '{ if (/[\x00-\x08\x0b\x0c\x0e-\x1f]/) exit 1 }' < "$1"
}

send_to_kitty() {
    if is_control_char_free "$PAYLOAD_FILE"; then
        # 主线：原始字节，不碰剪贴板，不触发 OSC 5522 → 无双贴
        kitty @ send-text --match id:$WIN_ID \
            --from-file "$PAYLOAD_FILE" --bracketed-paste disable
    else
        # 回退：当前方案（带标记 + 清空剪贴板）
        wl-copy -c
        kitty @ send-text --match id:$WIN_ID \
            --from-file "$PAYLOAD_FILE" --bracketed-paste auto
        sleep 0.05
        wl-copy < "$PAYLOAD_FILE"
    fi
}
```


3. 跑一个**多行 payload**，确认不提交。
