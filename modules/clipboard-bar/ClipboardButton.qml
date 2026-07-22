import Quickshell
import qs.core.runtime
import qs
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

    readonly property real barHeight: Config.options.bar.cornerStyle === 1
        ? (32 + Appearance.sizes.hyprlandGapsOut * 2) : 32

    RippleButton {
        id: clipboardButton
        anchors.centerIn: parent
        width: Config.options.bar.rightIconSlotWidth
        height: Config.options.bar.rightIconSlotWidth
        buttonRadius: Config.options.bar.rightIconSlotWidth / 2
        colBackground: "transparent"
        colBackgroundHover: Qt.rgba(1, 1, 1, 0.10)
        colBackgroundToggled: Qt.rgba(1, 1, 1, 0.18)
        colBackgroundToggledHover: Qt.rgba(1, 1, 1, 0.26)
        colRipple: Qt.rgba(1, 1, 1, 0.12)
        colRippleToggled: Qt.rgba(1, 1, 1, 0.18)
        toggled: GlobalStates.barPopupType === "clipboard"

        onClicked: {
            if (Date.now() - GlobalStates.barPopupDismissedAt < 200) return;
            const wasOpen = GlobalStates.barPopupType === "clipboard";
            GlobalStates.barPopupType = wasOpen ? "" : "clipboard";
            ActionManager.invoke("clipboard.toggleBar", {height: root.barHeight});
        }
    }

    BarNerdIcon {
        anchors.centerIn: clipboardButton
        text: NerdIconMap.contentPaste
        color: Appearance.colors.colBarText
    }
}
