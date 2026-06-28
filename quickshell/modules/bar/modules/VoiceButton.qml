import Quickshell
import qs.modules.bar
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    implicitWidth: Config.options.bar.rightIconSlotWidth
    implicitHeight: Config.options.bar.rightIconSlotWidth
    property bool hovered: actionButton.hovered || (voiceMenuLoader.item ? voiceMenuLoader.item.visible : false)

    readonly property string state: VoiceInput.state
    readonly property bool isRecording: root.state === "recording"
    readonly property bool isTranscribing: root.state === "transcribing"
    readonly property bool isSetup: root.state === "setup"
    readonly property bool isError: root.state === "error"
    readonly property bool isSuccess: root.state === "success"

    // ── 主按钮 ──
    RippleButton {
        id: actionButton
        anchors.centerIn: parent
        width: Config.options.bar.rightIconSlotWidth
        height: Config.options.bar.rightIconSlotWidth
        buttonRadius: Appearance.rounding.full

        colBackground: {
            if (root.isRecording) return ColorUtils.transparentize(Appearance.m3colors.m3error, 0.65)
            if (root.isError)     return ColorUtils.transparentize(Appearance.m3colors.m3error, 0.45)
            if (root.isSuccess)   return ColorUtils.transparentize(Appearance.m3colors.m3tertiary, 0.45)
            if (root.isTranscribing || root.isSetup)
                return ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.30)
            return ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        }
        colBackgroundHover: {
            if (root.isRecording) return ColorUtils.transparentize(Appearance.m3colors.m3error, 0.45)
            if (root.isError)     return ColorUtils.transparentize(Appearance.m3colors.m3error, 0.30)
            if (root.isSuccess)   return ColorUtils.transparentize(Appearance.m3colors.m3tertiary, 0.30)
            if (root.isTranscribing || root.isSetup)
                return ColorUtils.transparentize(Appearance.m3colors.m3primary, 0.20)
            return ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        }
        colRipple: ColorUtils.transparentize(Appearance.colors.colLayer1Active, 1)

        onClicked: VoiceInput.toggle()
    }

    // ── 右键菜单 ──
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onPressed: (event) => {
            if (event.button === Qt.RightButton) {
                voiceMenuLoader.open();
            }
        }
    }

    Loader {
        id: voiceMenuLoader
        function open() {
            voiceMenuLoader.active = true;
        }
        active: false
        sourceComponent: VoiceContextMenu {
            Component.onCompleted: this.open();
            anchor {
                window: actionButton.QsWindow.window
                item: actionButton
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onMenuClosed: {
                voiceMenuLoader.active = false;
            }
        }
    }

    // ── 录音中的红色脉冲环 ──
    Rectangle {
        id: pulseRing
        anchors.centerIn: actionButton
        width: actionButton.width
        height: actionButton.height
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: Appearance.m3colors.m3error
        visible: root.isRecording
        opacity: 0.7

        SequentialAnimation on scale {
            running: root.isRecording
            loops: Animation.Infinite
            NumberAnimation { to: 1.6; duration: 700; easing.type: Easing.OutCubic }
            NumberAnimation { to: 1.0; duration: 0 }
        }
        SequentialAnimation on opacity {
            running: root.isRecording
            loops: Animation.Infinite
            NumberAnimation { to: 0; duration: 700; easing.type: Easing.OutCubic }
            NumberAnimation { to: 0.7; duration: 0 }
        }
    }

    // ── 图标 ──
    CosmicIcon {
        id: icon
        anchors.centerIn: actionButton
        iconSize: Config.options.bar.rightIconSize
        color: {
            if (root.isRecording || root.isError) return Appearance.m3colors.m3error
            if (root.isSuccess) return Appearance.m3colors.m3tertiary
            if (root.isTranscribing || root.isSetup) return Appearance.m3colors.m3primary
            return Appearance.colors.colBarText
        }
        name: {
            if (root.isRecording)   return "status/microphone-sensitivity-muted-symbolic"
            if (root.isTranscribing || root.isSetup)
                return "status/network-transmit-receive-symbolic"
            if (root.isError)       return "status/dialog-warning-symbolic"
            if (root.isSuccess)     return "checkbox-checked-symbolic"
            return "status/microphone-sensitivity-high-symbolic"
        }

        RotationAnimation on rotation {
            running: root.isTranscribing || root.isSetup
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 900
        }
    }

    // ── 成功时的绿色闪烁覆盖层 ──
    Rectangle {
        anchors.fill: actionButton
        radius: actionButton.buttonRadius
        color: Appearance.m3colors.m3tertiary
        opacity: root.isSuccess ? 0.4 : 0
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
    }
}
