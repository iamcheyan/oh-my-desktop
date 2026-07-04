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
    readonly property bool requirePasswordToPower: Config.options.lock.security.requirePasswordToPower
    readonly property string wallpaperPath: {
        const path = FileUtils.expandHomePath(Config.options.background.wallpaperPath);
        const isVideo = path.endsWith(".mp4") || path.endsWith(".webm") || path.endsWith(".mkv") || path.endsWith(".avi") || path.endsWith(".mov");
        return isVideo ? FileUtils.expandHomePath(Config.options.background.thumbnailPath) : path;
    }
    property string timeText: Qt.formatDateTime(new Date(), "HH:mm")
    property string dateText: englishDate(new Date())
    property bool ctrlHeld: false
    property bool passwordVisible: false
    property int focusAttempts: 0
    readonly property string screenshotPath: "/tmp/quickshell/lock/screenshot-" + (root.QsWindow?.window?.screen?.name ?? "default") + ".png"
    property bool useFallback: false

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
                root.useFallback = false;
                root.context.currentText = "";
                root.passwordVisible = false;
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
        id: wallpaper
        anchors.fill: parent
        source: (GlobalStates.screenLocked && !root.useFallback) ? ("file://" + root.screenshotPath + "?t=" + Date.now()) : root.wallpaperPath
        fillMode: Image.PreserveAspectCrop
        cache: false
        smooth: true
        visible: false

        onStatusChanged: {
            if (status === Image.Error && !root.useFallback) {
                root.useFallback = true;
            }
        }
    }

    GaussianBlur {
        anchors.fill: parent
        source: wallpaper
        radius: 64
        samples: 64
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.34
    }

    Rectangle {
        id: vignette
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#33000000" }
            GradientStop { position: 0.45; color: "#00000000" }
            GradientStop { position: 1.0; color: "#66000000" }
        }
    }

    ColumnLayout {
        id: clockBlock
        anchors {
            top: parent.top
            topMargin: Math.max(54, parent.height * 0.065)
            horizontalCenter: parent.horizontalCenter
        }
        spacing: 2

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.dateText
            color: "#d6d6d6"
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.Medium
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.timeText
            color: "#f2f2f2"
            font.family: Appearance.font.family.title
            font.pixelSize: Math.min(86, Math.max(62, root.height * 0.105))
            font.weight: Font.DemiBold
        }
    }

    ColumnLayout {
        id: unlockBlock
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: Math.max(10, parent.height * 0.035)
        }
        width: Math.min(390, parent.width - 48)
        spacing: 12

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: SystemInfo.username
            color: "#eeeeee"
            font.pixelSize: Appearance.font.pixelSize.large
            font.weight: Font.DemiBold
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            visible: !root.passwordVisible
            text: "Press Space to unlock"
            color: "#b8b8b8"
            font.pixelSize: Appearance.font.pixelSize.normal
            opacity: 0.82
        }

        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(260, unlockBlock.width)
            Layout.preferredHeight: 34
            visible: root.passwordVisible
            opacity: root.passwordVisible ? 1 : 0
            radius: 0
            color: "transparent"
            border.width: 0

            Behavior on opacity {
                NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
            }

            TextInput {
                id: passwordBox
                anchors {
                    fill: parent
                    leftMargin: 2
                    rightMargin: unlockButton.width + 10
                }
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                enabled: !root.context.unlockInProgress
                readOnly: true
                focus: false
                activeFocusOnPress: false
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData | Qt.ImhLatinOnly | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                text: root.context.currentText
                color: "#f4f4f4"
                selectedTextColor: "#050505"
                selectionColor: OmarchyTheme.accent
                font.family: Appearance.font.family.main
                font.pixelSize: Appearance.font.pixelSize.small
                passwordCharacter: "•"

                Connections {
                    target: root.context
                    function onCurrentTextChanged() {
                        if (passwordBox.text !== root.context.currentText)
                            passwordBox.text = root.context.currentText;
                    }
                }

                ErrorShakeAnimation {
                    id: wrongPasswordShakeAnim
                    target: passwordBox
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
                    leftMargin: 2
                    verticalCenter: parent.verticalCenter
                }
                visible: passwordBox.text.length === 0
                text: GlobalStates.screenUnlockFailed ? "Incorrect password" : "Password"
                color: GlobalStates.screenUnlockFailed ? "#f0b8b8" : "#a8a8a8"
                font.pixelSize: Appearance.font.pixelSize.small
            }

            Rectangle {
                anchors {
                    left: parent.left
                    right: parent.right
                    bottom: parent.bottom
                    rightMargin: unlockButton.width + 8
                }
                height: 1
                color: root.context.currentText.length > 0 ? Qt.rgba(1, 1, 1, 0.58) : Qt.rgba(1, 1, 1, 0.30)
            }

            Rectangle {
                id: unlockButton
                anchors {
                    right: parent.right
                    rightMargin: 0
                    verticalCenter: parent.verticalCenter
                }
                width: 30
                height: 30
                radius: 15
                color: unlockMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.14) : "transparent"

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: root.ctrlHeld ? "coffee" : "arrow_forward"
                    iconSize: 19
                    color: "#e8e8e8"
                }

                MouseArea {
                    id: unlockMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !root.context.unlockInProgress
                    onClicked: root.context.tryUnlock(root.ctrlHeld)
                }
            }
        }
    }

    RowLayout {
        id: leftActions
        anchors {
            left: parent.left
            leftMargin: Math.max(34, parent.width * 0.035)
            bottom: parent.bottom
            bottomMargin: Math.max(26, parent.height * 0.045)
        }
        spacing: 10

        MiniAction {
            visible: Battery.available
            icon: Battery.isCharging ? "bolt" : "battery_android_full"
            label: `${Math.round(Battery.percentage * 100)}%`
        }

        MiniAction {
            visible: root.context.fingerprintsConfigured
            icon: "fingerprint"
            label: "Fingerprint"
            onClicked: root.context.tryFingerUnlock()
        }
    }

    RowLayout {
        id: rightActions
        anchors {
            right: parent.right
            rightMargin: Math.max(34, parent.width * 0.035)
            bottom: parent.bottom
            bottomMargin: Math.max(26, parent.height * 0.045)
        }
        spacing: 10

        MiniAction {
            icon: "dark_mode"
            label: "Sleep"
            onClicked: Session.suspend()
        }

        MiniAction {
            icon: "restart_alt"
            label: "Restart"
            onClicked: guardedAction(LockContext.ActionEnum.Reboot)
        }

        MiniAction {
            icon: "power_settings_new"
            label: "Power"
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

    component MiniAction: Item {
        id: action
        property string icon
        property string label
        signal clicked()

        implicitWidth: Math.max(42, actionRow.implicitWidth + 16)
        implicitHeight: 34

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: actionMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.15) : Qt.rgba(0, 0, 0, 0.18)
        }

        RowLayout {
            id: actionRow
            anchors.centerIn: parent
            spacing: 6

            MaterialSymbol {
                text: action.icon
                iconSize: 18
                color: "#dddddd"
            }

            StyledText {
                text: action.label
                color: "#d8d8d8"
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }
    }
}
