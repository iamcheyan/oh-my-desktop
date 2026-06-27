pragma ComponentBehavior: Bound
import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.schedulePopup.calendar
import qs.modules.schedulePopup.todo
import qs.modules.schedulePopup.pomodoro
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    radius: TuiStyle.radius
    color: TuiStyle.panel
    clip: true
    property bool popupMode: false
    property int selectedTab: Persistent.states.sidebar.bottomGroup.tab
    property int previousIndex: -1
    property bool collapsed: popupMode ? false : Persistent.states.sidebar.bottomGroup.collapsed
    implicitHeight: (!popupMode && collapsed) ? collapsedBottomWidgetGroupRow.implicitHeight : 350
    property var tabs: [
        {
            "type": "calendar",
            "name": Translation.tr("Calendar"),
            "icon": "calendar_month",
            "widget": Qt.resolvedUrl("calendar/CalendarWidget.qml")
        },
        {
            "type": "todo",
            "name": Translation.tr("To Do"),
            "icon": "done_outline",
            "widget": Qt.resolvedUrl("todo/TodoWidget.qml")
        },
        {
            "type": "timer",
            "name": Translation.tr("Timer"),
            "icon": "schedule",
            "widget": Qt.resolvedUrl("pomodoro/PomodoroWidget.qml")
        },
    ]

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Appearance.animation.elementMove.duration
            easing.type: Appearance.animation.elementMove.type
            easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
        }
    }

    function setCollapsed(state) {
        Persistent.states.sidebar.bottomGroup.collapsed = state;
        if (collapsed) {
            bottomWidgetGroupRow.opacity = 0;
        } else {
            collapsedBottomWidgetGroupRow.opacity = 0;
        }
        collapseCleanFadeTimer.start();
    }

    Timer {
        id: collapseCleanFadeTimer
        interval: Appearance.animation.elementMove.duration / 2
        repeat: false
        onTriggered: {
            if (collapsed)
                collapsedBottomWidgetGroupRow.opacity = 1;
            else
                bottomWidgetGroupRow.opacity = 1;
        }
    }

    Keys.onPressed: event => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.ControlModifier) {
            if (event.key === Qt.Key_PageDown) {
                root.selectedTab = Math.min(root.selectedTab + 1, root.tabs.length - 1);
            } else if (event.key === Qt.Key_PageUp) {
                root.selectedTab = Math.max(root.selectedTab - 1, 0);
            }
            Persistent.states.sidebar.bottomGroup.tab = root.selectedTab;
            event.accepted = true;
        } else if (event.key === Qt.Key_H && event.modifiers === Qt.NoModifier) {
            root.selectedTab = Math.max(root.selectedTab - 1, 0);
            Persistent.states.sidebar.bottomGroup.tab = root.selectedTab;
            event.accepted = true;
        } else if (event.key === Qt.Key_L && event.modifiers === Qt.NoModifier) {
            root.selectedTab = Math.min(root.selectedTab + 1, root.tabs.length - 1);
            Persistent.states.sidebar.bottomGroup.tab = root.selectedTab;
            event.accepted = true;
        } else if ((event.key === Qt.Key_Q || event.key === Qt.Key_Escape) && event.modifiers === Qt.NoModifier) {
            if (root.popupMode)
                GlobalStates.barPopupType = "";
            else
                GlobalStates.scheduleOpen = false;
            event.accepted = true;
        }
    }

    // The thing when collapsed
    RowLayout {
        id: collapsedBottomWidgetGroupRow
        visible: !popupMode && opacity > 0
        opacity: collapsed ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                id: collapsedBottomWidgetGroupRowFade
                duration: Appearance.animation.elementMove.duration / 2
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        spacing: 15

        CalendarHeaderButton {
            Layout.margins: 10
            Layout.rightMargin: 0
            forceCircle: true
            downAction: () => {
                root.setCollapsed(false);
            }
            contentItem: MaterialSymbol {
                text: "keyboard_arrow_up"
                iconSize: Appearance.font.pixelSize.larger
                horizontalAlignment: Text.AlignHCenter
                color: TuiStyle.fg
            }
        }

        StyledText {
            property int remainingTasks: Todo.list.filter(task => !task.done).length
            Layout.margins: 10
            Layout.leftMargin: 0
            text: Translation.tr("%1   •   %2 tasks").arg(DateTime.collapsedCalendarFormat).arg(remainingTasks)
            font.family: Appearance.font.family.monospace
            font.pixelSize: Appearance.font.pixelSize.large
            color: TuiStyle.fg
        }
    }

    // The thing when expanded
    RowLayout {
        id: bottomWidgetGroupRow

        opacity: collapsed ? 0 : 1
        visible: opacity > 0
        Behavior on opacity {
            NumberAnimation {
                id: bottomWidgetGroupRowFade
                duration: Appearance.animation.elementMove.duration / 2
                easing.type: Appearance.animation.elementMove.type
                easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
            }
        }

        anchors.fill: parent
        // implicitHeight: tabStack.implicitHeight
        spacing: 12

        // Navigation rail
        Rectangle {
            Layout.fillHeight: true
            Layout.fillWidth: false
            Layout.leftMargin: 8
            Layout.topMargin: 8
            Layout.bottomMargin: 8
            implicitWidth: 112
            color: TuiStyle.bg
            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.line

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 8
                spacing: 6

                StyledText {
                    Layout.fillWidth: true
                    text: "SCHEDULE"
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    color: TuiStyle.green
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: TuiStyle.borderWidth
                    color: TuiStyle.line
                }

                Repeater {
                    model: root.tabs
                    TuiTabButton {
                        required property int index
                        required property var modelData
                        Layout.fillWidth: true
                        active: root.selectedTab == index
                        label: modelData.name
                        icon: modelData.icon
                        onClicked: {
                            root.selectedTab = index;
                            Persistent.states.sidebar.bottomGroup.tab = index;
                        }
                    }
                }

                Item {
                    Layout.fillHeight: true
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "q close\nh/l tab"
                    lineHeight: 1.15
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: TuiStyle.dim
                }
            }

            // Collapse button
            CalendarHeaderButton {
                visible: !root.popupMode
                anchors.left: parent.left
                anchors.top: parent.top
                forceCircle: true
                downAction: () => {
                    root.setCollapsed(true);
                }
                contentItem: MaterialSymbol {
                    text: "keyboard_arrow_down"
                    iconSize: Appearance.font.pixelSize.larger
                    horizontalAlignment: Text.AlignHCenter
                    color: TuiStyle.fg
                }
            }
        }

        // Content area
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            // implicitHeight: tabStack.implicitHeight

            Loader {
                id: tabStack
                anchors.fill: parent
                anchors.bottomMargin: -anchors.topMargin

                Component.onCompleted: {
                    tabStack.source = root.tabs[root.selectedTab].widget;
                }

                Connections {
                    target: root
                    function onSelectedTabChanged() {
                        if (root.selectedTab > root.previousIndex)
                            tabSwitchBehavior.animation.down = true;
                        else if (root.selectedTab < root.previousIndex)
                            tabSwitchBehavior.animation.down = false;
                        tabStack.source = root.tabs[root.selectedTab].widget;
                    }
                }

                Behavior on source {
                    id: tabSwitchBehavior
                    animation: TabSwitchAnim {
                        id: upAnim
                        down: true
                    }
                }
            }
        }
    }

    component TabSwitchAnim: SequentialAnimation {
        id: switchAnim
        property bool down: false
        ParallelAnimation {
            PropertyAnimation {
                target: tabStack
                properties: "opacity"
                to: 0
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
            PropertyAnimation {
                target: tabStack.anchors
                properties: "topMargin"
                to: 10 * (switchAnim.down ? -1 : 1)
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }
        PropertyAction {
            target: tabStack
            property: "source"
            value: root.tabs[root.selectedTab].widget
        } // The source change happens here
        ParallelAnimation {
            PropertyAnimation {
                target: tabStack.anchors
                properties: "topMargin"
                from: 10 * -(switchAnim.down ? -1 : 1)
                to: 0
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
            PropertyAnimation {
                target: tabStack
                properties: "opacity"
                to: 1
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMoveEnter.bezierCurve
            }
        }
        ScriptAction {
            script: {
                root.previousIndex = root.selectedTab;
            }
        }
    }

    component TuiTabButton: Rectangle {
        id: tabButton
        signal clicked
        property bool active: false
        property string label: ""
        property string icon: ""

        implicitHeight: 34
        color: active ? TuiStyle.panelAlt : tabMouse.containsMouse ? Qt.rgba(TuiStyle.green.r, TuiStyle.green.g, TuiStyle.green.b, 0.10) : "transparent"
        border.width: TuiStyle.borderWidth
        border.color: active || tabMouse.containsMouse ? TuiStyle.green : TuiStyle.line

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 8

            MaterialSymbol {
                text: tabButton.icon
                iconSize: Appearance.font.pixelSize.normal
                color: tabButton.active ? TuiStyle.green : TuiStyle.dim
            }

            StyledText {
                Layout.fillWidth: true
                text: tabButton.label.toUpperCase()
                elide: Text.ElideRight
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Bold
                color: tabButton.active ? TuiStyle.fg : TuiStyle.dim
            }
        }

        MouseArea {
            id: tabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tabButton.clicked()
        }
    }
}
