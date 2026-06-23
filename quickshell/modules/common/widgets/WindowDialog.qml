import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Rectangle {
    id: root

    property bool show: false
    default property alias contentData: contentColumn.data
    property real backgroundHeight: 400
    property real backgroundWidth: 360
    property real backgroundAnimationMovementDistance: 60
    property int anchorPosition: 0 // 0 = center, 1 = top-right
    property real anchorMargin: 8

    signal dismiss()
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.dismiss();
            event.accepted = true;
        }
    }

    color: "transparent"
    visible: dialogBackground.implicitHeight > 0

    onShowChanged: {
        dialogBackgroundHeightAnimation.easing.bezierCurve = (show ? Appearance.animationCurves.emphasizedDecel : Appearance.animationCurves.emphasizedAccel)
    }

    radius: 0

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onPressed: root.dismiss()
    }

    Rectangle {
        id: dialogBackground
        anchors.horizontalCenter: root.anchorPosition === 0 ? parent.horizontalCenter : undefined
        anchors.right: root.anchorPosition === 1 ? parent.right : undefined
        anchors.rightMargin: root.anchorPosition === 1 ? root.anchorMargin : 0
        radius: Appearance.tiling.dialogRadius
        color: Appearance.tiling.bg
        border.width: Appearance.tiling.borderWidth
        border.color: Appearance.tiling.border
        clip: true

        property real targetY: root.anchorPosition === 1 ? (Config.options.bar.bottom ? (root.height - Appearance.sizes.barHeight - root.backgroundHeight - root.anchorMargin) : (Appearance.sizes.barHeight + root.anchorMargin)) : (root.height / 2 - root.backgroundHeight / 2)
        y: root.show ? targetY : (targetY - root.backgroundAnimationMovementDistance)
        implicitWidth: root.backgroundWidth
        implicitHeight: show ? root.backgroundHeight : 0
        Behavior on implicitHeight {
            NumberAnimation {
                id: dialogBackgroundHeightAnimation
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: dialogBackgroundHeightAnimation.duration
                easing.type: dialogBackgroundHeightAnimation.easing.type
                easing.bezierCurve: dialogBackgroundHeightAnimation.easing.bezierCurve
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            spacing: 6
            opacity: root.show ? 1 : 0
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }
        }
    }
}