import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

RowLayout {
    id: root
    spacing: 6
    Layout.fillWidth: true
    Layout.leftMargin: 8
    Layout.rightMargin: 8
    Layout.topMargin: 4
    Layout.bottomMargin: 4

    property list<QtObject> leadingActions
    property list<QtObject> trailingActions
    property bool paginationVisible: false
    property int currentPage: 0
    property int totalPages: 1
    signal pageUp()
    signal pageDown()

    Repeater {
        model: root.leadingActions
        delegate: Loader {
            required property var modelData
            sourceComponent: modelData.type === "icon" ? iconButtonComponent : textButtonComponent
            onLoaded: {
                item.actionData = modelData;
            }
        }
    }

    Item { Layout.fillWidth: true; visible: !root.paginationVisible }

    RippleButton {
        visible: root.paginationVisible
        implicitHeight: 28
        implicitWidth: 28
        buttonRadius: 14
        colBackgroundHover: Appearance.tiling.bgHover
        colRipple: Appearance.tiling.bgActive
        enabled: root.currentPage > 0
        opacity: enabled ? 1 : 0.3
        onClicked: root.pageUp()
        MaterialSymbol {
            anchors.centerIn: parent
            text: "chevron_left"
            font.pixelSize: Appearance.font.pixelSize.larger
            color: Appearance.tiling.text
        }
    }

    StyledText {
        visible: root.paginationVisible
        text: `${root.currentPage + 1} / ${root.totalPages}`
        color: Appearance.tiling.textDim
        font.pixelSize: Appearance.font.pixelSize.small
    }

    RippleButton {
        visible: root.paginationVisible
        implicitHeight: 28
        implicitWidth: 28
        buttonRadius: 14
        colBackgroundHover: Appearance.tiling.bgHover
        colRipple: Appearance.tiling.bgActive
        enabled: root.currentPage < root.totalPages - 1
        opacity: enabled ? 1 : 0.3
        onClicked: root.pageDown()
        MaterialSymbol {
            anchors.centerIn: parent
            text: "chevron_right"
            font.pixelSize: Appearance.font.pixelSize.larger
            color: Appearance.tiling.text
        }
    }

    Item { Layout.fillWidth: true; visible: !root.paginationVisible }

    Repeater {
        model: root.trailingActions
        delegate: Loader {
            required property var modelData
            sourceComponent: modelData.type === "icon" ? iconButtonComponent : textButtonComponent
            onLoaded: {
                item.actionData = modelData;
            }
        }
    }

    Component {
        id: iconButtonComponent
        RippleButton {
            property var actionData
            implicitHeight: 28
            implicitWidth: 28
            buttonRadius: 14
            colBackgroundHover: Appearance.tiling.bgHover
            colRipple: Appearance.tiling.bgActive
            enabled: actionData?.enabled ?? true
            opacity: enabled ? 1 : 0.3
            onClicked: actionData?.callback()
            MaterialSymbol {
                anchors.centerIn: parent
                text: actionData?.icon ?? ""
                font.pixelSize: actionData?.iconSize ?? Appearance.font.pixelSize.small
                color: actionData?.color ?? Appearance.tiling.text
            }
        }
    }

    Component {
        id: textButtonComponent
        DialogButton {
            property var actionData
            buttonText: actionData?.text ?? ""
            enabled: actionData?.enabled ?? true
            opacity: enabled ? 1 : 0.3
            onClicked: actionData?.callback()
        }
    }
}
