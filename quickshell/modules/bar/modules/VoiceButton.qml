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
    readonly property bool isRecording:    root.state === "recording"
    readonly property bool isTranscribing: root.state === "transcribing"
    readonly property bool isSetup:        root.state === "setup"
    readonly property bool isError:        root.state === "error"
    readonly property bool isActive:       root.isRecording || root.isTranscribing || root.isSetup

    // ── 颜色定义 ──
    readonly property color colorIdle:   Appearance.colors.colBarText   // 白/默认
    readonly property color colorRecording: "#F5C542"                    // 黄色
    readonly property color colorTranscribing: "#5B9BD5"                 // 蓝色
    readonly property color colorError:  "#FF3B30"                       // 大红

    readonly property color iconColor: {
        if (root.isError)        return root.colorError
        if (root.isRecording)    return root.colorRecording
        if (root.isTranscribing) return root.colorTranscribing
        if (root.isSetup)        return root.colorRecording
        return root.colorIdle
    }

    readonly property string iconText: {
        if (root.isTranscribing) return NerdIconMap.hourglass
        return NerdIconMap.mic
    }

    // ── 主按钮（透明背景）──
    RippleButton {
        id: actionButton
        anchors.centerIn: parent
        width: Config.options.bar.rightIconSlotWidth
        height: Config.options.bar.rightIconSlotWidth
        buttonRadius: Appearance.rounding.full

        colBackground:      ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
        colRipple:          ColorUtils.transparentize(Appearance.colors.colLayer1Active, 1)

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
            if (voiceMenuLoader.item) {
                voiceMenuLoader.item.open();
            } else {
                voiceMenuLoader.active = true;
            }
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

    // ── 录音/激活时：脉冲环 ──
    Rectangle {
        id: pulseRing
        anchors.centerIn: actionButton
        width: actionButton.width
        height: actionButton.height
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: root.isRecording ? root.colorRecording
                    : root.isTranscribing ? root.colorTranscribing
                    : root.colorRecording
        visible: root.isActive
        opacity: 0.75

        SequentialAnimation on scale {
            running: root.isRecording
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.65; duration: 750; easing.type: Easing.OutCubic }
            NumberAnimation { from: 1.65; to: 1.0;  duration: 0 }
        }
        SequentialAnimation on opacity {
            running: root.isRecording
            loops: Animation.Infinite
            NumberAnimation { from: 0.75; to: 0; duration: 750; easing.type: Easing.OutCubic }
            NumberAnimation { from: 0; to: 0.75; duration: 0 }
        }
    }

    // ── 图标 ──
    BarNerdIcon {
        id: icon
        anchors.centerIn: actionButton
        // 漏斗图标稍小，避免视觉过大
        iconSize: root.isTranscribing
            ? Config.options.bar.rightIconSize * 0.72
            : Config.options.bar.rightIconSize
        text: root.iconText

        color: root.iconColor
        Behavior on color { ColorAnimation { duration: 120 } }

        // 录音时缓慢呼吸式闪烁
        SequentialAnimation on opacity {
            id: recordingBlink
            running: root.isRecording && !root.isError
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.3; duration: 500 }
            NumberAnimation { from: 0.3; to: 1.0; duration: 500 }
        }
    }

    // 错误时快速闪烁（独立动画，避免与 recordingBlink 冲突）
    SequentialAnimation {
        id: errorBlink
        running: false
        loops: 2
        NumberAnimation { target: icon; property: "opacity"; from: 1.0; to: 0.0; duration: 80  }
        NumberAnimation { target: icon; property: "opacity"; from: 0.0; to: 1.0; duration: 80  }
        NumberAnimation { target: icon; property: "opacity"; from: 1.0; to: 0.0; duration: 80  }
        NumberAnimation { target: icon; property: "opacity"; from: 0.0; to: 1.0; duration: 80  }
        onStopped: icon.opacity = 1.0
    }

    // 转写时缓慢旋转漏斗
    SequentialAnimation {
        id: rotateAnim
        running: root.isTranscribing
        loops: Animation.Infinite
        NumberAnimation {
            target: icon
            property: "rotation"
            from: 0
            to: 180
            duration: 2000
            easing.type: Easing.InOutQuad
        }
        PauseAnimation { duration: 300 }
        PropertyAction {
            target: icon
            property: "rotation"
            value: 0
        }
        onStopped: {
            icon.rotation = 0;
        }
    }

    // 监听 error 状态，触发闪烁
    onIsErrorChanged: {
        if (root.isError) errorBlink.start()
    }

    // ── Transparent MouseArea for hover detection ──
    MouseArea {
        id: hoverArea
        anchors.fill: actionButton
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
    }

    // ── 悬浮提示（指向时显示快捷键）──
    VoiceHoverPopup {
        id: voiceHoverPopup
        hoverTarget: hoverArea
    }
}
