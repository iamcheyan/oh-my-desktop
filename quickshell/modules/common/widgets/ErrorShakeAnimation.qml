pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

SequentialAnimation {
    id: root

    required property Item target
    property real distance: 30

    PropertyAction { target: root.target; property: "Layout.leftMargin"; value: 0 }
}
