import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Item {
    id: root
    property var action
    property var selectionMode

    property string materialSymbol: switch (root.action) {
    case RegionSelection.SnipAction.Copy:
    case RegionSelection.SnipAction.Edit:
        return "add";
    case RegionSelection.SnipAction.Search:
        return "image_search";
    case RegionSelection.SnipAction.CharRecognition:
        return "document_scanner";
    case RegionSelection.SnipAction.Record:
    case RegionSelection.SnipAction.RecordWithSound:
        return "videocam";
    default:
        return "";
    }

    implicitWidth: 28
    implicitHeight: 28

    MaterialSymbol {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        iconSize: 28
        color: Appearance.colors.colPrimary
        text: root.materialSymbol
    }
}
