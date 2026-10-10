pragma Singleton
import QtQuick
import Quickshell.Hyprland

QtObject {
    readonly property var focusedWorkspace: Hyprland.focusedWorkspace

    function focusWorkspace(workspaceId) {
        const numericId = Number(workspaceId)
        if (!Number.isFinite(numericId) || Math.trunc(numericId) !== numericId || numericId < 1 || numericId > 999)
            return false
        const id = numericId
        // Hyprland's dispatcher syntax depends on whether the user enabled its
        // Lua configuration provider. Quickshell exposes that mode explicitly.
        if (Hyprland.usingLua)
            Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id.toString() + '" })')
        else
            Hyprland.dispatch("workspace " + id.toString())
        return true
    }
}
