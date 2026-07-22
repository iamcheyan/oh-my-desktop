import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
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
    readonly property string displayTitle: root.hasWindowOnWorkspace ? root.windowTitle : "Desktop"
    readonly property string osIconPath: `file://${FileUtils.trimFileProtocol(Directories.config)}/omd/icons/OS/${root.osIconName()}.svg`

    readonly property var screen: root.QsWindow.window?.screen
    readonly property real useShortenedForm: (Appearance.sizes.barHellaShortenScreenWidthThreshold >= screen?.width) ? 2 : (Appearance.sizes.barShortenScreenWidthThreshold >= screen?.width) ? 1 : 0

    implicitWidth: titleAreaWidth
    implicitHeight: 28
    visible: !root.hideOnShortScreen || root.useShortenedForm === 0

    function fallbackLetter(appId, title) {
        const source = (appId && appId.length > 0) ? appId : (title ?? "");
        if (!source || source.length === 0)
            return "?";
        return source.charAt(0).toUpperCase();
    }

    function osIconName() {
        const id = (SystemInfo.distroId || "").toLowerCase();
        const name = (SystemInfo.distroName || "").toLowerCase();
        const haystack = `${id} ${name}`;

        if (haystack.includes("fedora")) return "fedora";
        if (haystack.includes("arch")) return "arch";
        if (haystack.includes("ubuntu")) return "ubuntu";
        if (haystack.includes("debian")) return "debian";
        if (haystack.includes("endeavouros")) return "endeavouros";
        if (haystack.includes("nixos")) return "nixos";
        if (haystack.includes("manjaro")) return "manjaro";
        if (haystack.includes("opensuse") || haystack.includes("suse")) return "opensuse";
        if (haystack.includes("mint")) return "mint";
        if (haystack.includes("pop")) return "pop-os";
        if (haystack.includes("zorin")) return "zorin-os";
        if (haystack.includes("centos")) return "centos";
        if (haystack.includes("redhat")) return "redhat";
        if (haystack.includes("rocky")) return "rockylinux";
        if (haystack.includes("alpine")) return "alpine";
        if (haystack.includes("gentoo")) return "gentoo";
        return "fedora";
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
                visible: root.hasWindowOnWorkspace ? root.windowIconClass.length > 0 : true
                source: root.hasWindowOnWorkspace ? AppSearch.iconSource(AppSearch.guessIcon(root.windowIconClass)) : root.osIconPath
                smooth: true
            }

            Rectangle {
                anchors.fill: parent
                visible: !windowIcon.visible || windowIcon.source === "" || windowIcon.status === Image.Error
                radius: 3
                color: "transparent"

                StyledText {
                    anchors.centerIn: parent
                    text: root.fallbackLetter(root.windowIconClass, root.displayTitle)
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
            text: root.displayTitle
        }
    }
}
