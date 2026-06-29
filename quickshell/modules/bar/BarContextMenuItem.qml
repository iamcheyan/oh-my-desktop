pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * BarContextMenuItem — a single row inside a BarContextMenu.
 *
 * Usage:
 *   BarContextMenuItem {
 *       iconName:  "devices/bluetooth-symbolic"
 *       iconColor: TuiStyle.fg          // optional, defaults to TuiStyle.fg
 *       label:     "Open Bluetooth"
 *       onClicked: { ... }
 *   }
 *
 * Style is driven by BarContextMenu's readonly properties via the `menu` alias.
 * Never hard-code itemHeight / iconSize here — read them from `menu`.
 */
RippleButton {
    id: root

    // ── Content properties ──────────────────────────────────────────────────
    property string iconName:   ""
    property color  iconColor:  TuiStyle.fg
    property color  labelColor: iconColor   // defaults to iconColor; override for independent text colour
    property string label:      ""

    // ── Pointer to parent menu for style tokens ─────────────────────────────
    // Traverse up the parent chain to find the BarContextMenu
    readonly property var menu: {
        var p = parent;
        while (p) {
            if (p.itemHeight !== undefined && p.iconColumnWidth !== undefined) return p;
            p = p.parent;
        }
        return null;
    }
    readonly property int _itemHeight:      menu ? menu.itemHeight      : 48
    readonly property int _itemRadius:      menu ? menu.itemRadius      : 5
    readonly property int _iconColumnWidth: menu ? menu.iconColumnWidth : 26
    readonly property int _iconSize:        menu ? menu.iconSize        : 18
    readonly property real _hPadding:       menu ? menu.hPadding        : 8
    // ────────────────────────────────────────────────────────────────────────

    buttonRadius:      _itemRadius
    horizontalPadding: _hPadding

    Layout.fillWidth:      true
    Layout.minimumHeight:  _itemHeight
    Layout.preferredHeight: _itemHeight
    Layout.maximumHeight:  _itemHeight

    colBackground:      "transparent"
    colBackgroundHover: TuiStyle.surfaceHover
    colRipple:          TuiStyle.surfacePressed
    borderWidth:        0

    contentItem: RowLayout {
        anchors.fill:        parent
        anchors.leftMargin:  root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        spacing: 8

        Item {
            Layout.preferredWidth:  root._iconColumnWidth
            Layout.preferredHeight: root._iconColumnWidth
            Layout.alignment:       Qt.AlignVCenter

            CosmicIcon {
                anchors.centerIn: parent
                iconSize: root._iconSize
                name:     root.iconName
                color:    root.iconColor
                visible:  root.iconName !== ""
            }
        }

        StyledText {
            Layout.fillWidth:  true
            Layout.alignment:  Qt.AlignVCenter
            text:              root.label
            font.family:       Appearance.font.family.main
            font.pixelSize:    Appearance.font.pixelSize.small
            font.weight:       Font.Normal
            color:             root.labelColor  // text colour (follows iconColor by default)
        }
    }
}
