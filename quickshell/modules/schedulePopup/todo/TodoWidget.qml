import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    property var tabButtonList: [{"icon": "checklist", "name": Translation.tr("Unfinished")}, {"name": Translation.tr("Done"), "icon": "check_circle"}]
    property bool showAddDialog: false
    property int dialogMargins: 20
    property int fabSize: 48
    property int fabMargins: 14

    Keys.onPressed: (event) => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageDown) {
                tabBar.incrementCurrentIndex();
            } else if (event.key === Qt.Key_PageUp) {
                tabBar.decrementCurrentIndex();
            }
            event.accepted = true;
        }
        // Open add dialog on "N" (any modifiers)
        else if (event.key === Qt.Key_N) {
            root.showAddDialog = true
            event.accepted = true;
        }
        // Close dialog on Esc if open
        else if (event.key === Qt.Key_Escape && root.showAddDialog) {
            root.showAddDialog = false
            event.accepted = true;
        }
    }

    TuiSegmentedTabs {
        id: tabBar
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.rightMargin: 8
        tabs: root.tabButtonList
        onSelected: index => swipeView.currentIndex = index
    }

    SwipeView {
        id: swipeView
        anchors.fill: parent
        anchors.topMargin: tabBar.implicitHeight + 16
        spacing: 10
        clip: true
        currentIndex: tabBar.currentIndex
        onCurrentIndexChanged: tabBar.currentIndex = currentIndex

        TaskList {
            listBottomPadding: root.fabSize + root.fabMargins * 2
            emptyPlaceholderIcon: "check_circle"
            emptyPlaceholderText: Translation.tr("Nothing here!")
            taskList: Todo.list
                .map(function(item, i) { return Object.assign({}, item, {originalIndex: i}); })
                .filter(function(item) { return !item.done; })
        }

        TaskList {
            listBottomPadding: root.fabSize + root.fabMargins * 2
            emptyPlaceholderIcon: "checklist"
            emptyPlaceholderText: Translation.tr("Finished tasks will go here")
            taskList: Todo.list
                .map(function(item, i) { return Object.assign({}, item, {originalIndex: i}); })
                .filter(function(item) { return item.done; })
        }
    }

    Rectangle {
        id: fabButton
        property int buttonRadius: TuiStyle.radius
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: root.fabMargins
        anchors.bottomMargin: root.fabMargins
        implicitWidth: root.fabSize
        implicitHeight: root.fabSize
        radius: TuiStyle.radius
        color: fabMouse.containsMouse ? TuiStyle.green : TuiStyle.bg
        border.width: TuiStyle.borderWidth
        border.color: TuiStyle.green

        MaterialSymbol {
            anchors.centerIn: parent
            text: "add"
            iconSize: Appearance.font.pixelSize.larger
            color: fabMouse.containsMouse ? TuiStyle.bg : TuiStyle.green
        }

        MouseArea {
            id: fabMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.showAddDialog = true
        }
    }

    Item {
        anchors.fill: parent
        z: 9999

        visible: opacity > 0
        opacity: root.showAddDialog ? 1 : 0
        Behavior on opacity {
            NumberAnimation { 
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Appearance.animation.elementMoveFast.type
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        onVisibleChanged: {
            if (!visible) {
                todoInput.text = ""
                fabButton.focus = true
            }
        }

        Rectangle { // Scrim
            anchors.fill: parent
            radius: 0
            color: TuiStyle.scrim
            MouseArea {
                hoverEnabled: true
                anchors.fill: parent
                preventStealing: true
                propagateComposedEvents: false
            }
        }

        Rectangle { // The dialog
            id: dialog
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: root.dialogMargins
            implicitHeight: dialogColumnLayout.implicitHeight

            color: TuiStyle.panel
            radius: 0
            border.width: 1
            border.color: TuiStyle.line

            function addTask() {
                if (todoInput.text.length > 0) {
                    Todo.addTask(todoInput.text)
                    todoInput.text = ""
                    root.showAddDialog = false
                    tabBar.setCurrentIndex(0)
                }
            }

            ColumnLayout {
                id: dialogColumnLayout
                anchors.fill: parent
                spacing: 16

                StyledText {
                    Layout.topMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.alignment: Qt.AlignLeft
                    color: TuiStyle.fg
                    font.family: Appearance.font.family.monospace
                    font.pixelSize: Appearance.font.pixelSize.larger
                    text: Translation.tr("Add task")
                }

                TextField {
                    id: todoInput
                    Layout.fillWidth: true
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    padding: 10
                    color: activeFocus ? TuiStyle.fg : TuiStyle.dim
                    font.family: Appearance.font.family.monospace
                    renderType: Text.NativeRendering
                    selectedTextColor: TuiStyle.bg
                    selectionColor: TuiStyle.green
                    placeholderText: Translation.tr("Task description")
                    placeholderTextColor: TuiStyle.dim
                    focus: root.showAddDialog
                    onAccepted: dialog.addTask()

                    background: Rectangle {
                        anchors.fill: parent
                        radius: 0
                        border.width: 1
                        border.color: todoInput.activeFocus ? TuiStyle.green : TuiStyle.line
                        color: "transparent"
                    }

                    cursorDelegate: Rectangle {
                        width: 1
                        color: todoInput.activeFocus ? TuiStyle.green : "transparent"
                        radius: 1
                    }
                }

                RowLayout {
                    Layout.bottomMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16
                    Layout.alignment: Qt.AlignRight
                    spacing: 5

                    DialogButton {
                        buttonText: Translation.tr("Cancel")
                        onClicked: root.showAddDialog = false
                    }
                    DialogButton {
                        buttonText: Translation.tr("Add")
                        enabled: todoInput.text.length > 0
                        onClicked: dialog.addTask()
                    }
                }
            }
        }
    }
}
