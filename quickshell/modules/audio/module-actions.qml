pragma ComponentBehavior: Bound
import QtQuick

import qs
import qs.core.runtime
import qs.modules.common
import qs.modules.common.functions
import Quickshell

/// Audio action registrations.
///
/// Registers the audio-mixer launcher used by the SUPER+CTRL+A binding.
/// Loaded by ModuleActionHost when the audio module is enabled.
Item {
    Component.onCompleted: {
        // Mirror the AudioPopup settings gear: honor the user-configured
        // mixer (sumika.json apps.volumeMixer) and apply the GDK scaling
        // workaround GTK4 pavucontrol needs on HiDPI.
        var mixer = (Config.options?.apps?.volumeMixer ?? "").toString();
        if (mixer.length === 0)
            mixer = "pavucontrol";

        ActionManager.register("audio.launch", "audio", "Open audio mixer", {
            type: "process",
            command: ["env", "GDK_SCALE=1", "GDK_DPI_SCALE=0.5", mixer]
        }, {description: "Open the volume mixer"})
    }
}
