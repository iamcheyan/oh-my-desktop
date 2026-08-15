pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.settings.widgets

Rectangle {
    id: root

    required property var displayState
    property var output: null
    property var settingsRoot: null
    property bool advancedOpen: false

    readonly property var draft: (displayState.revision, output ? displayState.draftFor(output.name) : ({}))
    readonly property var parsedMode: displayState.parseMode(draft.mode)
        || (output ? displayState.parseMode(output.currentMode) : null)
    readonly property string resolutionValue: parsedMode
        ? `${parsedMode.w}x${parsedMode.h}`
        : (output && output.width && output.height ? `${output.width}x${output.height}` : "")
    readonly property var resolutionOptions: (displayState.revision, buildResolutionOptions())
    readonly property var refreshOptions: (displayState.revision, buildRefreshOptions())
    readonly property var scaleOptions: (displayState.revision, buildScaleOptions())
    readonly property var scaleDropdownOptions: (displayState.revision, buildScaleDropdownOptions())

    implicitHeight: 320
    radius: SettingsTokens.roundRadius
    color: SettingsTokens.panel
    border.width: 1
    border.color: displayState.hasPendingChanges ? SettingsTokens.accent : SettingsTokens.line

    function buildResolutionOptions() {
        if (!output)
            return [];
        const seen = {};
        const options = [];
        const modes = [];
        if (draft.mode)
            modes.push(draft.mode);
        if (output.currentMode)
            modes.push(output.currentMode);
        for (const mode of output.modes || [])
            modes.push(mode);
        for (const mode of modes) {
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
        const seen = {};
        const options = [];
        const modes = [];
        if (draft.mode)
            modes.push(draft.mode);
        if (output.currentMode)
            modes.push(output.currentMode);
        for (const mode of output.modes || [])
            modes.push(mode);
        for (const mode of modes) {
            const parsed = displayState.parseMode(mode);
            const normalized = displayState.normalizeMode(mode, output);
            if (parsed && parsed.w === parsedMode.w && parsed.h === parsedMode.h && !seen[normalized]) {
                seen[normalized] = true;
                options.push({ value: normalized, label: `${Math.round(parsed.hz)} Hz` });
            }
        }
        return options;
    }

    function buildScaleOptions() {
        const options = [];
        for (let percentage = 100; percentage <= 400; percentage += 25)
            options.push(percentage / 100);
        return options;
    }

    function cleanScale(scale, mode) {
        const selectedMode = mode || parsedMode;
        if (!selectedMode)
            return true;
        const logicalWidth = selectedMode.w / scale;
        const logicalHeight = selectedMode.h / scale;
        return Math.abs(logicalWidth - Math.round(logicalWidth)) < 0.0001
            && Math.abs(logicalHeight - Math.round(logicalHeight)) < 0.0001;
    }

    // Mirrors Hyprland CMonitor::applyMonitorRule: scale values are searched
    // on a 1/120 grid, checking upward before downward at each distance.
    function effectiveScaleForPreset(preset, mode) {
        const selectedMode = mode || parsedMode;
        if (!selectedMode)
            return Number(preset);
        const requestedTick = Math.round(Number(preset) * 120);
        const requestedScale = requestedTick / 120;
        if (cleanScale(requestedScale, selectedMode))
            return requestedScale;
        for (let offset = 1; offset < 90; offset++) {
            const scaleUp = (requestedTick + offset) / 120;
            if (cleanScale(scaleUp, selectedMode))
                return scaleUp;
            const scaleDown = (requestedTick - offset) / 120;
            if (scaleDown > 0 && cleanScale(scaleDown, selectedMode))
                return scaleDown;
        }
        return NaN;
    }

    function actualScaleLabel(scale) {
        const percentage = Number(scale) * 100;
        const rounded = Math.round(percentage);
        return Math.abs(percentage - rounded) < 0.005
            ? `${rounded}%`
            : `${percentage.toFixed(2)}%`;
    }

    function buildScaleDropdownOptions() {
        if (!output)
            return [];
        return scaleOptions.map(preset => {
            const effective = effectiveScaleForPreset(preset);
            const supported = Number.isFinite(effective);
            const presetLabel = displayState.scaleLabel(preset);
            return {
                value: String(Number(preset).toFixed(2)),
                label: supported
                    ? `${presetLabel} · actual ${actualScaleLabel(effective)}`
                    : `${presetLabel} · unavailable`,
                enabled: supported
            };
        });
    }

    function buildPositionOptions(currentVal) {
        const val = Number(currentVal || 0);
        const base = [-3840, -2560, -1920, -1440, -1080, 0, 1080, 1440, 1920, 2560, 3840];
        if (!base.includes(val))
            base.push(val);
        return base.sort((a, b) => a - b).map(x => ({ value: String(x), label: String(x) }));
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
        const normalizedMode = displayState.normalizeMode(candidates[0], output);
        const nextMode = displayState.parseMode(normalizedMode);
        const preset = Number(root.draft.scalePreset || root.draft.scale || 1);
        const effectiveScale = effectiveScaleForPreset(preset, nextMode);
        displayState.setDraftValue(output.name, "mode", normalizedMode);
        if (Number.isFinite(effectiveScale))
            displayState.setScalePreset(output.name, preset, effectiveScale);
    }

    ColumnLayout {
        id: detailColumn
        anchors.fill: parent
        anchors.margins: SettingsTokens.panelPadding
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

        StyledFlickable {
            id: settingsFlickable
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: width
            contentHeight: settingsColumn.implicitHeight

            ColumnLayout {
                id: settingsColumn
                width: settingsFlickable.width
                spacing: 10

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

                    SettingsDropdownRow {
                        label: "Scale"
                        description: "Choose how large text, windows, and controls appear"
                        currentValue: String(Number(root.draft.scalePreset || root.draft.scale || 1).toFixed(2))
                        options: root.scaleDropdownOptions
                        dropdownWidth: 250
                        controlled: true
                        onValueChanged: value => {
                            if (!root.output)
                                return;
                            const preset = Number(value);
                            const effectiveScale = root.effectiveScaleForPreset(preset);
                            if (Number.isFinite(effectiveScale))
                                root.displayState.setScalePreset(root.output.name, preset, effectiveScale);
                        }
                    }
                }

                SettingsSection {
                    title: "Advanced"

                    SettingsDropdownRow {
                        label: "Horizontal position"
                        description: "Horizontal coordinate of the display in the layout space"
                        currentValue: String(root.draft.x || 0)
                        options: root.buildPositionOptions(root.draft.x)
                        dropdownWidth: 190
                        controlled: true
                        onValueChanged: value => {
                            if (root.output)
                                root.displayState.setDraftValue(root.output.name, "x", Number(value));
                        }
                    }

                    SettingsDropdownRow {
                        label: "Vertical position"
                        description: "Vertical coordinate of the display in the layout space"
                        currentValue: String(root.draft.y || 0)
                        options: root.buildPositionOptions(root.draft.y)
                        dropdownWidth: 190
                        controlled: true
                        onValueChanged: value => {
                            if (root.output)
                                root.displayState.setDraftValue(root.output.name, "y", Number(value));
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
    }
}
