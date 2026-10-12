pragma Singleton
import QtQuick
import Quickshell
import "../../features/shared"

QtObject {
    id: registry

    readonly property var barBuiltins: ({
        systemInfo: Qt.resolvedUrl("../../features/systeminfo/SystemInfoView.qml"),
        activeWindow: Qt.resolvedUrl("../../features/activeWindow/ActiveWindowView.qml"),
        workspaces: Qt.resolvedUrl("../../features/workspaces/WorkspacesView.qml"),
        clock: Qt.resolvedUrl("../../features/clock/ClockView.qml"),
        systray: Qt.resolvedUrl("../../features/systray/SysTrayView.qml"),
        musicPlayer: Qt.resolvedUrl("../../features/bar/modules/MusicControls.qml"),
        notifications: Qt.resolvedUrl("../../features/bar/modules/NotificationsToggle.qml"),
        networkToggle: Qt.resolvedUrl("../../features/bar/modules/NetworkToggle.qml"),
        wallpaper: Qt.resolvedUrl("../../features/bar/modules/WallpaperToggle.qml"),
        controlPanelToggle: Qt.resolvedUrl("../../features/bar/modules/ControlPanelToggle.qml")
    })

    readonly property var controlPanelBuiltins: ({
        Wifi: Qt.resolvedUrl("../../features/controlpanel/modules/Wifi.qml"),
        Bluetooth: Qt.resolvedUrl("../../features/controlpanel/modules/Bluetooth.qml"),
        Volume: Qt.resolvedUrl("../../features/controlpanel/modules/Volume.qml"),
        Mic: Qt.resolvedUrl("../../features/controlpanel/modules/Mic.qml"),
        Appearance: Qt.resolvedUrl("../../features/controlpanel/modules/AppearanceSettings.qml")
    })

    function builtinMap(target) {
        return target === "controlPanel" ? controlPanelBuiltins : barBuiltins
    }

    function hasKey(object, key) {
        return Object.prototype.hasOwnProperty.call(object, key)
    }

    function sourceFor(moduleId, target) {
        const selectedTarget = target || "bar"
        const builtins = builtinMap(selectedTarget)
        if (hasKey(builtins, moduleId))
            return builtins[moduleId]
        // Built-in IDs are reserved even in the other UI context.
        if (hasKey(barBuiltins, moduleId) || hasKey(controlPanelBuiltins, moduleId))
            return ""

        const plugin = hasKey(GlobalState.config.plugins, moduleId) ? GlobalState.config.plugins[moduleId] : null
        if (!plugin || plugin.enabled !== true || typeof plugin.entrypoint !== "string")
            return ""
        if (plugin.apiVersion !== 1) {
            console.warn("[ModuleRegistry] Unsupported plugin API version for", moduleId)
            return ""
        }
        if (!isSafeEntrypoint(plugin.entrypoint)) {
            console.warn("[ModuleRegistry] Rejected unsafe entrypoint for plugin", moduleId)
            return ""
        }
        return Quickshell.shellDir + "/" + plugin.entrypoint
    }

    function isPlugin(moduleId, target) {
        const selectedTarget = target || "bar"
        const builtins = builtinMap(selectedTarget)
        if (hasKey(barBuiltins, moduleId) || hasKey(controlPanelBuiltins, moduleId))
            return false
        return !hasKey(builtins, moduleId) && sourceFor(moduleId, selectedTarget) !== ""
    }

    function isSafeEntrypoint(entrypoint) {
        if (typeof entrypoint !== "string" || entrypoint.length === 0 ||
            entrypoint.startsWith("/") || entrypoint.indexOf("\\") !== -1 ||
            /[%?#:\u0000-\u001f]/.test(entrypoint) || !entrypoint.endsWith(".qml"))
            return false

        const segments = entrypoint.split("/")
        if (segments.length < 2 || segments[0] !== "plugins")
            return false
        for (let i = 0; i < segments.length; i++) {
            // Restrict each path segment to plain filename characters. This also
            // rejects dot-segments and encoded traversal attempts.
            if (!/^[A-Za-z0-9_-][A-Za-z0-9._-]*$/.test(segments[i]))
                return false
        }
        return true
    }

    function settingsFor(moduleId) {
        if (isPlugin(moduleId, "bar") || isPlugin(moduleId, "controlPanel"))
            return GlobalState.config.plugins[moduleId].settings || ({})
        const modules = GlobalState.config.modules
        const direct = hasKey(modules, moduleId) ? modules[moduleId] : undefined
        if (direct !== undefined)
            return direct
        const conventional = moduleId.charAt(0).toUpperCase() + moduleId.slice(1)
        return hasKey(modules, conventional) ? modules[conventional] : ({})
    }
}
