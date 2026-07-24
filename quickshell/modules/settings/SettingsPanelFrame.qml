import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: frame

    required property var settingsRoot
    property string title: "Settings"
    property string iconName: "settings"
    property Component pageComponent
    property bool showConfirmFooter: true

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Escape) {
            frame.settingsRoot.dismiss();
            event.accepted = true;
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: TuiStyle.shellRadius
        color: TuiStyle.bg
        border.width: TuiStyle.borderWidth
        border.color: TuiStyle.shellBorder
        clip: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: frame.settingsRoot.shellInset
            spacing: 0

            StyledFlickable {
                id: pageScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: pageLoader.y + pageLoader.height + frame.settingsRoot.pageInset

                Loader {
                    id: pageLoader
                    x: frame.settingsRoot.pageInset
                    y: frame.settingsRoot.pageInset
                    width: Math.max(0, pageScroll.width - frame.settingsRoot.pageInset * 2)
                    height: Math.max(
                        0,
                        pageScroll.height - frame.settingsRoot.pageInset * 2,
                        item ? item.implicitHeight : 0
                    )
                    sourceComponent: frame.pageComponent

                    onLoaded: {
                        if (item && item.settingsRoot !== undefined)
                            item.settingsRoot = frame.settingsRoot;
                    }
                }
            }

            // Footer
            Rectangle {
                visible: frame.showConfirmFooter
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? SettingsTokens.footerHeight : 0
                Layout.minimumHeight: Layout.preferredHeight
                Layout.maximumHeight: Layout.preferredHeight
                color: "transparent"

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    anchors.top: parent.top
                    color: SettingsTokens.line
                    opacity: 0.55
                }

                RowLayout {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: frame.settingsRoot.pageInset
                    anchors.rightMargin: frame.settingsRoot.pageInset
                    height: SettingsTokens.controlHeight
                    spacing: SettingsTokens.controlGap

                    SettingsButton {
                        Layout.fillWidth: false
                        Layout.preferredWidth: SettingsTokens.footerCloseButtonWidth
                        label: "Close"
                        iconName: "close"
                        onClicked: frame.settingsRoot.dismiss()
                    }

                    Item { Layout.fillWidth: true }

                    SettingsButton {
                        Layout.fillWidth: false
                        Layout.preferredWidth: SettingsTokens.footerButtonWidth
                        label: "Discard"
                        iconName: "undo"
                        visible: pageLoader.item && (pageLoader.item.hasPendingChanges !== undefined || pageLoader.item.hasChanges !== undefined)
                        enabledState: pageLoader.item ? (!!pageLoader.item.hasPendingChanges || !!pageLoader.item.hasChanges) : false
                        onClicked: {
                            if (pageLoader.item) {
                                if (typeof pageLoader.item.resetDrafts === "function") pageLoader.item.resetDrafts();
                                else if (typeof pageLoader.item.reset === "function") pageLoader.item.reset();
                                else if (typeof pageLoader.item.discard === "function") pageLoader.item.discard();
                            }
                        }
                    }

                    SettingsButton {
                        Layout.fillWidth: false
                        Layout.preferredWidth: SettingsTokens.footerButtonWidth
                        label: pageLoader.item && !!pageLoader.item.applying ? "Applying..." : "Apply"
                        iconName: "check"
                        visible: pageLoader.item && (pageLoader.item.hasPendingChanges !== undefined || pageLoader.item.hasChanges !== undefined)
                        active: pageLoader.item ? (!!pageLoader.item.hasPendingChanges || !!pageLoader.item.hasChanges) : false
                        enabledState: pageLoader.item ? ((!!pageLoader.item.hasPendingChanges || !!pageLoader.item.hasChanges) && !pageLoader.item.applying) : false
                        onClicked: {
                            if (pageLoader.item) {
                                if (typeof pageLoader.item.applyAll === "function") pageLoader.item.applyAll();
                                else if (typeof pageLoader.item.apply === "function") pageLoader.item.apply();
                            }
                        }
                    }
                }
            }
        }
    }
}
