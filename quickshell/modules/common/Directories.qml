pragma Singleton
pragma ComponentBehavior: Bound

import qs.services
import qs.modules.common.functions
import QtCore
import QtQuick
import Quickshell

Singleton {
    // XDG Dirs, with "file://"
    readonly property string home: StandardPaths.standardLocations(StandardPaths.HomeLocation)[0]
    readonly property string config: StandardPaths.standardLocations(StandardPaths.ConfigLocation)[0]
    readonly property string state: StandardPaths.standardLocations(StandardPaths.StateLocation)[0]
    readonly property string cache: StandardPaths.standardLocations(StandardPaths.CacheLocation)[0]
    readonly property string genericCache: StandardPaths.standardLocations(StandardPaths.GenericCacheLocation)[0]
    readonly property string documents: StandardPaths.standardLocations(StandardPaths.DocumentsLocation)[0]
    readonly property string downloads: StandardPaths.standardLocations(StandardPaths.DownloadLocation)[0]
    readonly property string pictures: StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
    readonly property string music: StandardPaths.standardLocations(StandardPaths.MusicLocation)[0]
    readonly property string videos: StandardPaths.standardLocations(StandardPaths.MoviesLocation)[0]

    // Other dirs used by the shell, without "file://"
    // Raw XDG state home. Directories.state is Quickshell's app-specific state
    // directory and must not be used for Sumika Shell's shared runtime state.
    readonly property string stateHome: FileUtils.trimFileProtocol(
        Quickshell.env("XDG_STATE_HOME")
        ?? `${Directories.home}/.local/state`
    )
    // Canonical Sumika Shell state root. The environment variable already
    // includes the product suffix, so callers must not append it again.
    readonly property string sumikaStateHome: FileUtils.trimFileProtocol(
        Quickshell.env("SUMIKA_SHELL_STATE_HOME")
        ?? `${Directories.stateHome}/sumika-shell`
    )
    // Repository root: resolved from SUMIKA_SHELL_ROOT env var (set by session wrapper
    // or lib/paths.sh), falling back to the ~/.config/omd -> repo symlink.
    readonly property string root: FileUtils.trimFileProtocol(
        Quickshell.env("SUMIKA_SHELL_ROOT")
        ?? `${Directories.config}/omd`
    )
    property string assetsPath: Quickshell.shellPath("assets")
    property string scriptPath: Quickshell.shellPath("scripts")
    property string coverArt: FileUtils.trimFileProtocol(`${Directories.cache}/media/coverart`)
    property string shellConfig: FileUtils.trimFileProtocol(`${Directories.config}/sumika-shell/quickshell`)
    property string shellConfigName: "config.json"
    property string shellConfigPath: `${Directories.shellConfig}/${Directories.shellConfigName}`
    // Unified config path (sumika.json — replaces individual config files)
    readonly property string sumikaConfig: FileUtils.trimFileProtocol(`${Directories.config}/sumika-shell`)
    readonly property string sumikaConfigName: "sumika.json"
    readonly property string sumikaConfigPath: `${Directories.sumikaConfig}/${Directories.sumikaConfigName}`
    property string notificationsPath: FileUtils.trimFileProtocol(`${Directories.cache}/notifications/notifications.json`)
    property string cliphistDecode: FileUtils.trimFileProtocol(`${Directories.cache}/media/cliphist`)
    property string screenshotTemp: "/tmp/quickshell/media/screenshot"
    property string wallpaperSwitchScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/colors/switchwall.sh`)
    property string recordScriptPath: FileUtils.trimFileProtocol(`${Directories.scriptPath}/videos/record.sh`)
    property string userAvatarPathAccountsService: FileUtils.trimFileProtocol(`/var/lib/AccountsService/icons/${SystemInfo.username}`)
    property string userAvatarPathRicersAndWeirdSystems: FileUtils.trimFileProtocol(`${Directories.home}.face`)
    property string userAvatarPathRicersAndWeirdSystems2: FileUtils.trimFileProtocol(`${Directories.home}.face.icon`)
    // Cleanup on init
    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", `${shellConfig}`])
        Quickshell.execDetached(["bash", "-c", `rm -rf '${coverArt}'; mkdir -p '${coverArt}'`])
        Quickshell.execDetached(["mkdir", "-p", `${cliphistDecode}`])
    }
}
