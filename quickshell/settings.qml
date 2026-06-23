//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Adjust this to make the app smaller or larger
//@ pragma Env QT_SCALE_FACTOR=1

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions as CF

ApplicationWindow {
    id: root
    property string firstRunFilePath: CF.FileUtils.trimFileProtocol(`${Directories.state}/user/first_run.txt`)
    property string firstRunFileContent: "This file is just here to confirm you've been greeted :>"
    property real contentPadding: 8
    property bool showNextTime: false
    property var pages: [
        {
            name: Translation.tr("Quick"),
            icon: "instant_mix",
            component: "modules/settings/QuickConfig.qml"
        },
        {
            name: Translation.tr("General"),
            icon: "browse",
            component: "modules/settings/GeneralConfig.qml"
        },
        {
            name: Translation.tr("Bar"),
            icon: "toast",
            iconRotation: 180,
            component: "modules/settings/BarConfig.qml"
        },
        {
            name: Translation.tr("Background"),
            icon: "texture",
            component: "modules/settings/BackgroundConfig.qml"
        },
        {
            name: Translation.tr("Interface"),
            icon: "bottom_app_bar",
            component: "modules/settings/InterfaceConfig.qml"
        },
        {
            name: Translation.tr("Services"),
            icon: "settings",
            component: "modules/settings/ServicesConfig.qml"
        },
        {
            name: Translation.tr("Advanced"),
            icon: "construction",
            component: "modules/settings/AdvancedConfig.qml"
        },
        {
            name: Translation.tr("About"),
            icon: "info",
            component: "modules/settings/About.qml"
        }
    ]
    property int currentPage: 0

    component TuiSettingsButton: Item {
        id: button
        property string buttonText: ""
        property bool toggled: false
        property bool hovered: hoverArea.containsMouse
        property bool pressed: hoverArea.pressed
        signal clicked()
        signal rightClicked()

        implicitHeight: 28
        implicitWidth: label.implicitWidth + 16

        Rectangle {
            anchors.fill: parent
            radius: 0
            color: button.pressed ? Appearance.tiling.bgActive
                : button.hovered || button.toggled ? Appearance.tiling.bgHover
                : "transparent"
            border.width: Appearance.tiling.borderWidth
            border.color: button.toggled ? Appearance.tiling.borderFocus
                : button.hovered ? Appearance.tiling.borderFocus
                : Appearance.tiling.border
        }

        StyledText {
            id: label
            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: parent.verticalCenter
                leftMargin: 8
                rightMargin: 8
            }
            text: button.buttonText
            elide: Text.ElideRight
            maximumLineCount: 1
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.small
            color: button.toggled ? Appearance.tiling.textBright : Appearance.tiling.text
        }

        MouseArea {
            id: hoverArea
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton)
                    button.rightClicked();
                else
                    button.clicked();
            }
        }
    }

    visible: true
    onClosing: Qt.quit()
    title: "illogical-impulse Settings"

    Component.onCompleted: {
        Config.readWriteDelay = 0 // Settings app always only sets one var at a time so delay isn't needed
    }

    minimumWidth: 750
    minimumHeight: 500
    width: 1100
    height: 750
    color: Appearance.tiling.bg

    ColumnLayout {
        anchors {
            fill: parent
            margins: contentPadding
        }

        Keys.onPressed: (event) => {
            if (event.modifiers === Qt.ControlModifier) {
                if (event.key === Qt.Key_PageDown) {
                    root.currentPage = Math.min(root.currentPage + 1, root.pages.length - 1)
                    event.accepted = true;
                } 
                else if (event.key === Qt.Key_PageUp) {
                    root.currentPage = Math.max(root.currentPage - 1, 0)
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Tab) {
                    root.currentPage = (root.currentPage + 1) % root.pages.length;
                    event.accepted = true;
                }
                else if (event.key === Qt.Key_Backtab) {
                    root.currentPage = (root.currentPage - 1 + root.pages.length) % root.pages.length;
                    event.accepted = true;
                }
            }
        }

        Rectangle { // Titlebar
            visible: Config.options?.windows.showTitlebar
            Layout.fillWidth: true
            Layout.fillHeight: false
            implicitHeight: Appearance.tiling.titlebarHeight + 2
            radius: 0
            color: Appearance.tiling.bgTitlebar
            border.width: Appearance.tiling.borderWidth
            border.color: Appearance.tiling.border
            StyledText {
                id: titleText
                anchors {
                    left: parent.left
                    verticalCenter: parent.verticalCenter
                    leftMargin: 8
                }
                color: Appearance.tiling.textBright
                text: `settings:${root.pages[root.currentPage].name.toLowerCase()}`
                font {
                    family: Appearance.font.family.monospace
                    pixelSize: Appearance.font.pixelSize.small
                }
            }
            RowLayout { // Window controls row
                id: windowControlsRow
                anchors.verticalCenter: parent.verticalCenter
                anchors.right: parent.right
                anchors.rightMargin: 4
                TuiSettingsButton {
                    buttonText: "x"
                    onClicked: root.close()
                }
            }
        }

        RowLayout { // Window content with navigation rail and content pane
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            Rectangle {
                id: navRailWrapper
                Layout.fillHeight: true
                implicitWidth: 176
                radius: 0
                color: Appearance.tiling.bg
                border.width: Appearance.tiling.borderWidth
                border.color: Appearance.tiling.border

                ColumnLayout {
                    anchors {
                        fill: parent
                        margins: 6
                    }
                    spacing: 4

                    TuiSettingsButton {
                        id: configPathButton
                        property bool justCopied: false
                        Layout.fillWidth: true
                        buttonText: justCopied ? "copied" : "config file"
                        onClicked: {
                            Qt.openUrlExternally(`${Directories.config}/quickshell/config.json`);
                        }
                        onRightClicked: {
                            Quickshell.clipboardText = CF.FileUtils.trimFileProtocol(`${Directories.config}/quickshell/config.json`);
                            configPathButton.justCopied = true;
                            revertTextTimer.restart()
                        }
                        StyledToolTip {
                            text: Translation.tr("Open the shell config file\nRight-click to copy path")
                        }
                        Timer {
                            id: revertTextTimer
                            interval: 1500
                            onTriggered: configPathButton.justCopied = false
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Appearance.tiling.border
                    }

                    Repeater {
                        model: root.pages
                        TuiSettingsButton {
                            required property int index
                            required property var modelData
                            Layout.fillWidth: true
                            buttonText: `${index + 1}. ${modelData.name.toLowerCase()}`
                            toggled: root.currentPage === index
                            onClicked: root.currentPage = index
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    TuiSettingsButton {
                        Layout.fillWidth: true
                        buttonText: "copy path"
                        onClicked: {
                            Quickshell.clipboardText = CF.FileUtils.trimFileProtocol(`${Directories.config}/quickshell/config.json`);
                            configPathButton.justCopied = true;
                            revertTextTimer.restart();
                        }
                    }
                }
            }
            Rectangle { // Content container
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: Appearance.tiling.bg
                radius: 0
                border.width: Appearance.tiling.borderWidth
                border.color: Appearance.tiling.border

                Loader {
                    id: pageLoader
                    anchors.fill: parent
                    opacity: 1.0

                    active: Config.ready
                    Component.onCompleted: {
                        source = root.pages[0].component
                    }

                    Connections {
                        target: root
                        function onCurrentPageChanged() {
                            switchAnim.complete();
                            switchAnim.start();
                        }
                    }

                    SequentialAnimation {
                        id: switchAnim

                        PropertyAction {
                            target: pageLoader
                            property: "opacity"
                            value: 0
                        }
                        ParallelAnimation {
                            PropertyAction {
                                target: pageLoader
                                property: "source"
                                value: root.pages[root.currentPage].component
                            }
                            PropertyAction {
                                target: pageLoader
                                property: "anchors.topMargin"
                                value: 0
                            }
                        }
                        PropertyAction {
                            target: pageLoader
                            property: "opacity"
                            value: 1
                        }
                    }
                }
            }
        }
    }
}
