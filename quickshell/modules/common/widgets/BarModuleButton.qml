import qs
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property string icon: ""
    property string moduleId: ""
    property bool active: false
    property var altAction: null
    signal clicked()

    readonly property string effectiveIcon: {
        if (moduleId === "file-backup")
            return NerdIconMap.cloudUpload
        if (moduleId === "ocr")
            return NerdIconMap.textDocument
        if (moduleId === "windows-vm")
            return NerdIconMap.windows
        return icon
    }

    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    Layout.fillHeight: true
    implicitWidth: Config.options.bar.rightIconSlotWidth
    implicitHeight: Config.options.bar.rightIconSlotWidth

    property color iconColor: Appearance.colors.colBarText

    RippleButton {
        id: button
        anchors.centerIn: parent
        width: Config.options.bar.rightIconSlotWidth
        height: Config.options.bar.rightIconSlotWidth
        buttonRadius: Config.options.bar.rightIconSlotWidth / 2

        colBackground: "transparent"
        colBackgroundHover: Qt.rgba(1, 1, 1, 0.10)
        colBackgroundToggled: Qt.rgba(1, 1, 1, 0.18)
        colBackgroundToggledHover: Qt.rgba(1, 1, 1, 0.26)
        colRipple: Qt.rgba(1, 1, 1, 0.12)
        colRippleToggled: Qt.rgba(1, 1, 1, 0.18)
        toggled: root.active

        onClicked: {
            root.clicked();
        }

        altAction: function(event) {
            hideMenuLoader.open();
        }
    }

    Loader {
        id: hideMenuLoader
        function open() {
            if (hideMenuLoader.item)
                hideMenuLoader.item.open();
            else
                hideMenuLoader.active = true;
        }
        active: false
        sourceComponent: ModuleHideMenu {
            moduleId: root.moduleId
            anchor {
                window: button.QsWindow.window
                item: button
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            Component.onCompleted: hideMenuLoader.open()
            onMenuClosed: hideMenuLoader.active = false
        }
    }

    BarNerdIcon {
        anchors.centerIn: button
        text: root.effectiveIcon
        color: root.iconColor
    }
}
