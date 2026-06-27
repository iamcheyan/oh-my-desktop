import qs.modules.common
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: root

    property var tabs: []
    property int currentIndex: 0
    signal selected(int index)

    spacing: 0

    function setCurrentIndex(index) {
        const nextIndex = Math.max(0, Math.min(index, root.tabs.length - 1));
        if (root.currentIndex === nextIndex)
            return;
        root.currentIndex = nextIndex;
        root.selected(nextIndex);
    }

    function incrementCurrentIndex() {
        root.setCurrentIndex(root.currentIndex + 1);
    }

    function decrementCurrentIndex() {
        root.setCurrentIndex(root.currentIndex - 1);
    }

    Repeater {
        model: root.tabs

        Rectangle {
            id: tab
            required property int index
            required property var modelData
            readonly property bool active: index === root.currentIndex

            Layout.preferredHeight: 30
            Layout.preferredWidth: Math.max(96, tabRow.implicitWidth + 18)
            color: active ? TuiStyle.panelAlt : tabMouse.containsMouse ? Qt.rgba(TuiStyle.green.r, TuiStyle.green.g, TuiStyle.green.b, 0.10) : TuiStyle.bg
            border.width: TuiStyle.borderWidth
            border.color: active || tabMouse.containsMouse ? TuiStyle.green : TuiStyle.line

            RowLayout {
                id: tabRow
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    text: tab.modelData.icon
                    iconSize: Appearance.font.pixelSize.small
                    color: tab.active ? TuiStyle.green : TuiStyle.dim
                }

                StyledText {
                    text: tab.modelData.name.toUpperCase()
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    color: tab.active ? TuiStyle.fg : TuiStyle.dim
                }
            }

            MouseArea {
                id: tabMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.setCurrentIndex(tab.index)
            }
        }
    }
}
