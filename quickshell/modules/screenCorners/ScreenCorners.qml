import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: screenCorners
    property bool hotCornersEnabled: false
    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property string overviewApp: `${FileUtils.trimFileProtocol(Directories.config)}/omd/apps/omd-overview`
    readonly property string appLauncherApp: `${FileUtils.trimFileProtocol(Directories.config)}/omd/apps/omd-applauncher`
    // ... (rest unchanged)

    function callOverview(method) {
        Quickshell.execDetached([
            "qs", "-p", screenCorners.overviewApp, "ipc", "call", "overview", method
        ]);
    }

    function callAppLauncher(method) {
        Quickshell.execDetached([
            "qs", "-p", screenCorners.appLauncherApp, "ipc", "call", "appLauncher", method
        ]);
    }

    property var actionForCorner: ({
        [RoundCorner.CornerEnum.TopLeft]: () => screenCorners.callOverview("toggle"),
        [RoundCorner.CornerEnum.BottomLeft]: () => {},
        [RoundCorner.CornerEnum.TopRight]: () => screenCorners.callAppLauncher("toggle"),
        [RoundCorner.CornerEnum.BottomRight]: () => GlobalStates.controlCenterOpen = !GlobalStates.controlCenterOpen
    })

    // Dedicated hot corners for top-left (Overview) and top-right (AppLauncher)
    // Independent of sidebar.cornerOpen config
    component TopCornerHotspot: PanelWindow {
        id: hotspot
        property bool isRight: false
        property bool fullscreen: false
        property bool triggered: false
        property bool cooldown: false   // blocks re-trigger after panel closes
        visible: !fullscreen
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:screenCorners"
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"
        anchors.top: true
        anchors.left: !isRight
        anchors.right: isRight
        implicitWidth: 200
        implicitHeight: 4
        mask: Region { item: hotspotArea }

        Timer {
            id: triggerDelayTimer
            interval: Config.options.interactions.hotCorner.triggerDelay
            repeat: false
            onTriggered: {
                if (hotspot.isRight) {
                    screenCorners.callAppLauncher("open");
                } else {
                    screenCorners.callOverview("open");
                }
                hotspot.cooldown = true;
                cooldownTimer.restart();
            }
        }

        Timer {
            id: cooldownTimer
            interval: 800
            repeat: false
            onTriggered: hotspot.cooldown = false
        }

        Connections {
            target: GlobalStates
            function onOverviewOpenChanged() {
                if (!hotspot.isRight && !GlobalStates.overviewOpen) {
                    hotspot.triggered = false;
                    hotspot.cooldown = true;
                    cooldownTimer.restart();
                }
            }
        }

        MouseArea {
            id: hotspotArea
            anchors.fill: parent
            hoverEnabled: true
            onEntered: {
                if (hotspot.triggered || hotspot.cooldown) return;
                hotspot.triggered = true;
                triggerDelayTimer.restart();
            }
            onExited: {
                hotspot.triggered = false;
                triggerDelayTimer.stop();
                if (!hotspot.cooldown)
                    cooldownTimer.stop();
            }
        }
    }

    component CornerPanelWindow: PanelWindow {
        id: cornerPanelWindow
        property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
        property bool fullscreen
        visible: false
        property var corner

        exclusionMode: ExclusionMode.Ignore
        mask: Region {
            item: sidebarCornerOpenInteractionLoader.active ? sidebarCornerOpenInteractionLoader : null
        }
        WlrLayershell.namespace: "quickshell:screenCorners"
        WlrLayershell.layer: WlrLayer.Overlay
        color: "transparent"

        anchors {
            top: cornerWidget.isTopLeft || cornerWidget.isTopRight
            left: cornerWidget.isBottomLeft || cornerWidget.isTopLeft
            bottom: cornerWidget.isBottomLeft || cornerWidget.isBottomRight
            right: cornerWidget.isTopRight || cornerWidget.isBottomRight
        }
        margins {
            right: (Config.options.interactions.deadPixelWorkaround.enable && cornerPanelWindow.anchors.right) * -1
            bottom: (Config.options.interactions.deadPixelWorkaround.enable && cornerPanelWindow.anchors.bottom) * -1
        }

        implicitWidth: cornerWidget.implicitWidth
        implicitHeight: cornerWidget.implicitHeight

        RoundCorner {
            id: cornerWidget
            anchors.fill: parent
            corner: cornerPanelWindow.corner
            rightVisualMargin: (Config.options.interactions.deadPixelWorkaround.enable && cornerPanelWindow.anchors.right) * 1
            bottomVisualMargin: (Config.options.interactions.deadPixelWorkaround.enable && cornerPanelWindow.anchors.bottom) * 1

            implicitSize: Appearance.rounding.screenRounding
            implicitHeight: Math.max(implicitSize, sidebarCornerOpenInteractionLoader.implicitHeight)
            implicitWidth: Math.max(implicitSize, sidebarCornerOpenInteractionLoader.implicitWidth)

            Loader {
                id: sidebarCornerOpenInteractionLoader
                active: {
                    if (!Config.options.sidebar.cornerOpen.enable) return false;
                    if (cornerPanelWindow.fullscreen) return false;
                    return (Config.options.sidebar.cornerOpen.bottom == cornerWidget.isBottom);
                }
                anchors {
                    top: (cornerWidget.isTopLeft || cornerWidget.isTopRight) ? parent.top : undefined
                    bottom: (cornerWidget.isBottomLeft || cornerWidget.isBottomRight) ? parent.bottom : undefined
                    left: (cornerWidget.isLeft) ? parent.left : undefined
                    right: (cornerWidget.isTopRight || cornerWidget.isBottomRight) ? parent.right : undefined
                }

                sourceComponent: FocusedScrollMouseArea {
                    id: mouseArea
                    implicitWidth: Config.options.sidebar.cornerOpen.cornerRegionWidth
                    implicitHeight: Config.options.sidebar.cornerOpen.cornerRegionHeight
                    hoverEnabled: true

                    Timer {
                        id: cornerTriggerDelay
                        interval: Config.options.interactions.hotCorner.triggerDelay
                        repeat: false
                        onTriggered: {
                            screenCorners.actionForCorner[cornerPanelWindow.corner]();
                        }
                    }

                    onPositionChanged: {
                        if (!Config.options.sidebar.cornerOpen.clicklessCornerEnd) return;
                        const verticalOffset = Config.options.sidebar.cornerOpen.clicklessCornerVerticalOffset;
                        const correctX = (cornerWidget.isRight && mouseArea.mouseX >= mouseArea.width - 2) || (cornerWidget.isLeft && mouseArea.mouseX <= 2);
                        const correctY = (cornerWidget.isTop && mouseArea.mouseY > verticalOffset || cornerWidget.isBottom && mouseArea.mouseY < mouseArea.height - verticalOffset);
                        if (correctX && correctY)
                            screenCorners.actionForCorner[cornerPanelWindow.corner]();
                    }
                    onEntered: {
                        if (Config.options.sidebar.cornerOpen.clickless)
                            cornerTriggerDelay.restart();
                    }
                    onExited: {
                        cornerTriggerDelay.stop();
                    }
                    onPressed: {
                        cornerTriggerDelay.stop();
                        screenCorners.actionForCorner[cornerPanelWindow.corner]();
                    }
                    onScrollDown: (steps) => {
                        if (!Config.options.sidebar.cornerOpen.valueScroll)
                            return;
                        if (cornerWidget.isLeft)
                            for (let i = 0; i < steps; i++) Brightness.decreaseBrightness()
                    }
                    onScrollUp: (steps) => {
                        if (!Config.options.sidebar.cornerOpen.valueScroll)
                            return;
                        if (cornerWidget.isLeft)
                            for (let i = 0; i < steps; i++) Brightness.increaseBrightness()
                    }
                    onMovedAway: {
                        if (!Config.options.sidebar.cornerOpen.valueScroll)
                            return;
                        if (cornerWidget.isLeft)
                            GlobalStates.osdBrightnessOpen = false;
                    }

                    Loader {
                        active: Config.options.sidebar.cornerOpen.visualize
                        anchors.fill: parent
                        sourceComponent: Rectangle {
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }
        }
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: monitorScope
            required property var modelData
            property HyprlandMonitor monitor: Hyprland.monitorFor(modelData)

            // Hide when fullscreen
            property list<HyprlandWorkspace> workspacesForMonitor: Hyprland.workspaces.values.filter(workspace => workspace.monitor && workspace.monitor.name == monitor.name)
            property var activeWorkspaceWithFullscreen: workspacesForMonitor.filter(workspace => ((workspace.toplevels.values.filter(window => window.wayland?.fullscreen)[0] != undefined) && workspace.active))[0]
            property bool fullscreen: activeWorkspaceWithFullscreen != undefined

    // Toggle to temporarily disable all corner hot zones
    property bool hotCornersEnabled: false

    // Corner panels (visual corners)
    CornerPanelWindow {
        screen: modelData
        corner: RoundCorner.CornerEnum.TopLeft
        fullscreen: monitorScope.fullscreen
        visible: hotCornersEnabled
    }
    CornerPanelWindow {
        screen: modelData
        corner: RoundCorner.CornerEnum.TopRight
        fullscreen: monitorScope.fullscreen
        visible: hotCornersEnabled
    }
    CornerPanelWindow {
        screen: modelData
        corner: RoundCorner.CornerEnum.BottomLeft
        fullscreen: monitorScope.fullscreen
        visible: hotCornersEnabled
    }
    CornerPanelWindow {
        screen: modelData
        corner: RoundCorner.CornerEnum.BottomRight
        fullscreen: monitorScope.fullscreen
        visible: hotCornersEnabled
    }
    // Top hot corners used for overview/app launcher
    TopCornerHotspot {
        screen: modelData
        isRight: false
        fullscreen: monitorScope.fullscreen
        visible: hotCornersEnabled
    }
    TopCornerHotspot {
        screen: modelData
        isRight: true
        fullscreen: monitorScope.fullscreen
        visible: hotCornersEnabled
    }
        }
    }
}
