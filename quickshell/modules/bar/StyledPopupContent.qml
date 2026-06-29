import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property int preferredWidth: 0
    property int maximumWidth: 360
    property int contentSpacing: 2
    default property alias content: contentLayout.data
    readonly property int resolvedWidth: preferredWidth > 0
        ? Math.min(preferredWidth, maximumWidth)
        : Math.min(contentLayout.implicitWidth, maximumWidth)

    implicitWidth: resolvedWidth
    implicitHeight: contentLayout.implicitHeight
    width: implicitWidth
    anchors.centerIn: parent
    clip: true

    ColumnLayout {
        id: contentLayout
        width: parent.width
        spacing: root.contentSpacing
    }
}
