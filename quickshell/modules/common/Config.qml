pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common.functions

Singleton {
    id: root
    property string filePath: Directories.sumikaConfigPath
    property alias options: configOptionsJsonAdapter
    property bool ready: false
    property int readWriteDelay: 50 // milliseconds
    property bool blockWrites: false

    function setNestedValue(nestedKey, value) {
        let keys = nestedKey.split(".");
        let obj = root.options;
        let parents = [obj];

        // Traverse and collect parent objects
        for (let i = 0; i < keys.length - 1; ++i) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object") {
                obj[keys[i]] = {};
            }
            obj = obj[keys[i]];
            parents.push(obj);
        }

        // Convert value to correct type using JSON.parse when safe
        let convertedValue = value;
        if (typeof value === "string") {
            let trimmed = value.trim();
            if (trimmed === "true" || trimmed === "false" || !isNaN(Number(trimmed))) {
                try {
                    convertedValue = JSON.parse(trimmed);
                } catch (e) {
                    convertedValue = value;
                }
            }
        }

        obj[keys[keys.length - 1]] = convertedValue;
    }

    Timer {
        id: fileReloadTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            configFileView.reload()
        }
    }

    Timer {
        id: fileWriteTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            configFileView.writeAdapter()
        }
    }

    FileView {
        id: configFileView
        path: root.filePath
        watchChanges: true
        blockWrites: root.blockWrites
        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: fileWriteTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                writeAdapter();
            }
        }

        JsonAdapter {
            id: configOptionsJsonAdapter

            property JsonObject appearance: JsonObject {
                property bool extraBackgroundTint: true
                property JsonObject fonts: JsonObject {
                    property string main: "MesloLGS Nerd Font Mono"
                    property string numbers: "MesloLGS Nerd Font Mono"
                    property string title: "MesloLGS Nerd Font Mono"
                    property string iconNerd: "JetBrainsMono Nerd Font Mono"
                    property string monospace: "MesloLGS Nerd Font Mono"
                    property string reading: "MesloLGS Nerd Font Mono"
                    property string expressive: "MesloLGS Nerd Font Mono"
                }
                property JsonObject transparency: JsonObject {
                    property bool enable: false
                    property bool automatic: true
                    property real backgroundTransparency: 0.11
                    property real contentTransparency: 0.57
                }
                property JsonObject wallpaperTheming: JsonObject {
                    property bool enableAppsAndShell: true
                    property bool enableQtApps: true
                    property bool enableTerminal: true
                    property JsonObject terminalGenerationProps: JsonObject {
                        property real harmony: 0.6
                        property real harmonizeThreshold: 100
                        property real termFgBoost: 0.35
                        property bool forceDarkMode: false
                    }
                }
            }

            property JsonObject audio: JsonObject {
                // Values in %
                property JsonObject protection: JsonObject {
                    // Prevent sudden bangs
                    property bool enable: false
                    property real maxAllowedIncrease: 10
                    property real maxAllowed: 99
                }
            }

            property JsonObject apps: JsonObject {
                property string bluetooth: ""
                property string changePassword: ""
                property string network: ""
                property string manageUser: ""
                property string networkEthernet: ""
                property string taskManager: ""
                property string terminal: "xdg-terminal-exec" // This is only for shell actions
                property string update: ""
                property string volumeMixer: "pavucontrol-qt"
            }

            property JsonObject background: JsonObject {
                property string wallpaperPath: ""
                property string thumbnailPath: ""
                property bool hideWhenFullscreen: true
            }

            property JsonObject bar: JsonObject {
                property bool bottom: false // Instead of top
                property int cornerStyle: 0 // 0: Hug | 1: Float | 2: Plain rectangle
                property bool floatStyleShadow: true // Show shadow behind bar when cornerStyle == 1 (Float)
                property bool borderless: false // true for no grouping of items
                property bool showBackground: true
                property bool vertical: false
                property int rightModuleSpacing: 8 // pixels between right-side modules
                property int centerModuleSpacing: 8 // pixels between center modules
                property int rightIconSlotWidth: 28 // width of right-side icon-only slots
                property int rightIconSize: 20 // size of right-side bar icons
                property int centerIconSize: 18 // size of center-side bar icons
                property JsonObject resources: JsonObject {
                    property bool alwaysShowSwap: true
                    property bool alwaysShowCpu: true
                    property int memoryWarningThreshold: 95
                    property int swapWarningThreshold: 85
                    property int cpuWarningThreshold: 90
                }
                property list<string> screenList: [] // Non-empty: show bar only on these monitors (hyprctl monitors)
            }

            property JsonObject battery: JsonObject {
                property int low: 20
                property int critical: 5
                property int full: 101
                property bool automaticSuspend: true
                property int suspend: 3
            }

            property JsonObject conflictKiller: JsonObject {
                property bool autoKillNotificationDaemons: false
                property bool autoKillTrays: false
            }

            property JsonObject interactions: JsonObject {
                property JsonObject scrolling: JsonObject {
                    property bool fasterTouchpadScroll: false // Enable faster scrolling with touchpad
                    property int mouseScrollDeltaThreshold: 120 // delta >= this then it gets detected as mouse scroll rather than touchpad
                    property int mouseScrollFactor: 120
                    property int touchpadScrollFactor: 450
                }
                property JsonObject deadPixelWorkaround: JsonObject { // Hyprland leaves out 1 pixel on the right for interactions
                    property bool enable: false
                }
            }

            property JsonObject idle: JsonObject {
                property int screensaverTimeout: 150
                property int lockTimeout: 152
                property int monitorOffTimeout: 300
                property int suspendTimeout: 0
                property bool lockBeforeSuspend: true
            }

            property JsonObject inputMethod: JsonObject {
                property bool enabled: true
                property string backend: "fcitx5"
                property bool autostart: true
                property string switchKey: "SUPER + SPACE"
                property string switchSchemaKey: "SUPER + SHIFT + SPACE"
                property list<var> schemas: []
            }

            property JsonObject language: JsonObject {
                property string ui: "auto" // UI language. "auto" for system locale, or specific language code like "zh_CN", "en_US"
            }

            property JsonObject launcher: JsonObject {
                property list<string> pinnedApps: []
            }

            property JsonObject light: JsonObject {
                property JsonObject night: JsonObject {
                    property bool automatic: true
                    property string from: "19:00" // Format: "HH:mm", 24-hour time
                    property string to: "06:30"   // Format: "HH:mm", 24-hour time
                    property int colorTemperature: 5000
                }
                property JsonObject antiFlashbang: JsonObject {
                    property bool enable: false
                }
            }

            property JsonObject lock: JsonObject {
                property bool launchOnStartup: false
                property JsonObject blur: JsonObject {
                    property bool enable: true
                    property real radius: 100
                    property real extraZoom: 1.1
                }
                property bool centerClock: true
                property bool showLockedText: true
                property JsonObject security: JsonObject {
                    property bool unlockKeyring: true
                    property bool requirePasswordToPower: false
                }
                property bool materialShapeChars: true
            }

            property JsonObject media: JsonObject {
                // Attempt to remove dupes (the aggregator playerctl one and browsers' native ones when there's plasma browser integration)
                property bool filterDuplicatePlayers: true
            }

            property JsonObject networking: JsonObject {
                property string userAgent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
            }

            property JsonObject notifications: JsonObject {
                property int timeout: 7000
                property bool silent: false
                property list<string> mutedApps: []
                property JsonObject forceMonitor: JsonObject {
                    property bool enable: false
                    property string name: "" // Name of the monitor to show notifications on, like "eDP-1". Find out with 'hyprctl monitors' command
                }
            }

            property JsonObject osd: JsonObject {
                property int timeout: 1000
            }

            property JsonObject overview: JsonObject {
                property bool enable: true
                property real scale: 0.18 // Relative to screen size
                property real rows: 2
                property real columns: 5
                property bool orderRightLeft: false
                property bool orderBottomUp: false
                property bool centerIcons: true
            }

            property JsonObject regionSelector: JsonObject {
                property JsonObject targetRegions: JsonObject {
                    property bool windows: true
                    property bool layers: false
                    property bool content: true
                    property bool showLabel: false
                    property real opacity: 0.3
                    property real contentRegionOpacity: 0.8
                    property int selectionPadding: 5
                }
                property JsonObject rect: JsonObject {
                    property bool showAimLines: true
                }
                property JsonObject circle: JsonObject {
                    property int strokeWidth: 6
                    property int padding: 10
                }
                property JsonObject annotation: JsonObject {
                    property bool useSatty: false
                }
            }

            property JsonObject resources: JsonObject {
                property int updateInterval: 3000
                property int historyLength: 60
            }

            property JsonObject tray: JsonObject {
                property bool monochromeIcons: false
                property bool showItemId: false
                property bool invertPinnedItems: false
                property list<var> pinnedItems: []
                property bool filterPassive: false
            }

            property JsonObject search: JsonObject {
                property JsonObject imageSearch: JsonObject {
                    property string imageSearchEngineBaseUrl: "https://lens.google.com/uploadbyurl?url="
                    property bool useCircleSelection: false
                }
            }

            property JsonObject startup: JsonObject {
                property bool staggerPanelLoading: true
                property int tier1DelayMs: 1500
                property int tier2DelayMs: 6000
                property bool deferBackgroundTasks: true
                property int backgroundTasksDelayMs: 4000
                property bool deferUpdateCheck: true
                property int updateCheckDelayMs: 30000
            }

            property JsonObject screenRecord: JsonObject {
                property string savePath: Directories.videos.replace("file://","") // strip "file://"
            }

            property JsonObject screenSnip: JsonObject {
                property string savePath: "" // only copy to clipboard when empty
            }

            property JsonObject sounds: JsonObject {
                property string theme: "freedesktop"
            }

            property JsonObject time: JsonObject {
                // https://doc.qt.io/qt-6/qtime.html#toString
                property string shortDateFormat: "dd/MM"
                property string dateWithYearFormat: "dd/MM/yyyy"
                property string dateFormat: "ddd, dd/MM"
            }

            property JsonObject updates: JsonObject {
                property bool enableCheck: true
                property int checkInterval: 120 // minutes
                property int adviseUpdateThreshold: 75 // packages
                property int stronglyAdviseUpdateThreshold: 200 // packages
            }
            
            property JsonObject windows: JsonObject {
                property bool showTitlebar: true // Client-side decoration for shell apps
                property bool centerTitle: true
            }
            property JsonObject modules: JsonObject {
                // Master switch for optional modules. When false, only the product-floor
                // minimum desktop remains (launcher, clock, workspaces, systray, wifi, audio,
                // power-indicator, notification-popup, overview, display).
                property bool enabled: true
                // Per-module exclusion list (optional modules only). Required/floor
                // modules ignore this list and always stay enabled.
                property list<var> disabled: []
                // Extra required module IDs (union with hardcoded product floor).
                // Cannot shrink below: launcher, clock, workspaces, systray, wifi, audio,
                // power-indicator, notification-popup, overview, display.
                property list<var> required: [
                    "launcher",
                    "clock",
                    "notification-popup",
                    "workspaces",
                    "overview",
                    "systray",
                    "wifi",
                    "audio",
                    "power-indicator",
                    "display"
                ]
                property JsonObject barButtonOrder: JsonObject {}
            }

            property JsonObject hacks: JsonObject {
                property int arbitraryRaceConditionDelay: 20 // milliseconds
            }

            property JsonObject cursor: JsonObject {
                property string theme: "Adwaita"
                property int size: 24
            }

            property JsonObject gestures: JsonObject {
                property string fourFingerUp: "overview"
                property string fourFingerPinchIn: "launcher"
                property string fourFingerDown: ""
                property string fourFingerLeft: ""
                property string fourFingerRight: ""
                property string threeFingerHorizontal: ""
            }

            property JsonObject input: JsonObject {
                property JsonObject keyboard: JsonObject {
                    property string kbLayout: "jp"
                    property string kbVariant: ""
                    property string kbOptions: "compose:caps"
                    property bool numlockByDefault: true
                    property int repeatRate: 40
                    property int repeatDelay: 250
                }
                property JsonObject touchpad: JsonObject {
                    property bool tapToClick: true
                    property string tapButtonMap: "lrm"
                    property bool clickfingerBehavior: true
                    property real scrollFactor: 0.4
                    property bool naturalScroll: false
                    property bool disableWhileTyping: false
                }
            }

            property JsonObject ocr: JsonObject {
                property string lang: "ch"
                property string engine: "onnxruntime"
            }

            property JsonObject backup: JsonObject {
                property string address: ""
                property string share: ""
                property string user: ""
                property string remotePath: ""
                property list<string> localPaths: []
                property string includeExt: ""
                property string excludeExt: ""
                property string scheduleType: "manual"
                property string scheduleValue: ""
            }

            property JsonObject system: JsonObject {
                property list<string> startupAutoCommands: []
                property bool waybarOff: false
            }
        }
    }
}
