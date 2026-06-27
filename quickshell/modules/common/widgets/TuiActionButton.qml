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

    Layout.preferredWidth: Math.max(92, buttonText.implicitWidth + horizontalPadding)
    Layout.preferredHeight: preferredHeight
    radius: TuiStyle.radius
    color: actuallyEnabled && actionMouse.containsMouse ? Qt.rgba(accent.r, accent.g, accent.b, 0.16) : filled ? TuiStyle.panel : "transparent"
    border.width: TuiStyle.borderWidth
    border.color: actuallyEnabled ? (actionMouse.containsMouse ? accent : TuiStyle.line) : TuiStyle.line
    opacity: actuallyEnabled ? 1 : 0.45

    StyledText {
        id: buttonText
        anchors.centerIn: parent
        text: root.label
        font.family: Appearance.font.family.monospace
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.Bold
        color: root.actuallyEnabled ? root.accent : TuiStyle.dim
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
