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
    readonly property color colorActive: "#F5C542"                       // 黄色
    readonly property color colorError:  "#FF3B30"                       // 大红

    readonly property color iconColor: {
        if (root.isError)   return root.colorError
        if (root.isActive)  return root.colorActive
        return root.colorIdle
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

    // ── 录音/激活时：黄色脉冲环 ──
    Rectangle {
        id: pulseRing
        anchors.centerIn: actionButton
        width: actionButton.width
        height: actionButton.height
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: root.colorActive
        visible: root.isActive
        opacity: 0.75

        SequentialAnimation on scale {
            running: root.isActive
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 1.65; duration: 750; easing.type: Easing.OutCubic }
            NumberAnimation { from: 1.65; to: 1.0;  duration: 0 }
        }
        SequentialAnimation on opacity {
            running: root.isActive
            loops: Animation.Infinite
            NumberAnimation { from: 0.75; to: 0; duration: 750; easing.type: Easing.OutCubic }
            NumberAnimation { from: 0; to: 0.75; duration: 0 }
        }
    }

    // ── 麦克风图标 ──
    BarNerdIcon {
        id: icon
        anchors.centerIn: actionButton
        text: {
            if (root.isTranscribing) return NerdIconMap.micTranscribing;
            if (root.isRecording) return NerdIconMap.micRecording;
            return NerdIconMap.mic;
        }

        color: root.iconColor
        Behavior on color { ColorAnimation { duration: 120 } }

        SequentialAnimation on opacity {
            id: errorBlink
            running: false
            NumberAnimation { from: 1.0; to: 0.0; duration: 80  }
            NumberAnimation { from: 0.0; to: 1.0; duration: 80  }
            NumberAnimation { from: 1.0; to: 0.0; duration: 80  }
            NumberAnimation { from: 0.0; to: 1.0; duration: 80  }
        }
    }

    // 监听 error 状态，触发闪烁
    onIsErrorChanged: {
        if (root.isError) errorBlink.start()
    }

    // ── 悬浮提示（指向时显示快捷键）──
    PopupToolTip {
        text: Translation.tr("语音输入") + " (ALT + A / Globe)"
        anchorEdges: Config.options.bar.vertical
            ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
            : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
    }
}
