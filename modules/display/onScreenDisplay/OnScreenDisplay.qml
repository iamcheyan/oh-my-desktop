import qs
import qs.services
import qs.services as Services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property string protectionMessage: ""
    property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        ?? Quickshell.screens[0]
        ?? null
    // Screen the OSD window is pinned to for this show (does not follow focus jumps).
    property var osdScreen: focusedScreen

    property string currentIndicator: "volume"
    property string popupIndicatorType: ""
    property var indicators: [
        {
            id: "volume",
            sourceUrl: "indicators/VolumeIndicator.qml"
        },
        {
            id: "brightness",
            sourceUrl: "indicators/BrightnessIndicator.qml"
        },
        {
            id: "gamma",
            sourceUrl: "indicators/GammaIndicator.qml"
        },
        {
            id: "inputMethod",
            sourceUrl: "indicators/InputMethodIndicator.qml"
        },
    ]

    function screenByName(name) {
        if (!name)
            return null;
        return Quickshell.screens.find(s => s.name === name) ?? null;
    }

    /**
     * Show OSD. Optional screen pins the popup to that output (brightness
     * per-monitor). Volume / default uses the currently focused screen.
     */
    function triggerOsd(forScreen) {
        root.osdScreen = forScreen ?? root.focusedScreen ?? Quickshell.screens[0] ?? null;
        GlobalStates.osdVolumeOpen = true;
        osdTimeout.restart();
    }

    function triggerBarPopup(type) {
        root.popupIndicatorType = type;
        GlobalStates.osdVolumeOpen = false;
        if (GlobalStates.barPopupType === type && !GlobalStates.barPopupEphemeral)
            return;
        GlobalStates.barPopupEphemeral = true;
        GlobalStates.barPopupType = type;
        popupTimeout.restart();
    }

    Timer {
        id: osdTimeout
        interval: Config.options.osd.timeout
        repeat: false
        running: false
        onTriggered: {
            GlobalStates.osdVolumeOpen = false;
            root.protectionMessage = "";
        }
    }

    Timer {
        id: popupTimeout
        interval: Config.options.osd.timeout
        repeat: false
        running: false
        onTriggered: {
            if (GlobalStates.barPopupEphemeral && GlobalStates.barPopupType === root.popupIndicatorType)
                GlobalStates.barPopupType = "";
            GlobalStates.barPopupEphemeral = false;
            root.popupIndicatorType = "";
        }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged() {
            root.protectionMessage = "";
            // Prefer the monitor that was just adjusted (set by Brightness service).
            const monName = Brightness.lastAdjustedScreenName || GlobalStates.osdBrightnessScreen || "";
            if (monName)
                GlobalStates.osdBrightnessScreen = monName;
            GlobalStates.osdBrightnessValue = -1;
            root.currentIndicator = "brightness";
            root.triggerOsd(root.screenByName(monName) ?? root.focusedScreen);
        }
    }

    Connections {
        target: Hyprsunset
        function onGammaChangeAttempt() {
            root.protectionMessage = "";
            root.currentIndicator = "gamma";
            // Gamma is compositor-global — show on focused screen only.
            root.triggerOsd(root.focusedScreen);
        }
    }

    Connections {
        target: Services.InputMethod
        function onOsdRequested() {
            root.protectionMessage = "";
            root.currentIndicator = "inputMethod";
            root.triggerOsd(root.focusedScreen);
        }
    }

    Connections {
        // Listen to volume changes
        target: Audio.sink?.audio ?? null
        function onVolumeChanged() {
            if (!Audio.ready)
                return;
            root.currentIndicator = "volume";
            root.triggerOsd(root.focusedScreen);
        }
        function onMutedChanged() {
            if (!Audio.ready)
                return;
            root.currentIndicator = "volume";
            root.triggerOsd(root.focusedScreen);
        }
    }

    Connections {
        // Listen to protection triggers
        target: Audio
        function onSinkProtectionTriggered(reason) {
            root.protectionMessage = reason;
            root.currentIndicator = "volume";
            root.triggerOsd(root.focusedScreen);
        }
    }

    Loader {
        id: osdLoader
        active: GlobalStates.osdVolumeOpen

        sourceComponent: PanelWindow {
            id: osdRoot
            color: "transparent"
            // Pinned at trigger time — do not hop screens when focus changes.
            screen: root.osdScreen

            WlrLayershell.namespace: "quickshell:onScreenDisplay"
            WlrLayershell.layer: WlrLayer.Overlay
            anchors {
                top: root.currentIndicator !== "inputMethod" && !Config.options.bar.bottom
                bottom: root.currentIndicator !== "inputMethod" && Config.options.bar.bottom
            }
            mask: Region {
                item: osdValuesWrapper
            }

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            margins {
                top: Appearance.sizes.barHeight
                bottom: Appearance.sizes.barHeight
            }

            implicitWidth: columnLayout.implicitWidth
            implicitHeight: columnLayout.implicitHeight
            visible: osdLoader.active

            ColumnLayout {
                id: columnLayout
                anchors.horizontalCenter: parent.horizontalCenter

                Item {
                    id: osdValuesWrapper
                    // Extra space for shadow
                    implicitHeight: contentColumnLayout.implicitHeight
                    implicitWidth: contentColumnLayout.implicitWidth
                    clip: true

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: GlobalStates.osdVolumeOpen = false
                    }

                    Column {
                        id: contentColumnLayout
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                        }
                        spacing: 0

                        Loader {
                            id: osdIndicatorLoader
                            source: root.indicators.find(i => i.id === root.currentIndicator)?.sourceUrl
                        }

                        Item {
                            id: protectionMessageWrapper
                            anchors.horizontalCenter: parent.horizontalCenter
                            implicitHeight: protectionMessageBackground.implicitHeight
                            implicitWidth: protectionMessageBackground.implicitWidth
                            opacity: root.protectionMessage !== "" ? 1 : 0

                            StyledRectangularShadow {
                                target: protectionMessageBackground
                            }
                            Rectangle {
                                id: protectionMessageBackground
                                anchors.centerIn: parent
                                color: Appearance.m3colors.m3error
                                property real padding: 10
                                implicitHeight: protectionMessageRowLayout.implicitHeight + padding * 2
                                implicitWidth: protectionMessageRowLayout.implicitWidth + padding * 2
                                radius: Appearance.rounding.normal

                                RowLayout {
                                    id: protectionMessageRowLayout
                                    anchors.centerIn: parent
                                    MaterialSymbol {
                                        id: protectionMessageIcon
                                        text: "dangerous"
                                        iconSize: Appearance.font.pixelSize.hugeass
                                        color: Appearance.m3colors.m3onError
                                    }
                                    StyledText {
                                        id: protectionMessageTextWidget
                                        horizontalAlignment: Text.AlignHCenter
                                        color: Appearance.m3colors.m3onError
                                        wrapMode: Text.Wrap
                                        text: root.protectionMessage
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "osdVolume"

        function trigger() {
            root.currentIndicator = "volume";
            root.triggerOsd();
        }

        function hide() {
            GlobalStates.osdVolumeOpen = false;
            if (GlobalStates.barPopupType === "audio")
                GlobalStates.barPopupType = "";
        }

        function toggle() {
            GlobalStates.barPopupType = GlobalStates.barPopupType === "audio" ? "" : "audio";
        }
    }
    GlobalShortcut {
        name: "osdVolumeTrigger"
        description: "Triggers volume OSD on press"

        onPressed: {
            root.currentIndicator = "volume";
            root.triggerOsd();
        }
    }
    GlobalShortcut {
        name: "osdVolumeHide"
        description: "Hides volume OSD on press"

        onPressed: {
            GlobalStates.osdVolumeOpen = false;
            if (GlobalStates.barPopupType === "audio")
                GlobalStates.barPopupType = "";
        }
    }

    IpcHandler {
        target: "osdBrightness"

        // value: 0–100 (or <0 to read live monitor brightness).
        // monitorName: Hyprland connector to pin the OSD (e.g. eDP-1, HDMI-A-1).
        function trigger(value: real, monitorName: string): void {
            const mon = (monitorName && monitorName.length) ? monitorName : (Hyprland.focusedMonitor?.name ?? "");
            GlobalStates.osdBrightnessScreen = mon;
            if (value >= 0)
                GlobalStates.osdBrightnessValue = Math.max(0, Math.min(100, value));
            else
                GlobalStates.osdBrightnessValue = -1;
            root.currentIndicator = "brightness";
            root.triggerOsd(root.screenByName(mon) ?? root.focusedScreen);
        }

        // Back-compat: single-arg form pins to focused monitor.
        function triggerValue(value: real): void {
            trigger(value, Hyprland.focusedMonitor?.name ?? "");
        }
    }
}
