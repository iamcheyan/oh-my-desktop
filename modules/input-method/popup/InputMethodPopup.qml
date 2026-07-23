import qs
import qs.modules.bar
import qs.services as QsServices
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.popupComponents

PopupColumn {
    readonly property var im: QsServices.InputMethod

    id: inputMethodPanel


    property var choices: [
        { schema: "sbzr", badge: "中", title: "Chinese", subtitle: "Natural input" },
        { schema: "sbzr_mix", badge: "混", title: "Chinese", subtitle: "Mixed input" },
        { schema: "easy_en", badge: "A", title: "English", subtitle: "Easy English" },
        { schema: "jaroomaji", badge: "あ", title: "Japanese", subtitle: "Romaji" }
    ]

    Component.onCompleted: im.refresh()

    PopupHeader {
        Layout.fillWidth: true
        icon: NerdIconMap.keyboard
        title: "Input Language"
        subtitle: im.available ? im.summary : "Fcitx5 is unavailable"
        tone: im.available ? TuiStyle.accent : TuiStyle.danger
        showDivider: true
    }

    Repeater {
        model: inputMethodPanel.choices

        delegate: Rectangle {
            id: languageRow
            required property var modelData
            readonly property bool selected: im.schema === modelData.schema

            Layout.fillWidth: true
            Layout.preferredHeight: 58
            color: selected ? TuiStyle.panelAlt
                : languageMouse.containsMouse ? TuiStyle.surfaceHover
                : "transparent"
            radius: TuiStyle.miniRadius

            MouseArea {
                id: languageMouse
                anchors.fill: parent
                enabled: !im.busy
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const returnAddress = HyprlandData.activeWindow?.address || "";
                    root.close();
                    im.selectSchema(languageRow.modelData.schema, returnAddress);
                }
            }

            Rectangle {
                id: languageBadge
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                width: 30
                height: 30
                radius: TuiStyle.miniRadius
                color: languageRow.selected ? TuiStyle.accent : TuiStyle.surfaceSubtle

                StyledText {
                    anchors.centerIn: parent
                    text: languageRow.modelData.badge
                    color: languageRow.selected ? TuiStyle.bg : TuiStyle.fg
                    font.family: Appearance.font.family.main
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
            }

            Column {
                anchors.left: languageBadge.right
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                StyledText {
                    text: languageRow.modelData.title
                    color: TuiStyle.fg
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: languageRow.selected ? Font.DemiBold : Font.Normal
                }

                StyledText {
                    text: languageRow.modelData.subtitle
                    color: TuiStyle.dim
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }

            NerdIcon {
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                iconSize: 15
                text: im.busy && languageRow.selected
                    ? NerdIconMap.refresh
                    : NerdIconMap.check
                color: TuiStyle.accent
                visible: languageRow.selected
            }
        }
    }

    StyledText {
        Layout.fillWidth: true
        Layout.leftMargin: 16
        Layout.rightMargin: 16
        Layout.topMargin: 8
        Layout.bottomMargin: 8
        visible: im.lastError.length > 0
        text: "Unable to switch input language"
        color: TuiStyle.danger
        font.family: Appearance.font.family.main
        font.pixelSize: Appearance.font.pixelSize.small
        wrapMode: Text.Wrap
    }

    PopupFooterLink {
        Layout.fillWidth: true
        label: "Fcitx configuration…"
        onClicked: {
            root.close();
            im.openConfiguration();
        }
    }
}
