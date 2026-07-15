import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    property string label: ""
    property string description: ""
    property string currentValue: ""
    property var options: []
    property int dropdownWidth: 180
    property int maximumVisibleOptions: 7
    property bool controlled: false
    signal valueChanged(string value)

    readonly property int optionHeight: 34
    readonly property int popupPadding: 4

    function optionLabel(value) {
        const requested = String(value ?? "");
        for (const opt of root.options || []) {
            if (String(opt.value ?? "") === requested)
                return String(opt.label ?? opt.value ?? "");
        }
        return requested;
    }

    function currentOptionIndex() {
        const requested = String(root.currentValue ?? "");
        for (let index = 0; index < (root.options || []).length; index++) {
            if (String(root.options[index].value ?? "") === requested)
                return index;
        }
        return -1;
    }

    onOptionsChanged: {
        if (!root.options || root.options.length === 0)
            ddPopup.close();
    }

    Layout.fillWidth: true
    implicitHeight: 56
    radius: SettingsTokens.radius
    color: ddRowMouse.containsMouse ? SettingsTokens.cardHover : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 14

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            StyledText {
                Layout.fillWidth: true
                text: root.label
                color: SettingsTokens.fg
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
            }

            StyledText {
                visible: root.description.length > 0
                Layout.fillWidth: true
                text: root.description
                color: SettingsTokens.dim
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
            }
        }

        Rectangle {
            id: ddButton
            Layout.preferredWidth: root.dropdownWidth
            Layout.preferredHeight: 36
            radius: SettingsTokens.radius
            color: ddBtnMouse.containsMouse ? SettingsTokens.buttonHover : SettingsTokens.button
            border.width: 1
            border.color: ddPopup.opened ? SettingsTokens.accent : SettingsTokens.buttonBorder

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                spacing: 6

                StyledText {
                    Layout.fillWidth: true
                    text: root.optionLabel(root.currentValue)
                    color: SettingsTokens.fg
                    font.pixelSize: Appearance.font.pixelSize.small
                    elide: Text.ElideRight
                }

                MaterialSymbol {
                    text: ddPopup.opened ? "expand_less" : "expand_more"
                    iconSize: 18
                    color: SettingsTokens.muted
                }
            }

            MouseArea {
                id: ddBtnMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (!root.options || root.options.length === 0)
                        return;
                    if (ddPopup.opened)
                        ddPopup.close();
                    else
                        ddPopup.open();
                }
            }

            Popup {
                id: ddPopup
                y: ddButton.height + 4
                width: root.dropdownWidth
                height: Math.min(
                    root.maximumVisibleOptions,
                    root.options ? root.options.length : 0
                ) * root.optionHeight + root.popupPadding * 2
                padding: 0
                closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent

                onOpened: {
                    const selectedIndex = root.currentOptionIndex();
                    if (selectedIndex >= 0)
                        ddOptList.positionViewAtIndex(selectedIndex, ListView.Contain);
                }

                background: Rectangle {
                    radius: SettingsTokens.radius
                    color: SettingsTokens.panel
                    border.width: 1
                    border.color: SettingsTokens.line
                }

                ListView {
                    id: ddOptList
                    anchors.fill: parent
                    anchors.margins: 4
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentHeight > height
                    reuseItems: true
                    model: root.options
                    ScrollBar.vertical: StyledScrollBar {
                        id: ddScrollBar
                        policy: ddOptList.contentHeight > ddOptList.height
                            ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    }

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: ddOptList.width - (ddScrollBar.policy === ScrollBar.AlwaysOn ? 8 : 0)
                        height: root.optionHeight
                        radius: SettingsTokens.radius
                        color: ddOptMouse.containsMouse ? SettingsTokens.cardHover
                            : (String(modelData.value ?? "") === String(root.currentValue ?? "")
                                ? SettingsTokens.accentSoft : "transparent")

                        StyledText {
                            anchors.fill: parent
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            verticalAlignment: Text.AlignVCenter
                            text: modelData.label
                            color: SettingsTokens.fg
                            font.pixelSize: Appearance.font.pixelSize.small
                            elide: Text.ElideRight
                        }

                        MouseArea {
                            id: ddOptMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (!root.controlled)
                                    root.currentValue = modelData.value
                                root.valueChanged(modelData.value)
                                ddPopup.close()
                            }
                        }
                    }
                }
            }
        }
    }

    MouseArea {
        id: ddRowMouse
        anchors.fill: parent
        hoverEnabled: true
        propagateComposedEvents: true
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.ArrowCursor
    }
}
