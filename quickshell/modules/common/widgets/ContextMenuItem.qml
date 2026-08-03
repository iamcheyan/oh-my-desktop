pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root

    property string nerdIcon: ""
    property string labelText: ""
    // Optional explicit mnemonic. ContextMenuWindow keeps its generated
    // assignment separate so a visibility change can be rebalanced later.
    property string shortcutKey: ""
    property string assignedShortcutKey: ""
    readonly property string effectiveShortcutKey: assignedShortcutKey || shortcutKey
    readonly property string mnemonicMarkup: {
        const key = root.effectiveShortcutKey.toUpperCase();
        if (key === "")
            return root.labelText;
        const upper = root.labelText.toUpperCase();
        const index = upper.indexOf(key);
        const escapeMarkup = text => String(text)
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;");
        if (index < 0)
            return escapeMarkup(root.labelText);
        return escapeMarkup(root.labelText.slice(0, index))
            + "<u>" + escapeMarkup(root.labelText.slice(index, index + 1)) + "</u>"
            + escapeMarkup(root.labelText.slice(index + 1));
    }

    function registerWithMenu() {
        let current = root.parent;
        while (current) {
            if (typeof current.registerMenuItem === "function") {
                current.registerMenuItem(root);
                return;
            }
            current = current.parent;
        }
    }

    Component.onCompleted: {
        // Register independently of visual-layout ancestry. This is needed
        // by extension menus whose items are inserted through a Layout.data
        // default property and may not appear in children during the first
        // event-loop turn.
        Qt.callLater(root.registerWithMenu);
    }
    property color iconColor: TuiStyle.fg
    property color textColor: TuiStyle.fg

    property int itemHeight: 32
    property int iconSize: 18
    property int iconColumnWidth: 20
    property real hPadding: 8

    buttonRadius: 6
    horizontalPadding: root.hPadding
    topPadding: 0
    bottomPadding: 0
    implicitHeight: root.itemHeight
    height: root.itemHeight
    Layout.fillWidth: true

    colBackground: "transparent"
    colBackgroundHover: TuiStyle.surfaceHover
    colRipple: TuiStyle.surfacePressed
    borderWidth: 0

    contentItem: RowLayout {
        spacing: 8
        Item {
            Layout.preferredWidth: root.iconColumnWidth
            Layout.preferredHeight: root.iconColumnWidth
            Layout.alignment: Qt.AlignVCenter
            NerdIcon {
                anchors.centerIn: parent
                iconSize: root.iconSize
                text: root.nerdIcon
                color: root.iconColor
                visible: root.nerdIcon !== ""
            }
        }
        StyledText {
            Layout.fillWidth: true
            text: root.mnemonicMarkup
            textFormat: Text.RichText
            color: root.textColor
            elide: Text.ElideRight
            font {
                pixelSize: 13
                weight: Font.Normal
            }
        }
    }
}
