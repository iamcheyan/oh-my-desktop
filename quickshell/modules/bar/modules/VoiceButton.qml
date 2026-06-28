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
            if (root.isError)   return ColorUtils.transparentize(Appearance.m3colors.m3error, 0.45)
            if (root.isSuccess) return ColorUtils.transparentize(Appearance.m3colors.m3tertiary, 0.45)
            return ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        }
        colBackgroundHover: {
            if (root.isError)   return ColorUtils.transparentize(Appearance.m3colors.m3error, 0.30)
            if (root.isSuccess) return ColorUtils.transparentize(Appearance.m3colors.m3tertiary, 0.30)
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
            NumberAnimation { from: 1.0; to: 1.6; duration: 700; easing.type: Easing.OutCubic }
            NumberAnimation { from: 1.6; to: 1.0; duration: 0 }
        }
        SequentialAnimation on opacity {
            running: root.isRecording
            loops: Animation.Infinite
            NumberAnimation { from: 0.7; to: 0; duration: 700; easing.type: Easing.OutCubic }
            NumberAnimation { from: 0; to: 0.7; duration: 0 }
        }
    }

    // ── 图标（始终显示麦克风，状态通过颜色和动画区分）──
    CosmicIcon {
        id: icon
        anchors.centerIn: actionButton
        iconSize: Config.options.bar.rightIconSize
        opacity: (root.isTranscribing || root.isSetup) ? 0.5 : 1.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        color: {
            if (root.isRecording || root.isError) return Appearance.m3colors.m3error
            if (root.isSuccess)                   return Appearance.m3colors.m3tertiary
            return Appearance.colors.colBarText
        }
        Behavior on color { ColorAnimation { duration: 150 } }

        name: {
            if (root.isError)   return "status/dialog-warning-symbolic"
            if (root.isSuccess) return "checkbox-checked-symbolic"
            return "status/microphone-sensitivity-high-symbolic"
        }
    }

    // ── 转写中：细小旋转圆弧（角标式）──
    Item {
        anchors.centerIn: actionButton
        width: actionButton.width
        height: actionButton.height
        visible: root.isTranscribing || root.isSetup
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // 旋转的细圆弧（用小矩形裁剪出弧形感）
        Rectangle {
            id: spinnerArc
            anchors.centerIn: parent
            width: parent.width + 6
            height: parent.height + 6
            radius: width / 2
            color: "transparent"
            border.width: 1.5
            border.color: Appearance.m3colors.m3primary
            opacity: 0.55

            RotationAnimation on rotation {
                running: root.isTranscribing || root.isSetup
                loops: Animation.Infinite
                from: 0; to: 360
                duration: 1100
                easing.type: Easing.Linear
            }
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
