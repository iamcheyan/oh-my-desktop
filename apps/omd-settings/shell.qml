//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000
//@ pragma Env QT_IM_MODULE=fcitx

import qs.modules.settings
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    readonly property string initialPage: Quickshell.env("OMD_SETTINGS_PAGE") ?? "overview"
    readonly property bool onDemand: (Quickshell.env("OMD_SETTINGS_ON_DEMAND") ?? "0") === "1"
    readonly property string registryPath: Quickshell.env("SUMIKA_MODULE_REGISTRY") ?? (Quickshell.env("XDG_RUNTIME_DIR") ?? "/run/user/1000") + "/sumika-shell/modules.json"

    Component.onCompleted: {
        if (root.onDemand) {
            registryView.path = root.registryPath;
        }
    }

    FileView {
        id: registryView
        onLoaded: {
            try {
                var text = registryView.text();
                if (text.length > 0) {
                    var parsed = JSON.parse(text);
                    var pages = parsed.contributes?.settingsPages ?? [];
                    for (var i = 0; i < pages.length; i++) {
                        if (pages[i].id === root.initialPage) {
                            directPageLoader.source = pages[i].component;
                            return;
                        }
                    }
                }
            } catch (e) {
                console.warn("[Settings] Failed to read registry:", e);
            }
            // Fallback: page not found, use full settings dialog
            root.showSettings(root.initialPage);
        }
    }

    function showSettings(page: string) {
        settingsWindow.openPage(page);
    }

    function closeSettings() {
        settingsWindow.hidePage();
        if (root.onDemand) {
            Qt.callLater(Qt.quit);
        }
    }

    function closeDirectPage() {
        directPageLoader.source = "";
        if (root.onDemand) {
            Qt.callLater(Qt.quit);
        }
    }

    IpcHandler {
        target: "settings"

        function open(page: string): void {
            root.showSettings(page);
        }

        function close(): void {
            root.closeSettings();
        }

        function toggle(page: string): void {
            if (settingsWindow.isOpen) {
                root.closeSettings();
            } else {
                root.showSettings(page);
            }
        }
    }

    PanelWindow {
        id: settingsWindow
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:settings"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: settingsDialog.show ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        color: "transparent"
        visible: true

        property bool isOpen: settingsDialog.show

        function close() {
            root.closeSettings();
        }

        function openPage(page: string) {
            settingsDialog.requestedPage = page || "overview";
            settingsDialog.show = true;
        }

        function hidePage() {
            settingsDialog.show = false;
        }

        SettingsDialog {
            id: settingsDialog
            anchors.fill: parent
            requestedPage: root.initialPage
            visible: settingsDialog.show
            show: false
            onDismiss: settingsWindow.close()
        }
    }

    // On-demand panel: shows page content directly, no sidebar/footer chrome
    PanelWindow {
        id: directPanel
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:settings"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        color: "transparent"
        visible: root.onDemand && directPageLoader.active

        // Click background to dismiss
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
            onClicked: (mouse) => {
                if (!pageFrame.contains(Qt.point(mouse.x, mouse.y))) {
                    root.closeDirectPage();
                }
            }
        }

        Rectangle {
            id: pageFrame
            anchors.centerIn: parent

            readonly property int minWidth: 860
            readonly property int minHeight: 560
            width: Math.min(1080, Math.max(minWidth, parent.width - 52))
            height: Math.min(720, Math.max(minHeight, parent.height - 96))

            radius: TuiStyle.shellRadius
            color: TuiStyle.bg
            gradient: Gradient {
                GradientStop { position: 0.0; color: TuiStyle.shellGradientTop }
                GradientStop { position: 0.42; color: TuiStyle.shellGradientMid }
                GradientStop { position: 1.0; color: TuiStyle.shellGradientBottom }
            }
            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.shellBorder
            clip: true

            Loader {
                id: directPageLoader
                anchors.fill: parent
                anchors.margins: 16
                asynchronous: false

                onLoaded: {
                    if (item && item.settingsRoot !== undefined) {
                        item.settingsRoot = ({ shellQuote: function(v) { return "'" + String(v || "").replace(/'/g, "'\\''") + "'"; }, dismiss: function() { root.closeDirectPage(); } });
                    }
                }
            }
        }
    }
}
