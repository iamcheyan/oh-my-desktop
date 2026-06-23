import qs.modules.ii.bar.weather
import qs.modules.ii.bar.modules
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item { // Bar content region
    id: root

    readonly property int barSidePadding: 10
    readonly property int titleAreaWidth: 280
    readonly     property color barOpaqueColor: ColorUtils.transparentize(Appearance.m3colors.m3background, 0.2)
    readonly property bool anyChildActive: GlobalStates.barDialogOpen
        || GlobalStates.sidebarRightOpen
        || GlobalStates.scheduleOpen
        || GlobalStates.appLauncherOpen
        || GlobalStates.overviewOpen

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
    readonly property color barBackgroundColor: Config.options.bar.showBackground && root.workspaceHasWindows
        ? root.barOpaqueColor
        : "transparent"
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)
    property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0
    readonly property int centerSideModuleWidth: (useShortenedForm == 2) ? Appearance.sizes.barCenterSideModuleWidthHellaShortened : (useShortenedForm == 1) ? Appearance.sizes.barCenterSideModuleWidthShortened : Appearance.sizes.barCenterSideModuleWidth

    component VerticalBarSeparator: Rectangle {
        Layout.topMargin: Appearance.sizes.baseBarHeight / 3
        Layout.bottomMargin: Appearance.sizes.baseBarHeight / 3
        Layout.fillHeight: true
        implicitWidth: 1
        color: Appearance.colors.colOutlineVariant
    }

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

        BarTextButton {
            Layout.alignment: Qt.AlignVCenter
            text: "Applications"
            onTriggered: GlobalStates.appLauncherOpen = !GlobalStates.appLauncherOpen
        }

        Workspaces {
            id: workspacesWidget
            Layout.alignment: Qt.AlignVCenter
        }

        ActiveWindow {
            id: activeWindowItem
            Layout.alignment: Qt.AlignVCenter
            titleAreaWidth: root.titleAreaWidth
            visible: root.useShortenedForm === 0
        }
    }

    MouseArea { // Center clock
        id: centerClock
        z: 1
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
        }
        width: Math.max(centerClockWidget.implicitWidth + 24, 140)
        implicitHeight: centerClockWidget.implicitHeight

        onClicked: {
            GlobalStates.scheduleOpen = !GlobalStates.scheduleOpen;
        }

        ClockWidget {
            id: centerClockWidget
            anchors.verticalCenter: parent.verticalCenter
            showHoverPopup: false
        }
    }

    FocusedScrollMouseArea { // Right side
        id: barRightSideMouseArea

        anchors {
            top: parent.top
            bottom: parent.bottom
            left: centerClock.right
            right: parent.right
            rightMargin: root.barSidePadding
        }
        implicitWidth: rightSectionRowLayout.implicitWidth
        implicitHeight: Appearance.sizes.baseBarHeight

        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }
        }

        RightModuleRegistry {
            id: rightModuleRegistry
        }

        // Visual content

        RowLayout {
            id: rightSectionRowLayout
            anchors {
                top: parent.top
                bottom: parent.bottom
                right: parent.right
            }
            width: implicitWidth
            spacing: Config.options.bar.rightModuleSpacing
            layoutDirection: Qt.RightToLeft

            Repeater {
                model: Config.options.bar.rightModules
                delegate: Loader {
                    required property string modelData
                    Layout.fillHeight: true
                    sourceComponent: {
                        const comp = rightModuleRegistry.componentForName(modelData);
                        return comp;
                    }
                    active: sourceComponent !== null
                }
            }
        }
    }
}
