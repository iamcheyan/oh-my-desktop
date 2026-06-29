pragma Singleton
import QtQuick

QtObject {
    // Bluetooth — from Omarchy waybar config
    readonly property string bluetooth: "\uF294"              // fa-bluetooth-b U+F294
    readonly property string bluetoothConnected: "\uDB80\uDCB1" // mdi-bluetooth-connected U+F00B1
    readonly property string bluetoothDisabled: "\uDB80\uDCB2" // mdi-bluetooth-off U+F00B2

    // WiFi / Network — from Omarchy waybar config
    readonly property string wifi0: "\uDB82\uDD2F"            // mdi-wifi-strength-outline U+F092F
    readonly property string wifi1: "\uDB82\uDD1F"            // mdi-wifi-strength-1 U+F091F
    readonly property string wifi2: "\uDB82\uDD22"            // mdi-wifi-strength-2 U+F0922
    readonly property string wifi3: "\uDB82\uDD25"            // mdi-wifi-strength-3 U+F0925
    readonly property string wifi4: "\uDB82\uDD28"            // mdi-wifi-strength-4 U+F0928
    readonly property string wifi: "\uDB82\uDD28"             // mdi-wifi-strength-4 (alias) U+F0928
    readonly property string wifiOff: "\uDB82\uDD2E"          // mdi-wifi-off U+F092E
    readonly property string ethernet: "\uDB80\uDC02"         // mdi-lan U+F0002

    // Volume / Audio — from Omarchy waybar config
    readonly property string volumeHigh: "\uF028"             // fa-volume-high U+F028
    readonly property string volumeLow: "\uF027"              // fa-volume-low U+F027
    readonly property string volumeMedium: "\uF027"           // fa-volume-low U+F027 (same as low)
    readonly property string volumeOff: "\uF026"              // fa-volume-off U+F026
    readonly property string volumeMuted: "\uEEE8"            // nf-md-volume_mute_variant U+EEE8
    readonly property string volumeHeadphone: "\uF025"        // fa-headphones U+F025

    // Battery — from Omarchy waybar config
    readonly property string batteryAlert: "\uDB80\uDC7A"     // mdi-battery-alert U+F007A
    readonly property string battery10: "\uDB80\uDC7B"        // mdi-battery-10 U+F007B
    readonly property string battery20: "\uDB80\uDC7C"        // mdi-battery-20 U+F007C
    readonly property string battery30: "\uDB80\uDC7D"        // mdi-battery-30 U+F007D
    readonly property string battery40: "\uDB80\uDC7E"        // mdi-battery-40 U+F007E
    readonly property string battery50: "\uDB80\uDC7F"        // mdi-battery-50 U+F007F
    readonly property string battery60: "\uDB80\uDC80"        // mdi-battery-60 U+F0080
    readonly property string battery70: "\uDB80\uDC81"        // mdi-battery-70 U+F0081
    readonly property string battery80: "\uDB80\uDC82"        // mdi-battery-80 U+F0082
    readonly property string battery90: "\uDB80\uDC79"        // mdi-battery (full) U+F0079
    readonly property string batteryFull: "\uDB80\uDC79"      // mdi-battery (full) U+F0079
    readonly property string batteryCharging10: "\uDB82\uDC9C" // mdi-battery-charging-outline U+F089C
    readonly property string batteryCharging20: "\uDB80\uDC86" // mdi-battery-charging-20 U+F0086
    readonly property string batteryCharging30: "\uDB80\uDC87" // mdi-battery-charging-30 U+F0087
    readonly property string batteryCharging40: "\uDB80\uDC88" // mdi-battery-charging-40 U+F0088
    readonly property string batteryCharging50: "\uDB82\uDC9D" // mdi-battery-charging-low U+F089D
    readonly property string batteryCharging60: "\uDB80\uDC89" // mdi-battery-charging-60 U+F0089
    readonly property string batteryCharging70: "\uDB82\uDC9E" // mdi-battery-charging-medium U+F089E
    readonly property string batteryCharging80: "\uDB80\uDC8A" // mdi-battery-charging-80 U+F008A
    readonly property string batteryCharging90: "\uDB80\uDC8B" // mdi-battery-charging-90 U+F008B
    readonly property string batteryChargingFull: "\uDB80\uDC85" // mdi-battery-charging-100 U+F0085
    readonly property string batteryPlugged: "\uF1E6"         // fa-plug U+F1E6
    readonly property string bolt: "\uF1E6"                   // fa-plug (same as plugged) U+F1E6

    // CPU — from Omarchy waybar config
    readonly property string cpu: "\uDB80\uDF5B"              // mdi-chip U+F035B

    // Refresh / Update — from Omarchy waybar config
    readonly property string refresh: "\uF021"                // fa-refresh U+F021

    // Voice / Microphone
    readonly property string mic: "\uF130"                    // fa-microphone U+F130
    readonly property string micOff: "\uF131"                 // fa-microphone-slash U+F131
    readonly property string micRecording: "\uF130"           // fa-microphone U+F130
    readonly property string micTranscribing: "\uDB81\uDD1F"  // mdi-timer-sand U+F051F (Omarchy voxtype transcribing)

    // Power
    readonly property string power: "\uF1E6"                  // fa-plug U+F1E6 (same as plugged)
    readonly property string powerSettingsNew: "\uF011"       // fa-power-off U+F011 (shutdown button)

    // Media
    readonly property string musicNote: "\uDB81\uDC05"        // mdi-music-note U+F0405
    readonly property string pause: "\uDB81\uDC24"            // mdi-pause U+F0424
    readonly property string play: "\uDB81\uDC0A"             // mdi-play U+F040A
    readonly property string skipNext: "\uDB81\uDC59"         // mdi-skip-next U+F0459
    readonly property string skipPrevious: "\uDB81\uDC5A"     // mdi-skip-previous U+F045A
    readonly property string shuffle: "\uDB81\uDC57"          // mdi-shuffle U+F0457
    readonly property string repeat: "\uDB81\uDC51"           // mdi-repeat U+F0451
    readonly property string repeatOne: "\uDB81\uDC52"        // mdi-repeat-once U+F0452
    readonly property string album: "\uDB80\uDC1F"            // mdi-album U+F001F
    readonly property string graphicEq: "\uDB80\uDE36"        // mdi-graphic-eq U+F0236

    // Brightness
    readonly property string brightness6: "\uF185"            // fa-sun U+F185

    // Notifications
    readonly property string notifications: "\uDB81\uDC17"    // mdi-bell U+F0417
    readonly property string notificationsOff: "\uDB81\uDC18" // mdi-bell-off U+F0418

    // Navigation / Arrows
    readonly property string expandMore: "\uDB80\uDDDB"       // mdi-chevron-down U+F01DB
    readonly property string expand: "\uF053"                 // fa-chevron-left U+F053 (Omarchy tray expander)
    readonly property string chevronRight: "\uDB80\uDD42"     // mdi-chevron-right U+F0142
    readonly property string chevronLeft: "\uDB80\uDD41"      // mdi-chevron-left U+F0141
    readonly property string arrowBack: "\uDB80\uDC4D"        // mdi-arrow-left U+F004D
    readonly property string arrowForward: "\uDB80\uDC4E"     // mdi-arrow-right U+F004E

    // Actions
    readonly property string edit: "\uDB80\uDFCA"             // mdi-pencil U+F03CA
    readonly property string contentPaste: "\uF0EA"           // fa-clipboard U+F0EA
    readonly property string screenshot: "\uDB83\uDC2B"       // mdi-screenshot U+F0C2B
    readonly property string pushPin: "\uDB81\uDC3F"          // mdi-pin U+F043F
    readonly property string close: "\uDB80\uDD56"            // mdi-close U+F0156
    readonly property string check: "\uDB80\uDD2C"            // mdi-check U+F012C
    readonly property string add: "\uDB80\uDC2F"              // mdi-plus U+F002F
    readonly property string remove: "\uDB81\uDC47"           // mdi-minus U+F0447
    readonly property string stop: "\uDB81\uDCB3"             // mdi-stop U+F04B3
    readonly property string menu: "\uDB80\uDFDB"             // mdi-menu U+F03DB
    readonly property string menuOpen: "\uDB80\uDFDC"         // mdi-menu-open U+F03DC
    readonly property string settings: "\uDB81\uDC93"         // mdi-cog U+F0493

    // Status / Feedback
    readonly property string info: "\uDB80\uDEFC"             // mdi-information U+F02FC
    readonly property string warning: "\uF071"                // fa-exclamation-triangle U+F071
    readonly property string error: "\uDB80\uDEBC"            // mdi-alert-circle U+F02BC
    readonly property string block: "\uDB80\uDF97"            // mdi-block-helper U+F0397
    readonly property string eco: "\uF06C"                    // fa-leaf U+F06C
    readonly property string speed: "\uF0E4"                  // fa-gauge-high U+F0E4
    readonly property string flashOn: "\uDB80\uDE2F"          // mdi-flash U+F022F

    // Visibility
    readonly property string visibility: "\uDB81\uDD3A"       // mdi-eye U+F053A
    readonly property string visibilityOff: "\uDB81\uDD3B"    // mdi-eye-off U+F053B

    // Time / Schedule
    readonly property string schedule: "\uDB81\uDC86"         // mdi-clock U+F0486
    readonly property string timer: "\uDB81\uDCE0"            // mdi-timer U+F04E0

    // Favorites / Stars
    readonly property string favorite: "\uDB80\uDE23"         // mdi-heart U+F0223
    readonly property string star: "\uDB81\uDCCE"             // mdi-star U+F04CE
    readonly property string starOff: "\uDB81\uDCCF"          // mdi-star-off U+F04CF

    // Session
    readonly property string lock: "\uF023"                   // fa-lock U+F023
    readonly property string darkMode: "\uF186"               // fa-moon U+F186
    readonly property string download: "\uF2DC"               // fa-snowflake U+F2DC
    readonly property string logout: "\uF08B"                 // fa-sign-out U+F08B
    readonly property string restart: "\uF01E"                // fa-redo/fa-rotate-right U+F01E

    // Hardware
    readonly property string memory: "\uDB83\uDEF8"           // mdi-memory U+F0EF8
    readonly property string swapHoriz: "\uDB81\uDD4D"        // mdi-swap-horizontal U+F054D

    // Additional menu items
    readonly property string crop: "\uF125"                    // fa-crop U+F125
    readonly property string camera: "\uF030"                  // fa-camera U+F030
    readonly property string desktop: "\uF108"                 // fa-desktop U+F108
    readonly property string eyeDropper: "\uF1FB"              // fa-eye-dropper U+F1FB
    readonly property string video: "\uF03D"                   // fa-video U+F03D
    readonly property string keyboard: "\uF11C"                // fa-keyboard U+F11C
    readonly property string wrench: "\uF0AD"                  // fa-wrench U+F0AD
    readonly property string hourglass: "\uF254"               // fa-hourglass U+F254

    // Misc
    readonly property string keyboardArrowDown: "\uDB80\uDF47" // mdi-chevron-down U+F0347
    readonly property string circle: "\uDB80\uDD66"          // mdi-circle U+F0166
    readonly property string balance: "\uF24E"                 // fa-scale-balanced U+F24E
}