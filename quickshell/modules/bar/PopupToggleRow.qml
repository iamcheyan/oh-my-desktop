// PopupToggleRow — GNOME Quick Settings toggle row.
// Label left, toggle right. Height 52px. No truncation.
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string label: ""
    property bool checked: false
    property bool showDivider: true
    property bool enabled: true
    signal toggled(bool checked)

    implicitHeight: 52
    implicitWidth: parent?.width ?? 0
    Layout.fillWidth: true

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 20
            rightMargin: 20
        }
        spacing: 12

        StyledText {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            text: root.label
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.normal + 1   // ~16px
            font.weight: Font.Normal
            color: root.enabled ? TuiStyle.fg : TuiStyle.dim
            elide: Text.ElideRight
        }

        // Toggle switch — 56×28px
        Rectangle {
            id: track
            Layout.alignment: Qt.AlignVCenter
            width: 56
            height: 28
            radius: 14
            opacity: root.enabled ? 1.0 : 0.4
            color: root.checked ? TuiStyle.accent : "#444444"

            Behavior on color { ColorAnimation { duration: 150 } }

            Rectangle {
                id: thumb
                width: 22
                height: 22
                radius: 11
                color: "#ffffff"
                anchors.verticalCenter: parent.verticalCenter
                x: root.checked ? parent.width - width - 3 : 3

                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: root.enabled
                onClicked: root.toggled(!root.checked)
            }
        }
    }

    // Bottom divider — very subtle
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: TuiStyle.line
        opacity: 0.10
        visible: root.showDivider
    }
}
