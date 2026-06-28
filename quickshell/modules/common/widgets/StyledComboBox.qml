pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ComboBox {
    id: root

    property string buttonIcon: ""
    property real buttonRadius: 0
    property color colBackground: "#181818"
    property color colBackgroundHover: "#333333"
    property color colBackgroundActive: "#222222"

    implicitHeight: 34
    Layout.fillWidth: true

    background: Rectangle {
        radius: root.buttonRadius
        color: (root.down && !root.popup.visible) ? root.colBackgroundActive : root.hovered ? root.colBackgroundHover : root.colBackground
        border.width: TuiStyle.borderWidth
        border.color: root.activeFocus || root.popup.visible ? TuiStyle.accent : TuiStyle.line

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            cursorShape: Qt.PointingHandCursor
        }
    }

    indicator: MaterialSymbol {
        x: root.width - width - 16
        y: root.height / 2 - height / 2
        text: "keyboard_arrow_down"
        iconSize: Appearance.font.pixelSize.larger
        color: TuiStyle.fg

        rotation: root.popup.visible ? 180 : 0
        Behavior on rotation {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    contentItem: Item {
        implicitWidth: buttonLayout.implicitWidth
        implicitHeight: buttonLayout.implicitHeight

        RowLayout {
            id: buttonLayout
            anchors.fill: parent
            spacing: 8
            anchors.leftMargin: 10
            anchors.rightMargin: 28

            Loader {
                Layout.alignment: Qt.AlignVCenter
                active: root.buttonIcon.length > 0 || (root.currentIndex >= 0 && typeof root.model[root.currentIndex] === 'object' && root.model[root.currentIndex]?.icon)
                visible: active
                sourceComponent: MaterialSymbol {
                    text: {
                        if (root.currentIndex >= 0 && typeof root.model[root.currentIndex] === 'object' && root.model[root.currentIndex]?.icon) {
                            return root.model[root.currentIndex].icon;
                        }
                        return root.buttonIcon;
                    }
                    iconSize: Appearance.font.pixelSize.larger
                    color: TuiStyle.dim
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                color: TuiStyle.fg
                text: root.displayText
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    delegate: ItemDelegate {
        id: itemDelegate
        width: ListView.view ? ListView.view.width : root.width
        implicitHeight: 40

        required property var model
        required property int index
        property color color: {
            if (root.currentIndex === itemDelegate.index) {
                if (itemDelegate.down) return "#222222";
                if (itemDelegate.hovered) return "#333333";
                return "#222222";
            } else {
                if (itemDelegate.down) return "#222222";
                if (itemDelegate.hovered) return "#333333";
                return TuiStyle.bg;
            }
        }
        property color colText: (root.currentIndex === itemDelegate.index) ? TuiStyle.fg : TuiStyle.fg

        background: Rectangle {
            anchors.fill: parent
            radius: 0
            color: itemDelegate.color
            border.width: root.currentIndex === itemDelegate.index ? TuiStyle.borderWidth : 0
            border.color: TuiStyle.accent

            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                cursorShape: Qt.PointingHandCursor
            }
        }

        contentItem: RowLayout {
            spacing: 8
            anchors.leftMargin: 12
            anchors.rightMargin: 12

            Loader {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: Appearance.font.pixelSize.larger
                active: typeof itemDelegate.model === 'object' && itemDelegate.model?.icon?.length > 0
                visible: active

                sourceComponent: Item {
                    implicitWidth: icon.implicitWidth
                    implicitHeight: Appearance.font.pixelSize.larger

                    MaterialSymbol {
                        id: icon
                        anchors.centerIn: parent
                        text: itemDelegate.model?.icon ?? ""
                        iconSize: Appearance.font.pixelSize.larger
                        color: TuiStyle.dim
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.preferredHeight: Appearance.font.pixelSize.larger
                color: itemDelegate.colText
                text: itemDelegate.model[root.textRole]
                font.family: Appearance.font.family.monospace
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
            }
        }
    }

    popup: Popup {
        y: root.height + 4
        width: root.width
        height: Math.min(listView.contentHeight + topPadding + bottomPadding, 300)
        padding: 2

        enter: Transition {
            PropertyAnimation {
                properties: "opacity"
                to: 1
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        exit: Transition {
            PropertyAnimation {
                properties: "opacity"
                to: 0
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
            }
        }

        background: Rectangle {
            anchors.fill: parent
            radius: 0
            color: TuiStyle.bg
            border.width: TuiStyle.borderWidth
            border.color: TuiStyle.accent
        }

        contentItem: StyledListView {
            id: listView
            clip: true
            implicitHeight: contentHeight
            spacing: 0
            model: root.popup.visible ? root.delegateModel : null
            currentIndex: root.highlightedIndex
        }
    }
}
