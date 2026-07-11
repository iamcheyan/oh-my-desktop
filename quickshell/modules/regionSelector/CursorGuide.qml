import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick

Item {
    id: root
    property var action
    property var selectionMode

    property string description: switch (root.action) {
    case RegionSelection.SnipAction.Copy:
    case RegionSelection.SnipAction.Edit:
        return Translation.tr("Copy region (LMB) or annotate (RMB)");
    case RegionSelection.SnipAction.Search:
        return Translation.tr("Search with Google Lens");
    case RegionSelection.SnipAction.CharRecognition:
        return Translation.tr("Recognize text");
    case RegionSelection.SnipAction.Record:
    case RegionSelection.SnipAction.RecordWithSound:
        return Translation.tr("Record region");
    default:
        return "";
    }

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

    property bool showDescription: true
    function hideDescription() {
        root.showDescription = false
    }

    Timer {
        id: descTimeout
        interval: 1500
        running: true
        onTriggered: {
            root.hideDescription()
        }
    }

    onActionChanged: {
        root.showDescription = true
        descTimeout.restart()
    }

    property int margins: 8
    implicitWidth: content.implicitWidth + margins * 2
    implicitHeight: content.implicitHeight + margins * 2

    Rectangle {
        id: content
        anchors.centerIn: parent

        property real padding: 10
        implicitHeight: TuiStyle.rowHeight
        implicitWidth: root.showDescription && root.description !== ""
            ? contentRow.implicitWidth + padding * 2
            : implicitHeight
        clip: true

        radius: TuiStyle.radius
        color: TuiStyle.bg
        border.color: TuiStyle.controlActiveBorder
        border.width: TuiStyle.borderWidth

        Behavior on implicitWidth {
            animation: NumberAnimation { duration: 180; easing.type: Easing.OutQuad }
        }

        Row {
            id: contentRow
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                leftMargin: content.padding
            }
            spacing: 8

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                iconSize: 20
                color: TuiStyle.accent
                text: root.materialSymbol
            }

            Loader {
                id: descriptionLoader
                anchors.verticalCenter: parent.verticalCenter
                visible: root.showDescription && root.description !== ""
                active: true
                sourceComponent: StyledText {
                    color: TuiStyle.fg
                    text: root.description
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }
    }
}
