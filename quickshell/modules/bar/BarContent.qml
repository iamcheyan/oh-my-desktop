pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.core.runtime
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item { // Bar content region
    id: root

    readonly property int barSidePadding: 10
    readonly property color barOpaqueColor: Qt.rgba(
        Config.options.bar.backgroundColor === "white" ? 1 : 0,
        Config.options.bar.backgroundColor === "white" ? 1 : 0,
        Config.options.bar.backgroundColor === "white" ? 1 : 0,
        (Config.options.bar.backgroundOpacity ?? 100) / 100
    )

    property var screen: root.QsWindow.window?.screen

    // Fixed widgets at the rightmost positions (power always last; clock
    // sits before it on notched hosts where the center is physically
    readonly property bool clockInCenter: !HostInfo.screenHasNotch

    readonly property var _fixedWidgetIds: ["clock", "power-indicator"]

    readonly property var _movableRightButtons: {
        var result = [];
        var all = ModuleLoader.rightBarButtons;
        for (var i = 0; i < all.length; i++) {
            if (root._fixedWidgetIds.indexOf(all[i].moduleId) < 0) {
                result.push(all[i]);
            }
        }
        return result;
    }

    function _findFixedWidget(moduleId) {
        var all = ModuleLoader.rightBarButtons;
        for (var i = 0; i < all.length; i++) {
            if (all[i].moduleId === moduleId)
                return all[i];
        }
        return null;
    }

    // "Does this bar's workspace currently show any window?" — drives
    // transparentOnEmptyDesktop. Two paths:
    // - Hyprland: exact workspace semantics via HyprlandData (hyprctl IPC
    //   clients carry workspace.id/mapped/hidden), scoped to the workspace
    //   active on this bar's monitor.
    // - Other compositors (labwc, sway): zwlr_foreign_toplevel_management_v1
    //   approximation — an activated, maximized toplevel reporting this
    //   screen. Toplevel `screens` does not track workspaces on labwc, so a
    //   maximized window is the closest "this desktop is occupied" signal.
    readonly property bool workspaceHasWindows: {
        if (HyprlandData.hyprlandIpcAvailable) {
            const barScreen = root.screen?.name ?? "";
            const wsId = HyprlandData.monitors.find(mon => (mon.name ?? "") === barScreen)
                ?.activeWorkspace?.id ?? 0;
            const has = HyprlandData.workspaceHasVisibleWindows(wsId);
            return has;
        }
        const barScreen = root.screen?.name ?? "";
        const list = ToplevelManager.toplevels.values;
        for (let i = 0; i < list.length; i++) {
            const t = list[i];
            if (t.activated && t.maximized
                    && t.screens.some(s => s.name === barScreen))
                return true;
        }
        return false;
    }
    // No visible window on this workspace => fully transparent. Any visible
    // window => configured opacity (backgroundOpacity, e.g. 50 => 50%).
    readonly property color barBackgroundColor:
        !Config.options.bar.showBackground ? "transparent" :
        Config.options.bar.transparentOnEmptyDesktop
            ? (root.workspaceHasWindows ? root.barOpaqueColor : "transparent")
            : root.barOpaqueColor

    // Background shadow
    Loader {
        active: Config.options.bar.showBackground && Config.options.bar.cornerStyle === 1 && Config.options.bar.floatStyleShadow && root.workspaceHasWindows
        anchors.fill: barBackground
        sourceComponent: StyledRectangularShadow {
            anchors.fill: undefined // The loader's anchors act on this, and this should not have any anchor
            target: barBackground
        }
    }
    // Background
    Rectangle {
        id: barBackground
        anchors {
            fill: parent
            margins: Config.options.bar.cornerStyle === 1 ? (Appearance.sizes.hyprlandGapsOut) : 0 // idk why but +1 is needed
        }
        color: root.barBackgroundColor
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: 0
        border.color: Appearance.colors.colLayer0Border

        Behavior on color {
            ColorAnimation {
                duration: 300
                easing.type: Easing.InOutCubic
            }
        }
    }

    RowLayout {
        id: leftSectionRowLayout
        anchors.left: parent.left
        anchors.leftMargin: root.barSidePadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14



        // Left module registration slot — AppLauncher, ActiveWindow, and bar modules
        Repeater {
            model: ModuleLoader.leftBarButtons
            delegate: Loader {
                required property var modelData
                source: modelData.component
                active: true
                Layout.alignment: Qt.AlignVCenter
                onStatusChanged: if (status === Loader.Error) {
                    console.warn("[Module] Left bar module load failed:", modelData.component)
                }
                onLoaded: {
                    if (modelData.alwaysShow === true && item)
                        item.visible = true
                }
            }
        }
    }


    // Center section — centered between left and right content
    Item {
        id: centerSection
        z: 1
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        width: 0

        // On notchless hosts the clock lives in the screen center (the
        // notch counterpart stays in the right row below). Only one of the
        // two clock loaders is ever active.
        Loader {
            anchors.centerIn: parent
            source: root._findFixedWidget("clock")?.component ?? ""
            active: root.clockInCenter && source !== ""
            visible: active
            onStatusChanged: if (status === Loader.Error) {
                console.warn("[Module] Center clock widget load failed:", source)
            }
        }
    }

    FocusedScrollMouseArea { // Right side
        id: barRightSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: centerSection.right
            right: parent.right
            rightMargin: root.barSidePadding
        }
        implicitWidth: rightSectionRowLayout.implicitWidth
        implicitHeight: Appearance.sizes.baseBarHeight

        // onPressed removed — clicking individual modules should not
        // toggle the sidebar. Use the SidebarIndicators button instead.

        // Visual content

        RowLayout {
            id: rightSectionRowLayout
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            spacing: Config.options.bar.rightModuleSpacing

            // Movable plugin buttons sorted by order
            Repeater {
                model: root._movableRightButtons
                delegate: Loader {
                    required property var modelData
                    source: modelData.component
                    active: true
                    Layout.alignment: Qt.AlignVCenter
                    onLoaded: {
                        if (item && typeof item.moduleId !== "undefined")
                            item.moduleId = modelData.moduleId
                        // A widget may temporarily report unavailable while
                        // its backend is starting. alwaysShow keeps the entry
                        // present so the widget can recover in place.
                        if (modelData.alwaysShow === true && item)
                            item.visible = true
                    }
                    onStatusChanged: if (status === Loader.Error) {
                        console.warn("[Module] Bar button load failed:", modelData.component)
                    }
                }
            }

            // Fixed clock widget — second from right only on notched
            // hosts; notchless hosts render it in centerSection above.
            Loader {
                source: root._findFixedWidget("clock")?.component ?? ""
                active: !root.clockInCenter && source !== ""
                visible: active
                Layout.alignment: Qt.AlignVCenter
                onStatusChanged: if (status === Loader.Error) {
                    console.warn("[Module] Fixed clock widget load failed:", source)
                }
            }

            // Fixed power indicator — always far right
            Loader {
                source: root._findFixedWidget("power-indicator")?.component ?? ""
                active: source !== ""
                visible: source !== ""
                Layout.alignment: Qt.AlignVCenter
                onStatusChanged: if (status === Loader.Error) {
                    console.warn("[Module] Fixed power indicator load failed:", source)
                }
            }
        }
    }
}
