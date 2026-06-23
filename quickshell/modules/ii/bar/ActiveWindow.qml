import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Wayland
import Quickshell.Hyprland

Item {
    id: root

    property int titleAreaWidth: 280
    property bool hideOnShortScreen: true

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(root.QsWindow.window?.screen)
    readonly property int activeWorkspaceId: HyprlandData.monitorActiveWorkspaceId(root.monitor)
    readonly property var displayClient: HyprlandData.focusedClientForWorkspace(root.activeWorkspaceId)

    readonly property bool hasWindowOnWorkspace: root.displayClient !== null
    readonly property string windowTitle: root.displayClient?.title ?? ""
    readonly property string windowIconClass: root.displayClient?.class ?? ""

    readonly property var screen: root.QsWindow.window?.screen
    readonly property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0

    implicitWidth: root.hasWindowOnWorkspace ? titleAreaWidth : 0
    implicitHeight: 28
    visible: root.hasWindowOnWorkspace && (!root.hideOnShortScreen || root.useShortenedForm === 0)

    function fallbackLetter(appId, title) {
        const source = (appId && appId.length > 0) ? appId : (title ?? "");
        if (!source || source.length === 0)
            return "?";
        return source.charAt(0).toUpperCase();
    }

    RowLayout {
        anchors.fill: parent
        spacing: 6

        Item {
            Layout.alignment: Qt.AlignVCenter
            implicitWidth: 14
            implicitHeight: 14

            IconImage {
                id: windowIcon
                anchors.fill: parent
                visible: root.windowIconClass.length > 0
                source: AppSearch.iconSource(AppSearch.guessIcon(root.windowIconClass))
                smooth: true
            }

            Rectangle {
                anchors.fill: parent
                visible: !windowIcon.visible || windowIcon.source === "" || windowIcon.status === Image.Error
                radius: 3
                color: "transparent"

                StyledText {
                    anchors.centerIn: parent
                    text: root.fallbackLetter(root.windowIconClass, root.windowTitle)
                    font.pixelSize: 9
                    font.variableAxes: ({ "wght": 700 })
                    color: Appearance.colors.colBarText
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            font.pixelSize: 12
            font.variableAxes: ({
                "wght": 500,
                "wdth": 100,
            })
            color: Appearance.colors.colBarText
            elide: Text.ElideRight
            maximumLineCount: 1
            text: root.windowTitle
        }
    }
}
