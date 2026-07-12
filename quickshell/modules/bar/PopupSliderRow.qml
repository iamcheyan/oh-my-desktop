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
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.widgets
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

    implicitHeight: 52
    implicitWidth: row.implicitWidth

    RowLayout {
        id: row
        anchors {
            fill: parent
            leftMargin: 2
            rightMargin: 2
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
            trackColor: TuiStyle.meterTrack
            highlightColor: root.muted ? TuiStyle.danger : root.accentColor
            handleColor: TuiStyle.fg
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
            color: root.muted ? TuiStyle.danger : TuiStyle.dim
        }
    }

    // Bottom divider
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 1
        color: TuiStyle.line
        opacity: TuiStyle.dividerOpacity
        visible: root.showDivider
    }
}
