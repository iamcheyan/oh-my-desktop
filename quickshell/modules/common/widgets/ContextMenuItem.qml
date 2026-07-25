pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root

    property string nerdIcon: ""
    property string labelText: ""
    property color iconColor: TuiStyle.fg
    property color textColor: TuiStyle.fg

    property int itemHeight: 32
    property int iconSize: 18
    property int iconColumnWidth: 20
    property real hPadding: 8

    buttonRadius: 6
    horizontalPadding: root.hPadding
    topPadding: 0
    bottomPadding: 0
    implicitHeight: root.itemHeight
    height: root.itemHeight
    Layout.fillWidth: true

    colBackground: "transparent"
    colBackgroundHover: TuiStyle.surfaceHover
    colRipple: TuiStyle.surfacePressed
    borderWidth: 0

    contentItem: RowLayout {
        spacing: 8
        Item {
            Layout.preferredWidth: root.iconColumnWidth
            Layout.preferredHeight: root.iconColumnWidth
            Layout.alignment: Qt.AlignVCenter
            NerdIcon {
                anchors.centerIn: parent
                iconSize: root.iconSize
                text: root.nerdIcon
                color: root.iconColor
                visible: root.nerdIcon !== ""
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: root.labelText
            color: root.textColor
            elide: Text.ElideRight
            font {
                pixelSize: 13
                weight: Font.Normal
            }
        }
    }
}
