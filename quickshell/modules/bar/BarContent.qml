import qs.modules.bar.modules
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item { // Bar content region
    id: root

    readonly property int barSidePadding: 10
    readonly property color barOpaqueColor: "#000000"

    property var screen: root.QsWindow.window?.screen
    readonly property HyprlandMonitor barMonitor: Hyprland.monitorFor(root.screen)
    readonly property int barActiveWorkspaceId: HyprlandData.monitorActiveWorkspaceId(root.barMonitor)

    readonly property bool workspaceHasWindows: {
        const wsId = root.barActiveWorkspaceId;
        if (wsId < 1)
            return false;

        const wsData = HyprlandData.workspaceById[wsId];
        if (wsData !== undefined && typeof wsData.windows === "number")
            return wsData.windows > 0;

        return HyprlandData.hyprlandClientsForWorkspace(wsId).some(
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


        Workspaces {
            Layout.alignment: Qt.AlignVCenter
        }

        // Left module registration slot — AppLauncher, ActiveWindow, and external modules
        Repeater {
            model: ModuleLoader.leftBarModules
            delegate: Loader {
                required property var modelData
                source: modelData.component
                active: true
                Layout.alignment: Qt.AlignVCenter
                onStatusChanged: if (status === Loader.Error) {
                    console.warn("[Module] Left bar module load failed:", modelData.component)
                    active = false
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

            // --- 模块按钮（受 modules.enabled 总开关控制）---

            SysTray {
                Layout.alignment: Qt.AlignVCenter
                visible: ModuleLoader.modulesEnabled
            }

            InputMethodButton {
                Layout.alignment: Qt.AlignVCenter
                visible: ModuleLoader.modulesEnabled
            }

            // --- 核心按钮（永远显示）---

            AudioButton {
                Layout.alignment: Qt.AlignVCenter
            }

            WifiButton {
                Layout.alignment: Qt.AlignVCenter
            }

            // --- 模块按钮（受 modules.enabled 总开关控制）---

            ClipboardButton {
                Layout.alignment: Qt.AlignVCenter
                visible: ModuleLoader.modulesEnabled
            }

            SessionButton {
                Layout.alignment: Qt.AlignVCenter
                visible: ModuleLoader.modulesEnabled
            }

            DisplayButton {
                Layout.alignment: Qt.AlignVCenter
                visible: ModuleLoader.modulesEnabled
            }

            ToolsButton {
                Layout.alignment: Qt.AlignVCenter
                visible: ModuleLoader.modulesEnabled
            }

            // --- 核心按钮（永远显示）---

            ClockWidget {
                Layout.alignment: Qt.AlignVCenter
            }

            SidebarIndicators {
                Layout.alignment: Qt.AlignVCenter
            }

            // 外部可插拔模块按钮（动态加载，也受总开关控制）
            Repeater {
                model: ModuleLoader.barButtons
                delegate: Loader {
                    required property var modelData
                    source: modelData.component
                    active: true
                    Layout.alignment: Qt.AlignVCenter
                    onStatusChanged: if (status === Loader.Error) {
                        console.warn("[Module] Bar button load failed:", modelData.component)
                        active = false
                    }
                }
            }
        }
    }
}
