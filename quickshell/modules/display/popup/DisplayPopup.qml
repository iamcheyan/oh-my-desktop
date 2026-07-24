import qs.modules.common.widgets
import qs
import qs.modules.bar
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common.widgets

PopupColumn {
    id: displayPanel

    readonly property var targetScreen: Quickshell.screens[0]
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(targetScreen)
    readonly property real brightnessValue: brightnessMonitor?.brightness ?? 0
    readonly property bool canControlBrightness: {
        if (!targetScreen || !brightnessMonitor)
            return false;
        const n = targetScreen.name || "";
        const internal = n.startsWith("eDP") || n.startsWith("LVDS") || n.startsWith("DSI") || n.startsWith("DPI");
        return internal || !!brightnessMonitor.isDdc;
    }
    readonly property string monitorLabel: targetScreen?.name ?? "?"

    PopupHeader {
        Layout.fillWidth: true
        icon: NerdIconMap.desktop
        title: "Display"
        subtitle: canControlBrightness
            ? `Brightness ${Math.round(brightnessValue * 100)}%  ·  ${monitorLabel}` +
                (Hyprsunset.temperatureActive ? "  ·  Night mode on" : "")
            : `${monitorLabel}  ·  no brightness control (need DDC/i2c)` +
                (Hyprsunset.temperatureActive ? "  ·  Night mode on" : "")
        tone: !canControlBrightness
            ? TuiStyle.warning
            : (Hyprsunset.temperatureActive ? TuiStyle.warning : TuiStyle.accent)
    }

    // Brightness slider — only this monitor (same rules as omd-brightness-display)
    PopupSliderRow {
        icon: NerdIconMap.brightness6
        value: brightnessValue
        muted: false
        opacity: canControlBrightness ? 1 : 0.4
        onMoved: value => {
            if (!canControlBrightness || !brightnessMonitor)
                return;
            Brightness.lastAdjustedScreenName = targetScreen?.name ?? "";
            GlobalStates.osdBrightnessScreen = targetScreen?.name ?? "";
            brightnessMonitor.setBrightness(value);
        }
    }

    PopupToggleRow {
        label: "Night mode"
        checked: Hyprsunset.temperatureActive
        onToggled: checked => Hyprsunset.toggleTemperature(checked)
        showDivider: false
    }

    // Keep this row in the layout so toggling night mode never resizes
    // the popup. Its enabled state is communicated with a subtle fade.
    PopupSliderRow {
        enabled: Hyprsunset.temperatureActive
        opacity: Hyprsunset.temperatureActive ? 1 : 0.35
        icon: NerdIconMap.brightness6
        value: (6500 - (Config.options.light.night.colorTemperature ?? 6000)) / (6500 - 2500)
        muted: false
        onMoved: value => {
            const temp = Math.round(6500 - value * (6500 - 2500));
            Config.setNestedValue("light.night.colorTemperature", temp);
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    ToolLauncherRow {
        Layout.fillWidth: true
        icon: "palette"
        title: "Themes"
        subtitle: "Colors, fonts and desktop appearance"
    }
    SettingsButton {
        label: qsTr("Display Settings")
        iconName: "desktop_windows"
        onClicked: {
            GlobalStates.barPopupType = "";
            const rootDir = FileUtils.trimFileProtocol(Quickshell.env("OMD_REPO_ROOT") || Directories.root)
            Quickshell.execDetached([`${rootDir}/bin/omd-settings`, "open", "display"]);
        }
    }

    PopupFooterLink {
        Layout.fillWidth: true
        label: "Display settings…"
        onClicked: {
            GlobalStates.barPopupType = "";
            const rootDir = FileUtils.trimFileProtocol(Quickshell.env("OMD_REPO_ROOT") || Directories.root)
            Quickshell.execDetached([`${rootDir}/bin/omd-settings`, "open", "display"]);
        }
    }
}
