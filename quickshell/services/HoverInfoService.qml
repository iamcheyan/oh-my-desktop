pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick

/**
 * Registry for module hover info.
 *
 * Each module with a bar button registers a Component that renders its hover
 * info content. HoverInfoPopup then loads the registered component when the
 * user hovers over the button.
 *
 * Usage (in a module's bar button):
 *   Component { id: hoverInfo; HoverInfoContent {} }
 *   Component.onCompleted: HoverInfoService.register(moduleId, hoverInfo)
 *   Component.onDestruction: HoverInfoService.unregister(moduleId)
 */
QtObject {
    id: root

    property var _providers: ({})

    function register(moduleId, component): void {
        // console.log("[HoverInfoService] register:", moduleId)
        _providers[moduleId] = component;
    }

    function unregister(moduleId): void {
        // console.log("[HoverInfoService] unregister:", moduleId)
        delete _providers[moduleId];
    }

    function provider(moduleId): var {
        return _providers[moduleId] ?? null;
    }
}
