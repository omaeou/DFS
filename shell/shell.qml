//@ pragma UseQApplication
import QtQuick
import Quickshell
import "features/bar"
import "features/controlpanel"
import "features/musicPlayer"
import "features/notifications"
import "features/shared"

// Quickshell looks for shell.qml as the shell root. Keep all top-level
// windows here so each module can be developed and configured independently.
ShellRoot {
    id: root
    Variants {
        model: Quickshell.screens
        BarView {
            required property var modelData
            screen: modelData
            readonly property string outputName: modelData.name
            visible: GlobalState.config.bar.screenIds.length === 0 ||
                     GlobalState.config.bar.screenIds.indexOf(outputName) >= 0
        }
    }
    ControlPanelView {}
    MusicPlayerView {}
    NotificationsView {}
}
