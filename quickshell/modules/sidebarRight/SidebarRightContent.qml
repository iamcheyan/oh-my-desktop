import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

Item {
    id: root
    property int sidebarWidth: Appearance.sizes.sidebarWidth
    property int sidebarPadding: 8
    property string settingsQmlPath: Quickshell.shellPath("settings.qml")

    implicitHeight: sidebarRightBackground.implicitHeight
    implicitWidth: sidebarRightBackground.implicitWidth

    Rectangle {
        id: sidebarRightBackground
        anchors.fill: parent
        implicitHeight: parent.height - Appearance.sizes.hyprlandGapsOut * 2
        implicitWidth: sidebarWidth - Appearance.sizes.hyprlandGapsOut * 2
        color: Appearance.tiling.bg
        border.width: Appearance.tiling.borderWidth
        border.color: Appearance.tiling.borderFocus
        radius: 0

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: sidebarPadding
            spacing: sidebarPadding

            SystemButtonRow {
                Layout.fillHeight: false
                Layout.fillWidth: true
                Layout.bottomMargin: 0
            }

            CenterWidgetGroup {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: true
                Layout.fillWidth: true
            }
        }
    }

    component SystemButtonRow: Item {
        implicitHeight: commandBar.implicitHeight

        Rectangle {
            id: commandBar
            anchors.fill: parent
            implicitHeight: Appearance.tiling.titlebarHeight + 2
            radius: 0
            color: Appearance.tiling.bg
            border.width: Appearance.tiling.borderWidth
            border.color: Appearance.tiling.border

            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 8
                    rightMargin: 4
                }
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: "system"
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.tiling.textDim
                }

                TuiPanelButton {
                    buttonIcon: "restart_alt"
                    onClicked: {
                        Quickshell.execDetached(["hyprctl", "reload"])
                        Quickshell.reload(true);
                    }
                    StyledToolTip {
                        text: Translation.tr("Reload Hyprland & Quickshell")
                    }
                }

                TuiPanelButton {
                    buttonIcon: "settings"
                    onClicked: {
                        GlobalStates.sidebarRightOpen = false;
                        Quickshell.execDetached(["qs", "-p", root.settingsQmlPath]);
                    }
                    StyledToolTip {
                        text: Translation.tr("Settings")
                    }
                }

                TuiPanelButton {
                    buttonIcon: "power_settings_new"
                    onClicked: {
                        GlobalStates.sessionOpen = true;
                    }
                    StyledToolTip {
                        text: Translation.tr("Session")
                    }
                }
            }
        }
    }
}
