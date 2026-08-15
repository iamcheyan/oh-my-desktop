pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string icon: ""
    property string moduleId: ""
    property bool active: false
    property var altAction: null
    signal clicked()

    readonly property string effectiveIcon: icon

    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    implicitWidth: Appearance.sizes.rightIconSlotSize
    implicitHeight: Appearance.sizes.rightIconSlotSize

    property color iconColor: Appearance.colors.colBarText

    RippleButton {
        id: button
        anchors.centerIn: parent
        width: Appearance.sizes.rightIconSlotSize
        height: Appearance.sizes.rightIconSlotSize
        buttonRadius: Appearance.sizes.rightIconSlotSize / 2

        colBackground: "transparent"
        colBackgroundHover: Qt.rgba(1, 1, 1, 0.10)
        colBackgroundToggled: Qt.rgba(1, 1, 1, 0.18)
        colBackgroundToggledHover: Qt.rgba(1, 1, 1, 0.26)
        colRipple: Qt.rgba(1, 1, 1, 0.12)
        colRippleToggled: Qt.rgba(1, 1, 1, 0.18)
        toggled: root.active

        onClicked: {
            root.clicked();
        }
    }

    BarNerdIcon {
        anchors.centerIn: button
        text: root.effectiveIcon
        color: root.iconColor
    }
}
