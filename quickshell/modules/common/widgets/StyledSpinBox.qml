import qs.modules.common
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls

SpinBox {
    id: root

    property real baseHeight: 35
    property real radius: 0
    property real innerButtonRadius: 0
    editable: true

    opacity: root.enabled ? 1 : 0.4

    background: Rectangle {
        color: "#181818"
        radius: root.radius
        border.width: TuiStyle.borderWidth
        border.color: root.activeFocus ? TuiStyle.accent : TuiStyle.line
    }

    contentItem: Item {
        implicitHeight: root.baseHeight
        implicitWidth: Math.max(labelText.implicitWidth, 40)

        StyledTextInput {
            id: labelText
            anchors.centerIn: parent
            text: root.value // displayText would make the numbers weird like 1,000 instead of 1000
            color: TuiStyle.fg
            font.family: Appearance.font.family.numbers
            font.variableAxes: Appearance.font.variableAxes.numbers
            font.pixelSize: Appearance.font.pixelSize.small
            validator: root.validator
            onTextChanged: {
                root.value = parseFloat(text);
            }
        }
    }

    down.indicator: Rectangle {
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
        }
        implicitHeight: root.baseHeight
        implicitWidth: root.baseHeight
        topLeftRadius: root.radius
        bottomLeftRadius: root.radius
        topRightRadius: root.innerButtonRadius
        bottomRightRadius: root.innerButtonRadius

        color: root.down.pressed ? "#222222" :
            root.down.hovered ? "#333333" :
            "transparent"
        border.width: TuiStyle.borderWidth
        border.color: TuiStyle.line

        MaterialSymbol {
            anchors.centerIn: parent
            text: "remove"
            iconSize: 20
            color: TuiStyle.fg
        }
    }

    up.indicator: Rectangle {
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
        }
        implicitHeight: root.baseHeight
        implicitWidth: root.baseHeight
        topRightRadius: root.radius
        bottomRightRadius: root.radius
        topLeftRadius: root.innerButtonRadius
        bottomLeftRadius: root.innerButtonRadius

        color: root.up.pressed ? "#222222" :
            root.up.hovered ? "#333333" :
            "transparent"
        border.width: TuiStyle.borderWidth
        border.color: TuiStyle.line

        MaterialSymbol {
            anchors.centerIn: parent
            text: "add"
            iconSize: 20
            color: TuiStyle.fg
        }
    }
}
