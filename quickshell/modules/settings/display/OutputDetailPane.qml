import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets

Rectangle {
    id: root

    required property var displayState
    property var output: null
    property var settingsRoot: null
    property bool advancedOpen: false

    readonly property var draft: (displayState.revision, output ? displayState.draftFor(output.name) : ({}))
    readonly property var parsedMode: displayState.parseMode(draft.mode)
    readonly property string resolutionValue: parsedMode ? `${parsedMode.w}x${parsedMode.h}` : ""
    readonly property var resolutionOptions: (displayState.revision, buildResolutionOptions())
    readonly property var refreshOptions: (displayState.revision, buildRefreshOptions())
    readonly property var scaleOptions: (displayState.revision, buildScaleOptions())

    implicitHeight: detailColumn.implicitHeight + 32
    radius: SettingsTokens.roundRadius
    color: SettingsTokens.panel
    border.width: 1
    border.color: displayState.hasPendingChanges ? SettingsTokens.accent : SettingsTokens.line

    function buildResolutionOptions() {
        if (!output)
            return [];
        const seen = {};
        const options = [];
        for (const mode of output.modes || []) {
            const parsed = displayState.parseMode(mode);
            if (!parsed)
                continue;
            const key = `${parsed.w}x${parsed.h}`;
            if (seen[key])
                continue;
            seen[key] = true;
            options.push({ value: key, label: `${parsed.w} x ${parsed.h}` });
        }
        return options;
    }

    function buildRefreshOptions() {
        if (!output || !parsedMode)
            return [];
        const options = [];
        for (const mode of output.modes || []) {
            const parsed = displayState.parseMode(mode);
            if (parsed && parsed.w === parsedMode.w && parsed.h === parsedMode.h)
                options.push({ value: mode, label: `${Math.round(parsed.hz)} Hz` });
        }
        return options;
    }

    function buildScaleOptions() {
        const options = [1, 1.25, 1.5, 1.75, 2];
        const current = Number(Number(draft.scale || 1).toFixed(2));
        if (!options.includes(current))
            options.push(current);
        return options.sort((left, right) => left - right);
    }

    function chooseResolution(value) {
        if (!output)
            return;
        const dimensions = String(value).split("x");
        const width = Number(dimensions[0]);
        const height = Number(dimensions[1]);
        const candidates = (output.modes || []).filter(mode => {
            const parsed = displayState.parseMode(mode);
            return parsed && parsed.w === width && parsed.h === height;
        });
        if (candidates.length === 0)
            return;
        const currentHz = parsedMode ? parsedMode.hz : 60;
        candidates.sort((left, right) => {
            const a = displayState.parseMode(left);
            const b = displayState.parseMode(right);
            return Math.abs(a.hz - currentHz) - Math.abs(b.hz - currentHz);
        });
        displayState.setDraftValue(output.name, "mode", candidates[0]);
    }

    ColumnLayout {
        id: detailColumn
        anchors.fill: parent
        anchors.margins: 16
        spacing: 10

        Item {
            Layout.fillWidth: true
            implicitHeight: 68

            RowLayout {
                anchors.fill: parent
                spacing: 14

                Rectangle {
                    Layout.preferredWidth: 48
                    Layout.preferredHeight: 48
                    radius: SettingsTokens.radius
                    color: SettingsTokens.accentSoft

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "desktop_windows"
                        iconSize: 25
                        color: SettingsTokens.accent
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3

                    StyledText {
                        Layout.fillWidth: true
                        text: root.output ? root.displayState.displayName(root.output) : "No display selected"
                        color: SettingsTokens.fg
                        font.pixelSize: Appearance.font.pixelSize.large
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: root.output ? `${root.output.name}  ·  ${root.displayState.formatModeLabel(root.draft.mode)}` : "Select a connected display"
                        color: SettingsTokens.muted
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                    }
                }

                Rectangle {
                    visible: root.output && root.output.focused
                    implicitWidth: focusedText.implicitWidth + 20
                    implicitHeight: 28
                    radius: SettingsTokens.radius
                    color: SettingsTokens.accentSoft

                    StyledText {
                        id: focusedText
                        anchors.centerIn: parent
                        text: "Focused"
                        color: SettingsTokens.accent
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.DemiBold
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: SettingsTokens.line
        }

        SettingsSection {
            title: "Display mode"

            SettingsDropdownRow {
                label: "Resolution"
                description: "Number of pixels shown by this display"
                currentValue: root.resolutionValue
                options: root.resolutionOptions
                dropdownWidth: 190
                controlled: true
                onValueChanged: value => root.chooseResolution(value)
            }

            SettingsDropdownRow {
                label: "Refresh rate"
                description: "Higher rates make motion appear smoother"
                currentValue: root.draft.mode || ""
                options: root.refreshOptions
                dropdownWidth: 190
                controlled: true
                onValueChanged: value => {
                    if (root.output)
                        root.displayState.setDraftValue(root.output.name, "mode", value);
                }
            }

            SettingsDropdownRow {
                label: "Orientation"
                description: "Rotate or flip the displayed image"
                currentValue: String(root.draft.transform ?? 0)
                options: [
                    { value: "0", label: "Normal" },
                    { value: "1", label: "90°" },
                    { value: "2", label: "180°" },
                    { value: "3", label: "270°" },
                    { value: "4", label: "Flipped" },
                    { value: "5", label: "Flipped 90°" },
                    { value: "6", label: "Flipped 180°" },
                    { value: "7", label: "Flipped 270°" }
                ]
                dropdownWidth: 190
                controlled: true
                onValueChanged: value => {
                    if (root.output)
                        root.displayState.setDraftValue(root.output.name, "transform", Number(value));
                }
            }

            StyledText {
                visible: root.displayState.modeIsLowRefresh(root.draft.mode)
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                text: "This refresh rate can make motion and pointer movement feel choppy."
                color: SettingsTokens.danger
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.WordWrap
            }
        }

        SettingsSection {
            title: "Scale"

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                text: "Choose how large text, windows, and controls appear"
                color: SettingsTokens.muted
                font.pixelSize: Appearance.font.pixelSize.small
            }

            GridLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                columns: width >= 520 ? 5 : 3
                columnSpacing: 6
                rowSpacing: 6

                Repeater {
                    model: root.output ? root.scaleOptions : []

                    Rectangle {
                        required property var modelData
                        readonly property bool active: Math.abs(Number(modelData) - Number(root.draft.scale || 1)) < 0.001
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        radius: SettingsTokens.radius
                        color: active ? SettingsTokens.accentSoft : (scaleMouse.containsMouse ? SettingsTokens.buttonHover : SettingsTokens.button)
                        border.width: 1
                        border.color: active ? SettingsTokens.accent : SettingsTokens.buttonBorder

                        StyledText {
                            anchors.centerIn: parent
                            text: root.displayState.scaleLabel(modelData)
                            color: parent.active ? SettingsTokens.accent : SettingsTokens.fg
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: parent.active ? Font.DemiBold : Font.Normal
                        }

                        MouseArea {
                            id: scaleMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.displayState.setDraftValue(root.output.name, "scale", Number(parent.modelData))
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: advancedColumn.implicitHeight + 24
            radius: SettingsTokens.radius
            color: SettingsTokens.bg
            border.width: 1
            border.color: SettingsTokens.line

            ColumnLayout {
                id: advancedColumn
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    color: "transparent"

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10

                        MaterialSymbol {
                            text: "tune"
                            iconSize: 18
                            color: SettingsTokens.muted
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: "Advanced"
                            color: SettingsTokens.fg
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            visible: !root.advancedOpen && root.output
                            text: `Position ${root.draft.x}, ${root.draft.y}`
                            color: SettingsTokens.dim
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }

                        MaterialSymbol {
                            text: root.advancedOpen ? "expand_less" : "expand_more"
                            iconSize: 18
                            color: SettingsTokens.muted
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.advancedOpen = !root.advancedOpen
                    }
                }

                ColumnLayout {
                    visible: root.advancedOpen
                    Layout.fillWidth: true
                    spacing: 0

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: SettingsTokens.line; Layout.bottomMargin: 8 }

                    // Horizontal position row
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 56
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                StyledText {
                                    text: "Horizontal position"
                                    color: SettingsTokens.fg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                }

                                StyledText {
                                    text: "Horizontal offset of this display in pixels"
                                    color: SettingsTokens.dim
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 190
                                Layout.preferredHeight: 36
                                radius: SettingsTokens.radius
                                color: SettingsTokens.button
                                border.width: 1
                                border.color: SettingsTokens.buttonBorder

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    PositionButton {
                                        symbol: "remove"
                                        onClicked: {
                                            const next = Number(root.draft.x || 0) - 10;
                                            root.displayState.setDraftValue(root.output.name, "x", next);
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: String(root.draft.x || 0)
                                        color: SettingsTokens.fg
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    PositionButton {
                                        symbol: "add"
                                        onClicked: {
                                            const next = Number(root.draft.x || 0) + 10;
                                            root.displayState.setDraftValue(root.output.name, "x", next);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Vertical position row
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 56
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                StyledText {
                                    text: "Vertical position"
                                    color: SettingsTokens.fg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                }

                                StyledText {
                                    text: "Vertical offset of this display in pixels"
                                    color: SettingsTokens.dim
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideRight
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 190
                                Layout.preferredHeight: 36
                                radius: SettingsTokens.radius
                                color: SettingsTokens.button
                                border.width: 1
                                border.color: SettingsTokens.buttonBorder

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 0

                                    PositionButton {
                                        symbol: "remove"
                                        onClicked: {
                                            const next = Number(root.draft.y || 0) - 10;
                                            root.displayState.setDraftValue(root.output.name, "y", next);
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: String(root.draft.y || 0)
                                        color: SettingsTokens.fg
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.Medium
                                        horizontalAlignment: Text.AlignHCenter
                                    }

                                    PositionButton {
                                        symbol: "add"
                                        onClicked: {
                                            const next = Number(root.draft.y || 0) + 10;
                                            root.displayState.setDraftValue(root.output.name, "y", next);
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Hardware details row
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 56
                        color: "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 14

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 3

                                StyledText {
                                    text: "Hardware details"
                                    color: SettingsTokens.fg
                                    font.pixelSize: Appearance.font.pixelSize.small
                                }

                                StyledText {
                                    text: root.output ? `${root.output.make || "Unknown vendor"} ${root.output.model || ""}`.trim() : ""
                                    color: SettingsTokens.dim
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    elide: Text.ElideRight
                                }
                            }

                            SettingsButton {
                                Layout.preferredWidth: 120
                                Layout.preferredHeight: 32
                                label: "wlr-randr"
                                iconName: "open_in_new"
                                onClicked: Quickshell.execDetached(["foot", "--app-id=wlr-randr", "--title=wlr-randr", "--window-size-pixels=880x620", "-e", "wlr-randr"])
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillHeight: true
        }
    }

    component PositionButton: Rectangle {
        id: positionButton
        property string symbol: ""
        signal clicked()
        Layout.preferredWidth: 38
        Layout.fillHeight: true
        color: positionMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"

        MaterialSymbol {
            anchors.centerIn: parent
            text: positionButton.symbol
            iconSize: 17
            color: SettingsTokens.fg
        }

        MouseArea {
            id: positionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: positionButton.clicked()
        }
    }
}
