import qs.modules.common
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    property string label: ""
    property color accent: TuiStyle.accent
    property bool enabledState: true
    property bool filled: true
    property int horizontalPadding: 24
    property int preferredHeight: TuiStyle.buttonHeight
    readonly property bool actuallyEnabled: enabled && enabledState
    signal clicked()

    Layout.preferredWidth: Math.max(104, buttonText.implicitWidth + horizontalPadding)
    Layout.preferredHeight: preferredHeight
    radius: TuiStyle.radius
    color: filled
        ? (actuallyEnabled && actionMouse.containsMouse ? "#4d4d4d" : "#2b2b2b")
        : "transparent"
    border.width: 0
    opacity: actuallyEnabled ? 1 : 0.45

    StyledText {
        id: buttonText
        anchors.centerIn: parent
        text: root.label
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.Medium
        color: root.actuallyEnabled ? TuiStyle.fg : TuiStyle.dim
    }

    MouseArea {
        id: actionMouse
        anchors.fill: parent
        enabled: root.actuallyEnabled
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
