//@ pragma UseQApplication
import QtQuick
import Quickshell
import "features/bar"
import "features/controlpanel"

// Quickshell looks for shell.qml as the shell root. Keep all top-level
// windows here so each module can be developed and configured independently.
ShellRoot {
    id: root

    BarView {}
    ControlPanelView {}
}
