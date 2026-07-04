pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string state: "init"
    property real recordingDuration: 0
    property string lastTranscription: ""
    property string lastError: ""

    // ── 历史记录 ──
    property list<var> history: []
    readonly property int maxHistory: 20

    // ── 模型信息 ──
    property int modelSizeMB: 0
    property bool daemonRunning: false

    readonly property string cacheDir: FileUtils.trimFileProtocol(`${Directories.genericCache}/omd-voice`)
    readonly property string modelDir: `${root.cacheDir}/sense-voice-small-int8`
    readonly property string venvDir: `${root.cacheDir}/venv`
    readonly property string wavPath: "/tmp/omd-voice-rec.wav"
    readonly property string recPidFile: "/tmp/omd-voice-rec.pid"

    readonly property string shareDir: FileUtils.trimFileProtocol(
        `${Directories.config}/omd/share/bin`)

    // ── 自动粘贴策略 ──
    // 不同程序对粘贴快捷键的响应不同：
    //   终端类 (foot/kitty/alacritty/ghostty/wezterm)：Shift+Insert 或 Ctrl+Shift+V
    //   GUI 类 (浏览器/编辑器/聊天)：Ctrl+V
    //   不确定时：先 Shift+Insert（终端+GUI 通用），失败再 Ctrl+V
    // 通过 hyprctl activewindow 拿焦点窗口 class 做匹配。
    readonly property var pasteCommandForClass: ({
        // 终端 → 优先 Shift+Insert（终端通用）
        "foot": "wtype -M shift -k Insert",
        "footclient": "wtype -M shift -k Insert",
        "kitty": "wtype -M shift -k Insert",
        "alacritty": "wtype -M shift -k Insert",
        "ghostty": "wtype -M shift -k Insert",
        "wezterm": "wtype -M shift -k Insert",
        "org.wezfurlong.wezterm": "wtype -M shift -k Insert",
        "xdg-term": "wtype -M shift -k Insert",
        "konsole": "wtype -M shift -k Insert",
        "gnome-terminal": "wtype -M shift -k Insert",
        "xterm": "wtype -M shift -k Insert",
        "st": "wtype -M shift -k Insert",
        "urxvt": "wtype -M shift -k Insert",
        "rxvt": "wtype -M shift -k Insert",
        "tmux": "wtype -M shift -k Insert",
        // GUI → 优先 Ctrl+V
        "google-chrome": "wtype -M ctrl -k v",
        "chromium": "wtype -M ctrl -k v",
        "firefox": "wtype -M ctrl -k v",
        "org.mozilla.firefox": "wtype -M ctrl -k v",
        "code": "wtype -M ctrl -k v",
        "code-insiders": "wtype -M ctrl -k v",
        "obsidian": "wtype -M ctrl -k v",
        "telegram-desktop": "wtype -M ctrl -k v",
        "org.telegram.desktop": "wtype -M ctrl -k v",
        "discord": "wtype -M ctrl -k v",
        "wechat": "wtype -M ctrl -k v",
    })

    // 默认 paste 命令：Shift+Insert（终端 + GUI 通用）
    readonly property string defaultPasteCommand: "wtype -M shift -k Insert"

    // 匹配焦点窗口 class → paste 命令；未知返回空串（用 fallback 链）
    function pasteCommandForWindowClass(winClass) {
        if (!winClass) return ""
        const c = winClass.toLowerCase()
        // 精确匹配
        if (root.pasteCommandForClass.hasOwnProperty(c))
            return root.pasteCommandForClass[c]
        // 前缀模糊匹配（class 常带后缀如 "foot-1.2"）
        for (const key in root.pasteCommandForClass) {
            if (c.startsWith(key)) return root.pasteCommandForClass[key]
        }
        return ""
    }

    // 当前焦点窗口 class（异步刷新，粘贴时读取）
    property string focusedWindowClass: ""

    // 拿到当前焦点窗口 class 的 paste 命令；未知则用默认（Shift+Insert，终端+GUI 通用）
    function resolvePasteCommands() {
        const cmd = root.pasteCommandForWindowClass(root.focusedWindowClass)
        return { primary: cmd || root.defaultPasteCommand }
    }

    // 异步刷新焦点窗口 class
    Process {
        id: focusClassProc
        command: ["bash", "-c",
            "hyprctl -j activewindow 2>/dev/null | jq -r '.class // empty' 2>/dev/null"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.focusedWindowClass = this.text.trim()
            }
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", `${root.cacheDir}`])
        root.checkState()
        root.refreshModelInfo()
        root.refreshDaemonStatus()
    }

    onStateChanged: {
        if (state === "recording") {
            Quickshell.execDetached(["hyprctl", "eval", "o.bind(\"escape\", \"Cancel voice recording\", \"qs -p $HOME/.config/omd/apps/omd-bar ipc call voice cancel\")"])
        } else {
            Quickshell.execDetached(["hyprctl", "eval", "hl.unbind(\"escape\")"])
        }

        if (state === "success") {
            successResetTimer.restart()
        } else if (state === "error") {
            errorResetTimer.restart()
        }
    }

    Timer {
        id: successResetTimer
        interval: 1500
        repeat: false
        running: false
        onTriggered: {
            if (root.state === "success") root.state = "idle"
        }
    }

    Timer {
        id: errorResetTimer
        interval: 2000
        repeat: false
        running: false
        onTriggered: {
            if (root.state === "error") root.state = "idle"
        }
    }

    // ── 录音计时 ──
    Timer {
        id: recordingTimer
        interval: 100
        repeat: true
        running: root.state === "recording"
        onTriggered: root.recordingDuration += 0.1
    }

    // ── 模型信息刷新 ──
    function refreshModelInfo() {
        modelInfoProc.running = true
    }

    Process {
        id: modelInfoProc
        command: ["bash", "-c",
            `du -sm '${root.modelDir}' 2>/dev/null | awk '{print $1}' || echo 0`]
        stdout: SplitParser {
            onRead: (line) => {
                root.modelSizeMB = parseInt(line) || 0
            }
        }
    }

    // ── 守护进程状态刷新 ──
    function refreshDaemonStatus() {
        daemonCheckProc.running = true
    }

    Process {
        id: daemonCheckProc
        command: ["bash", "-c",
            `if [ -S /tmp/omd-voice.sock ] && ss -x src /tmp/omd-voice.sock 2>/dev/null | grep -q LISTEN; then echo running; else echo stopped; fi`]
        stdout: SplitParser {
            onRead: (line) => {
                root.daemonRunning = (line === "running")
            }
        }
    }

    // ── 桌面通知 helper ──
    function notify(title, body, icon) {
        var args = ["notify-send", "-a", "OMD Voice", "-t", "3000"]
        if (icon) args.push("-i", icon)
        args.push(title, body)
        Quickshell.execDetached(args)
    }

    // ── 状态检测 ──
    function checkState() {
        modelCheckProc.running = true
    }

    Process {
        id: modelCheckProc
        command: ["bash", "-c",
            `if [ -f '${root.modelDir}/model.int8.onnx' ] && [ -f '${root.modelDir}/tokens.txt' ]; then echo model-ok; else echo model-missing; fi`]
        stdout: SplitParser {
            onRead: (line) => {
                if (line === "model-ok") {
                    venvCheckProc.running = true
                } else {
                    root.state = "setup"
                }
            }
        }
    }

    Process {
        id: venvCheckProc
        command: ["bash", "-c",
            `if [ -f '${root.venvDir}/bin/python3' ] && '${root.venvDir}/bin/python3' -c 'import sherpa_onnx, numpy' 2>/dev/null; then echo venv-ok; else echo venv-missing; fi`]
        stdout: SplitParser {
            onRead: (line) => {
                if (line === "venv-ok") {
                    root.state = "idle"
                    root.refreshDaemonStatus()
                } else {
                    root.state = "setup"
                }
            }
        }
    }

    // ── 首次设置流程 ──
    function setup() {
        if (root.state !== "setup") return
        root.notify("⬇️ 正在准备语音输入",
            "首次使用需要安装依赖和下载模型，约需30秒…", "network-transmit")
        setupProc.running = true
    }

    Process {
        id: setupProc
        command: ["bash", `${root.shareDir}/omarchy-voice-setup`]
        stdout: SplitParser {
            onRead: (line) => {
                if (line.startsWith("ERROR")) {
                    root.lastError = line
                    root.state = "error"
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) {
                if (root.state !== "error") {
                    root.lastError = "依赖安装失败 (code " + code + ")"
                    root.state = "error"
                }
                return
            }
            if (root.state === "setup") {
                root.notify("⬇️ 正在下载模型", "约需30秒…", "network-transmit")
                downloadProc.running = true
            }
        }
    }

    Process {
        id: downloadProc
        command: ["bash", `${root.shareDir}/omarchy-voice-download`]
        stdout: SplitParser {
            onRead: (line) => {
                if (line === "model-ready") {
                    root.refreshModelInfo()
                    root.notify("✅ 准备完成", "开始录音", "audio-input-microphone")
                    root.state = "idle"
                    root.startRecording()
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0 && root.state === "setup") {
                root.lastError = "模型下载失败 (code " + code + ")"
                root.state = "error"
            }
        }
    }

    // ── 主切换逻辑 ──
    function toggle() {
        if (state === "setup") {
            root.setup()
            return
        }
        if (state === "error") {
            root.checkState()
            return
        }
        if (state === "idle") startRecording()
        else if (state === "recording") stopRecording()
    }

    function startRecording() {
        root.testMode = false
        root.recordingDuration = 0
        root.lastTranscription = ""
        root.lastError = ""
        // 记录当前焦点窗口 class，转写完成时按此选 paste 命令
        focusClassProc.running = false
        focusClassProc.running = true
        state = "recording"
        recProc.running = true
    }

    function stopRecording() {
        if (state !== "recording") return
        stopRecProc.running = true
    }

    function cancel() {
        if (state !== "recording") return
        state = "idle"
        stopRecProc.running = true
    }

    function isMeaningfulText(text) {
        var cleaned = text.replace(/<\|[^|]+\|>/g, "").trim()
        if (cleaned.length === 0) return false
        return !/^[\s\.,!?。，！？、…\-]+$/.test(cleaned)
    }

    Process {
        id: recProc
        command: ["bash", `${root.shareDir}/omarchy-voice-record`, "start"]
    }

    Process {
        id: stopRecProc
        command: ["bash", `${root.shareDir}/omarchy-voice-record`, "stop"]
        onExited: (code, status) => {
            if (root.state === "recording") {
                state = "transcribing"
                transcribeProc.running = true
            }
        }
    }

    property bool testMode: false

    Process {
        id: transcribeProc
        command: ["bash", "-c",
            `"${root.venvDir}/bin/python3" "${root.shareDir}/omarchy-voice-transcribe" "${root.wavPath}"`]
        stdout: SplitParser {
            onRead: (line) => {
                try {
                    var result = JSON.parse(line)
                    if (result.text !== undefined) {
                        if (root.isMeaningfulText(result.text)) {
                            root.lastTranscription = result.text
                            root.addToHistory(result.text)
                            if (root.testMode) {
                                root.onTestTranscriptionResult(result.text)
                            } else {
                                root.onTranscriptionResult(result.text)
                            }
                        } else {
                            root.lastError = "没有检测到语音"
                        }
                    } else if (result.error) {
                        root.lastError = result.error === "no-speech-detected"
                            ? "没有检测到语音（请检查麦克风或说大声一点）"
                            : result.error
                    }
                } catch (e) {
                    console.error("[VoiceInput] parse error:", e)
                    root.lastError = "转写结果解析失败"
                }
            }
        }
        onExited: (code, status) => {
            if (root.state !== "transcribing") return
            if (code !== 0 && root.lastError === "" && root.lastTranscription === "") {
                root.lastError = "转写失败 (code " + code + ")"
            }
            if (root.lastError === "" && root.lastTranscription === "") {
                root.lastError = "没有检测到语音"
            }
            root.state = root.lastError === "" ? "success" : "idle"
            root.testMode = false
        }
    }

    function onTranscriptionResult(text) {
        console.log("[VoiceInput] onTranscriptionResult text='" + text + "' class=" + root.focusedWindowClass)
        Quickshell.execDetached(["bash", "-c",
            `printf '%s' '${StringUtils.shellSingleQuoteEscape(text)}' | wl-copy`])
        // 解析焦点窗口 → 选 paste 命令（按窗口 class 精确匹配）
        const pasteCmds = root.resolvePasteCommands()
        console.log("[VoiceInput] paste primary: " + pasteCmds.primary)
        Quickshell.execDetached(["bash", "-c",
            `sleep 0.3 && ${pasteCmds.primary} || true`])
    }

    // ── 调试：不自动粘贴，只复制文本并打开设置面板展示结果 ──
    function onTestTranscriptionResult(text) {
        Quickshell.execDetached(["bash", "-c",
            `printf '%s' '${StringUtils.shellSingleQuoteEscape(text)}' | wl-copy`])
        root.lastTranscription = text
        root.addToHistory(text)
        root.openSettings()
    }

    // ── 历史记录 ──
    function addToHistory(text) {
        var now = new Date()
        var timeStr = now.getHours().toString().padStart(2, '0') + ":" + 
                      now.getMinutes().toString().padStart(2, '0')
        var entry = { text: text, time: timeStr }
        var newHistory = [entry].concat(root.history)
        if (newHistory.length > root.maxHistory) {
            newHistory = newHistory.slice(0, root.maxHistory)
        }
        root.history = newHistory
    }

    function clearHistory() {
        root.history = []
    }

    // ── 测试录音（3秒自动停止） ──
    function testRecording() {
        if (root.state !== "idle") {
            return
        }
        root.testMode = true
        root.recordingDuration = 0
        root.lastTranscription = ""
        root.lastError = ""
        state = "recording"
        recProc.running = true
        testStopTimer.restart()
    }

    Timer {
        id: testStopTimer
        interval: 3000
        repeat: false
        running: false
        onTriggered: {
            if (root.state === "recording") {
                stopRecProc.running = true
            }
        }
    }

    // ── 打开设置面板 ──
    function openSettings() {
        GlobalStates.barPopupType = "voice"
    }

    IpcHandler {
        target: "voice"
        function toggle(): void {
            root.toggle()
        }
        function cancel(): void {
            root.cancel()
        }
    }
}
