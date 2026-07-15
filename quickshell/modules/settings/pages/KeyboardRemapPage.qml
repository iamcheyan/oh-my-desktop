import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.settings
import qs.modules.settings.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: pageRoot

    required property var settingsRoot
    readonly property bool wideLayout: width >= 980

    // Footer contract (Discard / Apply)
    readonly property bool hasPendingChanges: KeyboardRemap.hasPendingChanges
    readonly property bool applying: KeyboardRemap.applyInProgress
    function resetDrafts() {
        KeyboardRemap.loadProfiles()
        KeyboardRemap.checkPendingChanges()
        pageRoot.settingsRoot.keyremapApplyConfirmOpen = false
    }
    function applyAll() {
        if (!KeyboardRemap.hasPendingChanges || KeyboardRemap.applyInProgress)
            return
        pageRoot.settingsRoot.keyremapApplyConfirmOpen = true
    }

    readonly property bool showList: pageRoot.wideLayout
        || !pageRoot.settingsRoot.keyremapDetailOpen
        || KeyboardRemap.selectedDeviceId === ""
    readonly property bool showDetail: pageRoot.wideLayout
        ? KeyboardRemap.selectedDeviceId !== ""
        : (pageRoot.settingsRoot.keyremapDetailOpen && KeyboardRemap.selectedDeviceId !== "")

    readonly property string healthTitle: {
        if (KeyboardRemap.state === "setup")
            return "Needs setup"
        if (!KeyboardRemap.keydReady)
            return "keyd not ready"
        if (KeyboardRemap.hasPendingChanges)
            return "Pending changes"
        return "Ready"
    }
    readonly property string healthDetail: {
        const n = KeyboardRemap.availableDevices.length
        const devices = `${n} keyboard${n === 1 ? "" : "s"}`
        if (KeyboardRemap.lastError.length > 0)
            return KeyboardRemap.lastError
        if (KeyboardRemap.hasPendingChanges)
            return `${devices} · draft not applied yet`
        if (KeyboardRemap.keydReady)
            return `${devices} · config matches this page`
        return `${devices} · check keyd service`
    }
    readonly property bool healthWarning: !KeyboardRemap.keydReady
        || KeyboardRemap.state === "setup"
        || KeyboardRemap.lastError.length > 0

    width: parent ? parent.width : 900
    spacing: SettingsTokens.controlGap
    implicitHeight: {
        const viewportHeight = pageRoot.settingsRoot ? pageRoot.settingsRoot.height - 120 : 500
        const contentHeight = contentGrid.implicitHeight + 50 + spacing + 12
        return Math.max(viewportHeight, contentHeight)
    }

    function openDevice(hyprName) {
        KeyboardRemap.selectDevice(hyprName)
        pageRoot.settingsRoot.keyremapDetailOpen = true
        pageRoot.settingsRoot.keyremapApplyConfirmOpen = false
    }

    function closeDetail() {
        pageRoot.settingsRoot.keyremapDetailOpen = false
        pageRoot.settingsRoot.keyremapEditingPreset = ""
    }

    GridLayout {
        id: contentGrid
        Layout.fillWidth: true
        Layout.fillHeight: true
        columns: pageRoot.wideLayout ? 2 : 1
        columnSpacing: SettingsTokens.columnGap
        rowSpacing: SettingsTokens.columnGap

        // ════════════════════════════════════════
        // LEFT · Status & keyboards
        // ════════════════════════════════════════
        Rectangle {
            visible: pageRoot.showList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: pageRoot.wideLayout
                ? (contentGrid.width - SettingsTokens.columnGap) / 2
                : contentGrid.width
            implicitHeight: leftColumn.implicitHeight + SettingsTokens.panelPadding * 2
            radius: SettingsTokens.roundRadius
            color: SettingsTokens.panel
            border.width: 1
            border.color: SettingsTokens.line

            ColumnLayout {
                id: leftColumn
                anchors.fill: parent
                anchors.margins: SettingsTokens.panelPadding
                spacing: SettingsTokens.sectionGap

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
                            color: pageRoot.healthWarning ? SettingsTokens.warningPanel : SettingsTokens.accentSoft
                            border.width: pageRoot.healthWarning ? 1 : 0
                            border.color: pageRoot.healthWarning ? SettingsTokens.warningBorder : "transparent"

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: pageRoot.healthWarning ? "warning" : "keyboard"
                                iconSize: 25
                                color: pageRoot.healthWarning ? SettingsTokens.danger : SettingsTokens.accent
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3

                            StyledText {
                                Layout.fillWidth: true
                                text: "Keyboard remap"
                                color: SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: `${pageRoot.healthTitle}  ·  ${pageRoot.healthDetail}`
                                color: pageRoot.healthWarning ? SettingsTokens.danger : SettingsTokens.muted
                                font.pixelSize: Appearance.font.pixelSize.small
                                wrapMode: Text.WordWrap
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
                    title: "Service"

                    ButtonRow {
                        SettingsButton {
                            label: KeyboardRemap.state === "setup" ? "Setup keyd" : "Recheck"
                            iconName: KeyboardRemap.state === "setup" ? "download" : "refresh"
                            onClicked: {
                                if (KeyboardRemap.state === "setup")
                                    KeyboardRemap.setup()
                                else
                                    KeyboardRemap.checkKeyd()
                            }
                        }
                        SettingsButton {
                            label: "Refresh list"
                            iconName: "devices"
                            onClicked: {
                                KeyboardRemap.refreshDevices()
                                KeyboardRemap.loadProfiles()
                                KeyboardRemap.checkKeyd()
                            }
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        text: KeyboardRemap.hasPendingChanges
                            ? "Use Apply in the footer to write /etc/keyd/omd.conf and restart keyd."
                            : "Select a keyboard to enable presets. Changes stay as a draft until Apply."
                        color: SettingsTokens.dim
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        wrapMode: Text.WordWrap
                    }
                }

                SettingsSection {
                    title: "Keyboards"

                    Repeater {
                        model: KeyboardRemap.availableDevices
                        delegate: Rectangle {
                            id: deviceRow
                            required property var modelData
                            readonly property int presetCount: KeyboardRemap.devicePresetCount(modelData.hyprName)
                            readonly property bool selected: modelData.hyprName === KeyboardRemap.selectedDeviceId

                            Layout.fillWidth: true
                            implicitHeight: 56
                            radius: SettingsTokens.radius
                            color: deviceRow.selected
                                ? SettingsTokens.accentSoft
                                : (deviceMouse.containsMouse ? SettingsTokens.cardHover : "transparent")
                            border.width: deviceRow.selected ? 1 : 0
                            border.color: SettingsTokens.accent

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 12
                                spacing: 12

                                MaterialSymbol {
                                    Layout.preferredWidth: 22
                                    text: "keyboard"
                                    iconSize: 18
                                    color: SettingsTokens.muted
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: deviceRow.modelData.displayName
                                        color: SettingsTokens.fg
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: deviceRow.selected ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: deviceRow.modelData.connected
                                            ? (deviceRow.modelData.keydId || "missing keyd id")
                                            : `${deviceRow.modelData.keydId || "missing keyd id"} · saved, disconnected`
                                        color: SettingsTokens.dim
                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                        elide: Text.ElideRight
                                    }
                                }

                                StyledText {
                                    text: deviceRow.presetCount > 0
                                        ? `${deviceRow.presetCount} preset${deviceRow.presetCount === 1 ? "" : "s"}`
                                        : "none"
                                    color: deviceRow.presetCount > 0 ? SettingsTokens.accent : SettingsTokens.muted
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                }

                                Rectangle {
                                    Layout.preferredWidth: 8
                                    Layout.preferredHeight: 8
                                    radius: 4
                                    color: deviceRow.modelData.connected ? SettingsTokens.accent : SettingsTokens.muted
                                }

                                MaterialSymbol {
                                    visible: !pageRoot.wideLayout
                                    text: "chevron_right"
                                    iconSize: 18
                                    color: SettingsTokens.muted
                                }
                            }

                            MouseArea {
                                id: deviceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pageRoot.openDevice(deviceRow.modelData.hyprName)
                            }
                        }
                    }

                    SettingsRow {
                        visible: KeyboardRemap.availableDevices.length === 0
                        iconName: "info"
                        label: "No keyboards found"
                        description: "Refresh after connecting a keyboard."
                        clickable: false
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // ════════════════════════════════════════
        // RIGHT · Selected keyboard
        // ════════════════════════════════════════
        Rectangle {
            visible: pageRoot.showDetail || pageRoot.wideLayout
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: pageRoot.wideLayout
                ? (contentGrid.width - SettingsTokens.columnGap) / 2
                : contentGrid.width
            implicitHeight: rightColumn.implicitHeight + SettingsTokens.panelPadding * 2
            radius: SettingsTokens.roundRadius
            color: SettingsTokens.panel
            border.width: 1
            border.color: SettingsTokens.line

            ColumnLayout {
                id: rightColumn
                anchors.fill: parent
                anchors.margins: SettingsTokens.panelPadding
                spacing: SettingsTokens.sectionGap

                // Empty state (wide, nothing selected)
                ColumnLayout {
                    visible: !pageRoot.showDetail
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 10

                    Item { Layout.fillHeight: true }

                    MaterialSymbol {
                        Layout.alignment: Qt.AlignHCenter
                        text: "keyboard"
                        iconSize: 40
                        color: SettingsTokens.muted
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: "Select a keyboard"
                        color: SettingsTokens.fg
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignHCenter
                        text: "Choose a device on the left to enable presets."
                        color: SettingsTokens.muted
                        font.pixelSize: Appearance.font.pixelSize.small
                        wrapMode: Text.WordWrap
                    }

                    Item { Layout.fillHeight: true }
                }

                // Detail
                ColumnLayout {
                    visible: pageRoot.showDetail
                    Layout.fillWidth: true
                    spacing: SettingsTokens.sectionGap

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 40

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 3

                            StyledText {
                                Layout.fillWidth: true
                                text: KeyboardRemap.selectedProfile?.displayName
                                    ?? KeyboardRemap.selectedDeviceId
                                    ?? "Keyboard"
                                color: SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.large
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: {
                                    const n = KeyboardRemap.devicePresetCount(KeyboardRemap.selectedDeviceId)
                                    return n > 0
                                        ? `${n} preset${n === 1 ? "" : "s"} active`
                                        : "No presets active"
                                }
                                color: SettingsTokens.muted
                                font.pixelSize: Appearance.font.pixelSize.small
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 1
                        color: SettingsTokens.line
                    }

                    ButtonRow {
                        visible: !pageRoot.wideLayout || KeyboardRemap.selectedDevice?.connected === false
                        SettingsButton {
                            visible: !pageRoot.wideLayout
                            label: "Back"
                            iconName: "chevron_left"
                            onClicked: pageRoot.closeDetail()
                        }
                        SettingsButton {
                            visible: KeyboardRemap.selectedDevice?.connected === false
                            label: "Remove saved"
                            iconName: "delete"
                            onClicked: {
                                KeyboardRemap.deleteProfile(KeyboardRemap.selectedDeviceId)
                                pageRoot.closeDetail()
                            }
                        }
                    }

                    SettingsRow {
                        iconName: "badge"
                        label: KeyboardRemap.selectedDevice?.keydId || "Missing keyd id"
                        description: KeyboardRemap.selectedKeydIdMissing
                            ? "Remaps cannot apply until this ID is resolved."
                            : "keyd vendor:product id"
                        value: KeyboardRemap.selectedEnabled ? "Enabled" : "Disabled"
                        valueColor: KeyboardRemap.selectedEnabled ? SettingsTokens.accent : SettingsTokens.muted
                        clickable: false
                    }

                    SettingsToggleRow {
                        iconName: "power_settings_new"
                        label: "Enable this keyboard"
                        description: "When off, no presets are emitted for this keyboard."
                        checked: KeyboardRemap.selectedEnabled
                        onToggled: KeyboardRemap.setProfileEnabled(!KeyboardRemap.selectedEnabled)
                    }

                    SettingsSection {
                        title: "Presets"

                        Repeater {
                            model: KeyboardRemap.globalPresetChoices
                            delegate: Rectangle {
                                id: presetRow
                                required property var modelData
                                readonly property bool isRemap: modelData.type === "remap"
                                readonly property string overrideKey: KeyboardRemap.presetOverride(
                                    KeyboardRemap.selectedDeviceId, modelData.id)
                                readonly property bool enabled: KeyboardRemap.devicePresetEnabled(
                                    KeyboardRemap.selectedDeviceId, modelData.id)

                                Layout.fillWidth: true
                                implicitHeight: 56
                                radius: SettingsTokens.radius
                                color: presetMouse.containsMouse ? SettingsTokens.cardHover : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 10

                                    MaterialSymbol {
                                        Layout.preferredWidth: 22
                                        text: "tune"
                                        iconSize: 18
                                        color: SettingsTokens.muted
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: presetRow.modelData.label
                                            color: SettingsTokens.fg
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            Layout.fillWidth: true
                                            text: presetRow.overrideKey.length > 0
                                                ? `${presetRow.modelData.remaps[0].from} → ${presetRow.overrideKey} (custom)`
                                                : presetRow.modelData.description
                                            color: SettingsTokens.dim
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // Edit remap target
                                    Rectangle {
                                        visible: presetRow.isRemap
                                        Layout.preferredWidth: 32
                                        Layout.preferredHeight: 32
                                        radius: SettingsTokens.radius
                                        color: editMouse.containsMouse ? SettingsTokens.buttonHover : "transparent"

                                        MaterialSymbol {
                                            anchors.centerIn: parent
                                            text: "edit"
                                            iconSize: 16
                                            color: presetRow.overrideKey.length > 0
                                                ? SettingsTokens.accent
                                                : SettingsTokens.muted
                                        }

                                        MouseArea {
                                            id: editMouse
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: pageRoot.settingsRoot.keyremapEditingPreset = presetRow.modelData.id
                                        }
                                    }

                                    // Toggle
                                    Rectangle {
                                        Layout.preferredWidth: 46
                                        Layout.preferredHeight: 26
                                        radius: height / 2
                                        color: presetRow.enabled ? SettingsTokens.accent : SettingsTokens.line

                                        Rectangle {
                                            width: 20
                                            height: 20
                                            radius: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: presetRow.enabled ? parent.width - width - 3 : 3
                                            color: presetRow.enabled ? "#111111" : "#dedede"
                                            Behavior on x { NumberAnimation { duration: 110 } }
                                        }

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: KeyboardRemap.setDevicePresetEnabled(
                                                KeyboardRemap.selectedDeviceId,
                                                presetRow.modelData.id,
                                                !presetRow.enabled)
                                        }
                                    }
                                }

                                MouseArea {
                                    id: presetMouse
                                    anchors.fill: parent
                                    anchors.rightMargin: 90
                                    hoverEnabled: true
                                    acceptedButtons: Qt.NoButton
                                }
                            }
                        }
                    }

                    // Apply confirmation (when footer Apply armed it)
                    Rectangle {
                        visible: pageRoot.settingsRoot.keyremapApplyConfirmOpen && KeyboardRemap.hasPendingChanges
                        Layout.fillWidth: true
                        implicitHeight: confirmColumn.implicitHeight + 24
                        radius: SettingsTokens.roundRadius
                        color: SettingsTokens.accentSoft
                        border.width: 1
                        border.color: SettingsTokens.accent

                        ColumnLayout {
                            id: confirmColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 14
                            spacing: 10

                            StyledText {
                                Layout.fillWidth: true
                                text: "Apply keyboard remaps?"
                                color: SettingsTokens.fg
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: "Writes /etc/keyd/omd.conf and restarts keyd. Authorization may be required."
                                color: SettingsTokens.muted
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                wrapMode: Text.WordWrap
                            }

                            ButtonRow {
                                SettingsButton {
                                    label: KeyboardRemap.applyInProgress ? "Applying…" : "Confirm apply"
                                    iconName: "check"
                                    active: true
                                    enabledState: !KeyboardRemap.applyInProgress
                                    onClicked: {
                                        pageRoot.settingsRoot.keyremapApplyConfirmOpen = false
                                        KeyboardRemap.apply()
                                    }
                                }
                                SettingsButton {
                                    label: "Cancel"
                                    iconName: "close"
                                    enabledState: !KeyboardRemap.applyInProgress
                                    onClicked: pageRoot.settingsRoot.keyremapApplyConfirmOpen = false
                                }
                            }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    Component.onCompleted: {
        KeyboardRemap.refreshDevices()
        KeyboardRemap.loadProfiles()
        KeyboardRemap.checkKeyd()
        KeyboardRemap.checkPendingChanges()
    }
}
