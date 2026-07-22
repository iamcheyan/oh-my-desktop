pragma ComponentBehavior: Bound

import qs.modules.bar
import QtQuick

// Host component for the bar UI.
// Delegates to the bar module (qs.modules.bar) which handles per-monitor
// rendering, layout, and all bar widgets/buttons via the registry system.
Singleton {
    id: mainBar

    readonly property Component barComponent: Bar {}

    function create(parent: Item): Bar {
        return barComponent.createObject(parent) as Bar;
    }
}
