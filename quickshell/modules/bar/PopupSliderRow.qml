// PopupSliderRow — icon + slider + numeric value.
// Used for volume, brightness, etc.
//
// Usage:
//   PopupSliderRow {
//       icon: NerdIconMap.volumeHigh
//       value: 0.39           // 0.0 – 1.0
//       muted: Audio.muted
//       showDivider: true
//       onMoved: value => Audio.setSinkVolume(value)
//       onIconClicked: Audio.toggleMute()
//   }
pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string icon: ""
    property real value: 0      // 0.0 – 1.0
    property bool muted: false
    property bool showDivider: true
    property color accentColor: TuiStyle.accent

    signal moved(real value)
    signal iconClicked()

    Layout.fillWidth: true
    implicitHeight: 56
    implicitWidth: parent?.width ?? row.implicitWidth

    RowLayout {
        id: row
        anchors {
            fill: parent
            leftMargin: 20
            rightMargin: 20
        }
        spacing: 10

        // Tappable icon (mute toggle etc.)
        Item {
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            Layout.alignment: Qt.AlignVCenter

            NerdIcon {
                anchors.centerIn: parent
                iconSize: 20
                text: root.icon
                color: root.muted ? TuiStyle.danger : TuiStyle.fg
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.iconClicked()
            }
        }

        // Slider
        SettingsSlider {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            trackColor: SettingsTokens.line
            highlightColor: root.muted ? SettingsTokens.danger : root.accentColor
            handleColor: SettingsTokens.fg
            value: root.muted ? 0 : root.value
            onValueChanged: {
                if (pressed)
                    root.moved(value)
            }
        }

        // Numeric label
        StyledText {
            Layout.preferredWidth: 38
            horizontalAlignment: Text.AlignRight
            Layout.alignment: Qt.AlignVCenter
            text: `${Math.round((root.muted ? 0 : root.value) * 100)}`
            font.family: Appearance.font.family.main
            font.pixelSize: Appearance.font.pixelSize.normal
            font.weight: Font.Medium
            color: root.muted ? SettingsTokens.danger : SettingsTokens.muted
        }
    }

    // Bottom divider
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: SettingsTokens.line
        opacity: TuiStyle.dividerOpacity
        visible: root.showDivider
    }
}
