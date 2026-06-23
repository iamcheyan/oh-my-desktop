import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.modules.common
import qs.modules.common.widgets

GroupButton {
    id: root
    horizontalPadding: 12
    verticalPadding: 6
    bounce: false
    property string buttonIcon
    property bool leftmost: false
    property bool rightmost: false
    buttonRadius: 0
    buttonRadiusPressed: 0
    leftRadius: 0
    rightRadius: 0
    colBackground: root.toggled ? Appearance.tiling.bgTitlebar : "transparent"
    colBackgroundHover: Appearance.tiling.bgHover
    colBackgroundActive: Appearance.tiling.bgActive
    colBackgroundToggled: Appearance.tiling.bgTitlebar
    colBackgroundToggledHover: Appearance.tiling.bgActive
    colBackgroundToggledActive: Appearance.tiling.bgHover
    borderWidth: Appearance.tiling.borderWidth
    borderColor: root.toggled ? Appearance.tiling.borderFocus : Appearance.tiling.border

    contentItem: RowLayout {
        spacing: 4 * (root.buttonText?.length > 0)

        Loader {
            Layout.alignment: Qt.AlignVCenter
            active: root.buttonIcon && root.buttonIcon.length > 0
            visible: active
            sourceComponent: Item {
                implicitWidth: materialSymbol.implicitWidth
                MaterialSymbol {
                    id: materialSymbol
                    anchors.centerIn: parent
                    text: root.buttonIcon
                    iconSize: Appearance.font.pixelSize.larger
                    color: root.toggled ? Appearance.tiling.textBright : Appearance.tiling.textDim
                }
            }
        }

        Item {
            implicitWidth: root.buttonText?.length > 0 ? textItem.implicitWidth : 0
            implicitHeight: textMetrics.height // Force height to that of regular text

            TextMetrics {
                id: textMetrics
                font.family: Appearance.font.family.monospace
                text: "Abc"
            }

            StyledText {
                id: textItem
                anchors.centerIn: parent
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                color: root.toggled ? Appearance.tiling.textBright : Appearance.tiling.text
                text: root.buttonText
            }
        }
    }
}
