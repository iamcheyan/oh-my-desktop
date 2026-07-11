pragma Singleton
import QtQuick
import Quickshell

QtObject {
    readonly property string config: (Quickshell.env("HOME") ?? "") + "/.config"
    readonly property string cache: (Quickshell.env("HOME") ?? "") + "/.cache"
    readonly property string shellConfig: config + "/quickshell"
    readonly property string cliphistDecode: cache + "/media/cliphist"
    readonly property string assetsPath: (Quickshell.env("HOME") ?? "") + "/Development/oh-my-desktop/quickshell/assets"
}
