//@ pragma UseQApplication
import QtQuick
import Quickshell
import "features/bar"
import "features/controlpanel"

// Alternate entry point for development tools; equivalent to shell.qml.
ShellRoot {
    id: root

    BarView {}
    ControlPanelView {}
}
