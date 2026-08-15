pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.panels.lock
import Quickshell

FocusScope {
    id: root
    anchors.fill: parent

    required property LockContext context
    property var screen
    readonly property bool requirePasswordToPower: Config.options.lock.security.requirePasswordToPower
    readonly property string wallpaperPath: {
        const path = FileUtils.expandHomePath(Config.options.background.wallpaperPath);
        const isVideo = path.endsWith(".mp4") || path.endsWith(".webm") || path.endsWith(".mkv") || path.endsWith(".avi") || path.endsWith(".mov");
        return isVideo ? FileUtils.expandHomePath(Config.options.background.thumbnailPath) : path;
    }
    readonly property string snapshotPath: root.context.snapshotForScreen(root.screen?.name ?? "")
    readonly property string backgroundPath: root.snapshotPath || root.wallpaperPath
    /// Prefer AccountsService / ~/.face style avatars (macOS-like user photo).
    readonly property var avatarCandidates: {
        const home = FileUtils.trimFileProtocol(Directories.home || "");
        const user = Quickshell.env("USER") || "";
        const list = [];
        if (user.length)
            list.push("file:///var/lib/AccountsService/icons/" + user);
        if (home.length) {
            list.push("file://" + home + "/.face");
            list.push("file://" + home + "/.face.icon");
        }
        return list;
    }
    property int avatarCandidateIndex: 0
    readonly property string avatarSource: {
        if (avatarCandidateIndex < 0 || avatarCandidateIndex >= avatarCandidates.length)
            return "";
        return avatarCandidates[avatarCandidateIndex];
    }
    property string timeText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: englishDate(new Date())
    property bool ctrlHeld: false
    property bool passwordVisible: false
    property bool showPasswordText: false
    property int focusAttempts: 0
    property bool avatarLoaded: false

    focus: true

    Component.onCompleted: startFocusRecovery()

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        onPressed: {
            if (!root.passwordVisible)
                root.revealPassword();
            else
                root.startFocusRecovery();
        }
    }

    Connections {
        target: context
        function onShouldReFocus() {
            startFocusRecovery();
        }
    }

    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) {
                root.context.currentText = "";
                root.passwordVisible = false;
                root.showPasswordText = false;
                root.startFocusRecovery();
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: {
            const now = new Date();
            root.timeText = Qt.formatDateTime(now, "HH:mm");
            root.dateText = englishDate(now);
        }
    }

    Timer {
        id: focusRecoveryTimer
        interval: 80
        repeat: true
        onTriggered: {
            root.focusAttempts += 1;
            root.forceLockFocus();
            if (root.focusAttempts >= 14)
                stop();
        }
    }

    Keys.onPressed: event => {
        root.context.resetClearTimer();
        if (event.key === Qt.Key_Control) {
            root.ctrlHeld = true;
            return;
        }
        if (event.key === Qt.Key_Escape) {
            root.context.currentText = "";
            root.passwordVisible = false;
            root.showPasswordText = false;
            startFocusRecovery();
            event.accepted = true;
            return;
        }
        if (!root.passwordVisible) {
            if (event.key === Qt.Key_Space) {
                root.revealPassword();
                event.accepted = true;
            }
            return;
        }
        if (event.key === Qt.Key_Backspace) {
            if (root.context.currentText.length > 0)
                root.context.currentText = root.context.currentText.slice(0, -1);
            event.accepted = true;
            return;
        }
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.context.tryUnlock(root.ctrlHeld);
            event.accepted = true;
            return;
        }
        const typed = root.keyEventToText(event);
        if (typed.length > 0) {
            root.context.currentText += typed;
            event.accepted = true;
        }
    }

    Keys.onReleased: event => {
        if (event.key === Qt.Key_Control)
            root.ctrlHeld = false;
    }

    StyledImage {
        id: background
        anchors.fill: parent
        source: root.snapshotPath
            ? Qt.resolvedUrl(`file://${root.snapshotPath}`)
            : root.backgroundPath
        fillMode: Image.PreserveAspectCrop
        cache: false
        smooth: true
        visible: false
    }

    GaussianBlur {
        anchors.fill: parent
        source: background
        radius: 36
        samples: 65
    }

    // Soft macOS-style wash: even dim, no heavy vignette blocks
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.28
    }

    ColumnLayout {
        id: clockBlock
        anchors {
            top: parent.top
            topMargin: Math.max(48, parent.height * 0.07)
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 0

        // Date — light, secondary (macOS lock hierarchy)
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.dateText
            color: Qt.rgba(1, 1, 1, 0.62)
            font.pixelSize: 15
            font.weight: Font.Normal
            font.letterSpacing: 0.2
        }

        // Time — hero; prefer light weight like SF Pro
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            text: root.timeText
            color: Qt.rgba(1, 1, 1, 0.96)
            font.family: Appearance.font.family.title
            font.pixelSize: Math.min(96, Math.max(68, root.height * 0.11))
            font.weight: Font.Light
            font.letterSpacing: -1.5
        }
    }

    ColumnLayout {
        id: unlockBlock
        anchors {
            horizontalCenter: parent.horizontalCenter
            // Slightly above true center — login window, not a dialog plate
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: Math.max(8, parent.height * 0.02)
        }
        width: Math.min(320, parent.width - 64)
        spacing: 10

        // Avatar — mid size, thin ring, photo preferred
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 76
            Layout.preferredHeight: 76

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: Qt.rgba(1, 1, 1, 0.10)
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.22)
            }

            Image {
                id: avatarImage
                anchors.fill: parent
                anchors.margins: 1
                source: root.avatarSource
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                smooth: true
                visible: false
                onStatusChanged: {
                    if (status === Image.Ready) {
                        root.avatarLoaded = true;
                    } else if (status === Image.Error || status === Image.Null) {
                        root.avatarLoaded = false;
                        if (root.avatarCandidateIndex + 1 < root.avatarCandidates.length)
                            root.avatarCandidateIndex += 1;
                    }
                }
                onSourceChanged: root.avatarLoaded = false
            }

            Rectangle {
                id: avatarMask
                anchors.fill: avatarImage
                radius: width / 2
                visible: false
            }

            OpacityMask {
                anchors.fill: avatarImage
                source: avatarImage
                maskSource: avatarMask
                visible: root.avatarLoaded
            }

            MaterialSymbol {
                anchors.centerIn: parent
                visible: !root.avatarLoaded
                text: "person"
                iconSize: 36
                color: Qt.rgba(1, 1, 1, 0.88)
                fill: 1
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            text: SystemInfo.username
            color: Qt.rgba(1, 1, 1, 0.88)
            font.pixelSize: 16
            font.weight: Font.Normal
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: !root.passwordVisible
            text: "Click or press Space"
            color: Qt.rgba(1, 1, 1, 0.45)
            font.pixelSize: 13
            font.weight: Font.Normal
        }

        // Password capsule — short, quiet, glyph actions without chrome chips
        Rectangle {
            id: passwordCard
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            Layout.preferredWidth: Math.min(236, unlockBlock.width)
            Layout.preferredHeight: 32
            visible: root.passwordVisible
            opacity: root.passwordVisible ? 1 : 0
            radius: height / 2
            color: Qt.rgba(0, 0, 0, 0.42)
            border.width: 0.5
            border.color: GlobalStates.screenUnlockFailed
                ? Qt.rgba(0.95, 0.45, 0.42, 0.55)
                : Qt.rgba(1, 1, 1, root.context.currentText.length > 0 ? 0.28 : 0.14)

            Behavior on opacity {
                NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
            }
            Behavior on border.color {
                ColorAnimation { duration: 180 }
            }

            // Submit — bare glyph, no filled disc
            Item {
                id: unlockButton
                anchors {
                    right: parent.right
                    rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                width: 20
                height: 20
                opacity: unlockMouse.containsMouse ? 1 : 0.72

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.ctrlHeld ? "coffee" : "arrow_forward"
                    iconSize: 16
                    color: "#f5f5f5"
                }

                MouseArea {
                    id: unlockMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.context.unlockInProgress
                    onClicked: root.context.tryUnlock(root.ctrlHeld)
                }
            }

            // Eye — only when focused / has text or hover
            Item {
                id: visibilityButton
                anchors {
                    right: unlockButton.left
                    rightMargin: 6
                    verticalCenter: parent.verticalCenter
                }
                width: 20
                height: 20
                opacity: (visibilityMouse.containsMouse || root.showPasswordText || root.context.currentText.length > 0)
                    ? (visibilityMouse.containsMouse ? 1 : 0.55)
                    : 0.28

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.showPasswordText ? "visibility_off" : "visibility"
                    iconSize: 15
                    color: "#f0f0f0"
                }

                MouseArea {
                    id: visibilityMouse
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.context.unlockInProgress
                    onClicked: root.showPasswordText = !root.showPasswordText
                }
            }

            TextInput {
                id: passwordBox
                anchors {
                    left: parent.left
                    leftMargin: 14
                    right: visibilityButton.left
                    rightMargin: 4
                    verticalCenter: parent.verticalCenter
                }
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                enabled: !root.context.unlockInProgress
                readOnly: true
                focus: false
                activeFocusOnPress: false
                echoMode: root.showPasswordText ? TextInput.Normal : TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhLatinOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                text: root.context.currentText
                color: "#f7f7f7"
                selectedTextColor: "#050505"
                selectionColor: OmarchyTheme.accent
                font.family: Appearance.font.family.main
                font.pixelSize: 13
                font.weight: Font.Normal
                passwordCharacter: "•"
                passwordMaskDelay: 0

                Connections {
                    target: root.context
                    function onCurrentTextChanged() {
                        if (passwordBox.text !== root.context.currentText)
                            passwordBox.text = root.context.currentText;
                    }
                }

                ErrorShakeAnimation {
                    id: wrongPasswordShakeAnim
                    target: passwordCard
                }

                Connections {
                    target: GlobalStates
                    function onScreenUnlockFailedChanged() {
                        if (GlobalStates.screenUnlockFailed)
                            wrongPasswordShakeAnim.restart();
                    }
                }
            }

            StyledText {
                anchors {
                    left: parent.left
                    leftMargin: 14
                    verticalCenter: parent.verticalCenter
                }
                visible: passwordBox.text.length === 0
                text: GlobalStates.screenUnlockFailed ? "Incorrect password" : "Enter Password"
                color: GlobalStates.screenUnlockFailed
                    ? Qt.rgba(0.95, 0.72, 0.72, 0.95)
                    : Qt.rgba(1, 1, 1, 0.38)
                font.pixelSize: 13
                font.weight: Font.Normal
            }
        }
    }

    // Bottom-left: status only — no chrome, no click (battery is display-only)
    Row {
        id: leftActions
        anchors {
            left: parent.left
            leftMargin: Math.max(28, parent.width * 0.03)
            bottom: parent.bottom
            bottomMargin: Math.max(22, parent.height * 0.04)
        }
        spacing: 10

        // Battery: plain icon + percent, no pill background, not clickable
        Row {
            id: batteryStatus
            visible: Battery.available
            spacing: 5
            height: 20

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.isCharging ? "bolt" : "battery_android_full"
                iconSize: 16
                color: Qt.rgba(1, 1, 1, 0.72)
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: `${Math.round(Battery.percentage * 100)}%`
                color: Qt.rgba(1, 1, 1, 0.72)
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }

        MacCornerAction {
            visible: root.context.fingerprintsConfigured
            icon: "fingerprint"
            tooltip: "Fingerprint"
            onClicked: root.context.tryFingerUnlock()
        }
    }

    // Bottom-right: icon-only power actions (macOS corner style)
    Row {
        id: rightActions
        anchors {
            right: parent.right
            rightMargin: Math.max(28, parent.width * 0.03)
            bottom: parent.bottom
            bottomMargin: Math.max(22, parent.height * 0.04)
        }
        spacing: 6

        MacCornerAction {
            icon: "dark_mode"
            tooltip: "Sleep"
            onClicked: Session.suspend()
        }

        MacCornerAction {
            icon: "restart_alt"
            tooltip: "Restart"
            onClicked: guardedAction(LockContext.ActionEnum.Reboot)
        }

        MacCornerAction {
            icon: "power_settings_new"
            tooltip: "Shut Down"
            onClicked: guardedAction(LockContext.ActionEnum.Poweroff)
        }
    }

    function forceLockFocus() {
        root.forceActiveFocus(Qt.TabFocusReason);
        if (Qt.inputMethod)
            Qt.inputMethod.hide();
    }

    function startFocusRecovery() {
        root.context.deactivateInputMethod();
        root.focusAttempts = 0;
        forceLockFocus();
        focusRecoveryTimer.restart();
    }

    function revealPassword() {
        root.passwordVisible = true;
        startFocusRecovery();
    }

    // fcitx/rime eats event.text for plain letter keys while IME is active.
    // Fall back to physical key codes so passwords still work after repeated locks.
    function keyEventToText(event) {
        if (event.text.length === 1 && event.text !== "\t")
            return event.text;

        const shift = !!(event.modifiers & Qt.ShiftModifier);

        if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z)
            return String.fromCharCode(event.key + (shift ? 0 : 32));

        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) {
            if (!shift)
                return String.fromCharCode(event.key);
            const shifted = ")!@#$%^&*(";
            return shifted[event.key - Qt.Key_0];
        }

        switch (event.key) {
        case Qt.Key_Space:
            return " ";
        case Qt.Key_Minus:
            return shift ? "_" : "-";
        case Qt.Key_Equal:
            return shift ? "+" : "=";
        case Qt.Key_BracketLeft:
            return shift ? "{" : "[";
        case Qt.Key_BracketRight:
            return shift ? "}" : "]";
        case Qt.Key_Semicolon:
            return shift ? ":" : ";";
        case Qt.Key_Apostrophe:
            return shift ? "\"" : "'";
        case Qt.Key_Comma:
            return shift ? "<" : ",";
        case Qt.Key_Period:
            return shift ? ">" : ".";
        case Qt.Key_Slash:
            return shift ? "?" : "/";
        case Qt.Key_Backslash:
            return shift ? "|" : "\\";
        case Qt.Key_QuoteLeft:
            return shift ? "~" : "`";
        default:
            return "";
        }
    }

    function englishDate(date) {
        const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
        const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
        return `${days[date.getDay()]}, ${months[date.getMonth()]} ${date.getDate()}, ${date.getFullYear()}`;
    }

    function guardedAction(targetAction) {
        if (!root.requirePasswordToPower) {
            root.context.unlocked(targetAction);
            return;
        }

        if (root.context.targetAction === targetAction) {
            root.context.resetTargetAction();
        } else {
            root.context.targetAction = targetAction;
            root.context.shouldReFocus();
        }
    }

    /// Compact corner control: icon-first, optional always-on label (battery %).
    component MacCornerAction: Item {
        id: action
        property string icon
        property string label: ""
        property string tooltip: ""
        property bool showLabelAlways: false
        signal clicked()

        readonly property bool expanded: showLabelAlways || actionMouse.containsMouse
        implicitWidth: showLabelAlways
            ? Math.max(44, chipRow.implicitWidth + 14)
            : (expanded && label.length > 0 ? Math.max(36, chipRow.implicitWidth + 14) : 36)
        implicitHeight: 36

        Behavior on implicitWidth {
            NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: actionMouse.containsMouse
                ? Qt.rgba(1, 1, 1, 0.14)
                : Qt.rgba(0, 0, 0, 0.22)
            border.width: 0.5
            border.color: Qt.rgba(1, 1, 1, 0.10)

            Behavior on color {
                ColorAnimation { duration: 100 }
            }
        }

        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: 5

            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: action.icon
                iconSize: 18
                color: Qt.rgba(1, 1, 1, 0.88)
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: action.showLabelAlways || (actionMouse.containsMouse && action.label.length > 0)
                text: action.label.length > 0 ? action.label : action.tooltip
                color: Qt.rgba(1, 1, 1, 0.82)
                font.pixelSize: 12
                font.weight: Font.Normal
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }

        // Hover tooltip when icon-only and no expanding label
        StyledText {
            anchors {
                horizontalCenter: parent.horizontalCenter
                bottom: parent.top
                bottomMargin: 8
            }
            visible: actionMouse.containsMouse && !action.showLabelAlways && action.label.length === 0 && action.tooltip.length > 0
            text: action.tooltip
            color: Qt.rgba(1, 1, 1, 0.75)
            font.pixelSize: 11
        }
    }
}
