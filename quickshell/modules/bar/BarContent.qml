import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.core.runtime
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item { // Bar content region
    id: root

    readonly property int barSidePadding: 10
    readonly property color barOpaqueColor: {
        const base = Config.options.bar.backgroundColor === "white" ? "#FFFFFF" : "#000000"
        const alpha = Math.round((Config.options.bar.backgroundOpacity ?? 100) / 100 * 255)
        return Qt.rgba(
            base === "#FFFFFF" ? 1 : 0,
            base === "#FFFFFF" ? 1 : 0,
            base === "#FFFFFF" ? 1 : 0,
            alpha / 255
        )
    }

    property var screen: root.QsWindow.window?.screen
    readonly property HyprlandMonitor barMonitor: Hyprland.monitorFor(root.screen)
    readonly property int barActiveWorkspaceId: ServiceManager.workspace.monitorActiveWorkspaceId(root.barMonitor)

    // Fixed widgets at the rightmost positions (power always last, clock before it)
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

    readonly property bool workspaceHasWindows: {
        const wsId = root.barActiveWorkspaceId;
        if (wsId < 1)
            return false;

        const wsData = ServiceManager.workspace.workspaceById[wsId];
        if (wsData !== undefined && typeof wsData.windows === "number")
            return wsData.windows > 0;

        return ServiceManager.workspace.hyprlandClientsForWorkspace(wsId).some(
            win => win.mapped && !win.hidden
        );
    }
    readonly property color barBackgroundColor: Config.options.bar.showBackground
        ? root.barOpaqueColor
        : "transparent"

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
                    }
                    onStatusChanged: if (status === Loader.Error) {
                        console.warn("[Module] Bar button load failed:", modelData.component)
                    }
                }
            }

            // Fixed clock widget — always second from right
            Loader {
                source: root._findFixedWidget("clock")?.component ?? ""
                active: source !== ""
                visible: source !== ""
                Layout.alignment: Qt.AlignVCenter
                onStatusChanged: if (status === Loader.Error) {
                    console.warn("[Module] Fixed clock widget load failed:", source)
                }
            }

            // Fixed power indicator (power + xkb) — always far right
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
