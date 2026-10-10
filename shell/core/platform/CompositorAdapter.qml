pragma Singleton
import QtQuick

// Stable workspace API for UI modules. Only this adapter facade should need
// to change when DFS gains support for another compositor.
QtObject {
    readonly property var focusedWorkspace: HyprlandAdapter.focusedWorkspace
    readonly property string activeBackend: "hyprland"

    function focusWorkspace(workspaceId) {
        return HyprlandAdapter.focusWorkspace(workspaceId)
    }
}
