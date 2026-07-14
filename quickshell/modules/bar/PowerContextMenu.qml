pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

PopupWindow {
    id: root

    // Style tokens aligned with TuiStyle and GNOME-style appearance
    readonly property int   itemHeight:      32
    readonly property int   itemRadius:       6
    readonly property int   iconColumnWidth: 20
    readonly property int   iconSize:        18
    readonly property real  hPadding:         8
    readonly property real  menuPadding:      4
    readonly property real  outerPadding:     Appearance.sizes.elevationMargin

    signal menuClosed()

    color: "transparent"

    implicitWidth:  popupBackground.implicitWidth  + root.outerPadding * 2
    implicitHeight: popupBackground.implicitHeight + root.outerPadding * 2

    property bool hibernateAvailable: false

    Process {
        command: ["bash", "-c", "grep -q disk /sys/power/state 2>/dev/null && echo YES || echo NO"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.hibernateAvailable = text.trim() === "YES"
        }
    }

    function open()  {
        root.visible = true;
    }
    
    function close() {
        root.visible = false;
        root.menuClosed();
    }

    Component.onDestruction: {
        dismissGuard.stop();
        GlobalFocusGrab.removeDismissable(root);
    }

    Timer {
        id: dismissGuard
        interval: 180
        repeat: false
        onTriggered: {
            if (root.visible)
                GlobalFocusGrab.addDismissable(root);
        }
    }

    onVisibleChanged: {
        if (visible) {
            dismissGuard.restart();
        } else {
            dismissGuard.stop();
            GlobalFocusGrab.removeDismissable(root);
        }
    }

    Connections {
        target: GlobalFocusGrab
        function onDismissed() {
            root.close()
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        onPressed: event => {
            const pos = mapToItem(popupBackground, event.x, event.y)
            if (pos.x < 0 || pos.x > popupBackground.width || pos.y < 0 || pos.y > popupBackground.height)
                root.close();
        }

        StyledRectangularShadow {
            target:  popupBackground
            opacity: popupBackground.opacity
        }

        Rectangle {
            id: popupBackground
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: root.outerPadding
            }
            color:        TuiStyle.bg
            radius:       TuiStyle.shellRadius
            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.menuBorder
            clip:         true

            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: popupBackground.width
                    height: popupBackground.height
                    radius: popupBackground.radius
                }
            }

            opacity: 0
            Component.onCompleted: opacity = 1
            implicitWidth:  columnLayout.implicitWidth  + root.menuPadding * 2
            implicitHeight: columnLayout.implicitHeight + root.menuPadding * 2

            Behavior on opacity        { animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(popupBackground) }
            Behavior on implicitHeight { NumberAnimation { duration: 120 } }
            Behavior on implicitWidth  { animation: Appearance.animation.elementResize.numberAnimation.createObject(popupBackground) }

            ColumnLayout {
                id: columnLayout
                anchors {
                    fill:    parent
                    margins: root.menuPadding
                }
                spacing: 0

                // MenuItem helper component defined inline
                component MenuItem : RippleButton {
                    id: itemRoot
                    property string menuIcon: ""
                    property string label: ""
                    property color color: TuiStyle.fg
                    
                    buttonRadius:      root.itemRadius
                    horizontalPadding: root.hPadding
                    topPadding:        0
                    bottomPadding:     0
                    implicitHeight:    root.itemHeight
                    height:            root.itemHeight
                    Layout.fillWidth:  true

                    colBackground:      "transparent"
                    colBackgroundHover: TuiStyle.surfaceHover
                    colRipple:          TuiStyle.surfacePressed
                    borderWidth:        0

                    contentItem: RowLayout {
                        spacing: 8
                        Item {
                            Layout.preferredWidth:  root.iconColumnWidth
                            Layout.preferredHeight: root.iconColumnWidth
                            Layout.alignment:       Qt.AlignVCenter
                            NerdIcon {
                                anchors.centerIn: parent
                                iconSize: root.iconSize
                                text:     itemRoot.menuIcon
                                color:    itemRoot.color
                                visible:  itemRoot.menuIcon !== ""
                            }
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text:             itemRoot.label
                            color:            itemRoot.color
                            elide:            Text.ElideRight
                            font {
                                pixelSize: 13
                                weight:    Font.Normal
                            }
                        }
                    }
                }

                // Separator helper component defined inline
                component Separator : Rectangle {
                    Layout.fillWidth:    true
                    implicitHeight:      1
                    color:               TuiStyle.line
                    opacity:             TuiStyle.dividerOpacity
                    Layout.topMargin:    4
                    Layout.bottomMargin: 4
                }

                MenuItem {
                    visible:  root.hibernateAvailable
                    menuIcon: NerdIconMap.download
                    label:    "Hibernate"
                    onClicked: {
                        root.close();
                        Session.hibernate();
                    }
                }

                Separator {
                    visible: root.hibernateAvailable
                }

                MenuItem {
                    menuIcon: NerdIconMap.logout
                    label:    "Logout"
                    onClicked: {
                        root.close();
                        Session.logout();
                    }
                }

                MenuItem {
                    menuIcon: NerdIconMap.restart
                    label:    "Reboot"
                    onClicked: {
                        root.close();
                        Session.reboot();
                    }
                }

                MenuItem {
                    menuIcon: NerdIconMap.powerSettingsNew
                    label:    "Shutdown"
                    onClicked: {
                        root.close();
                        Session.poweroff();
                    }
                }

                Separator {}

                MenuItem {
                    menuIcon: NerdIconMap.settings
                    label:    "Settings"
                    onClicked: {
                        root.close();
                        Quickshell.execDetached([
                            `${FileUtils.trimFileProtocol(Directories.config)}/omd/bin/omd-settings`, "open", "overview"
                        ]);
                    }
                }

                MenuItem {
                    menuIcon: NerdIconMap.refresh
                    label:    "Reload Shell"
                    onClicked: {
                        root.close();
                        Quickshell.execDetached(["bash", `${FileUtils.trimFileProtocol(Directories.config)}/scripts/reload-quickshell`]);
                    }
                }
            }
        }
    }
}
