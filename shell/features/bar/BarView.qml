import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../core/modules"
import "../shared"
import "../../core/ui"

PanelWindow {
    id: barRoot

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: false
    implicitHeight: GlobalState.config.bar.height
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    exclusiveZone: GlobalState.config.bar.autoHide ? 0 : GlobalState.config.bar.height

    Item {
        anchors.fill: parent
        anchors.leftMargin: GlobalState.config.bar.margin
        anchors.rightMargin: GlobalState.config.bar.margin
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        opacity: GlobalState.config.bar.autoHide && !reveal.hovered ? 0.05 : 1
        Behavior on opacity { NumberAnimation { duration: GlobalState.animationDuration(180) } }

        HoverHandler {
            id: reveal
        }

        // Three visually independent metal capsules. There is deliberately no
        // line behind them: it previously crossed the gaps and looked broken.
        Capsule {
            id: leftCapsule
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            visible: GlobalState.config.bar.layout.left.length > 0

            Repeater {
                model: GlobalState.config.bar.layout.left
                delegate: Loader {
                    required property string modelData
                    property string moduleId: modelData
                    // Layout constraints belong to the Loader, not the loaded Text.
                    // Without this, long active-window titles can expand the whole left capsule.
                    Layout.maximumWidth: moduleId === "activeWindow"
                        ? Math.max(100, Math.min(600, Number(GlobalState.config.modules.ActiveWindow.maxWidth) || 250))
                        : (moduleId === "musicPlayer" ? 196 : (moduleId === "networkToggle" ? 112 : -1))
                    source: ModuleRegistry.sourceFor(moduleId, "bar")
                    onSourceChanged: if (source === "") console.warn("[DFS] Unknown or disabled left-bar module:", moduleId)
                    onStatusChanged: if (status === Loader.Error) console.warn("[DFS] Failed to load left-bar module:", moduleId, source)
                    onLoaded: {
                        if (ModuleRegistry.isPlugin(moduleId, "bar")) {
                            item.moduleId = moduleId
                            item.settings = Qt.binding(() => ModuleRegistry.settingsFor(moduleId))
                            item.theme = Qt.binding(() => GlobalState.effectiveTheme)
                        }
                    }
                }
            }
        }

        Capsule {
            id: centerCapsule
            anchors.centerIn: parent
            visible: GlobalState.config.bar.layout.center.length > 0

            Repeater {
                model: GlobalState.config.bar.layout.center
                delegate: Loader {
                    required property string modelData
                    property string moduleId: modelData
                    // Layout constraints belong to the Loader, not the loaded Text.
                    // Without this, long active-window titles can expand the whole left capsule.
                    Layout.maximumWidth: moduleId === "activeWindow"
                        ? Math.max(100, Math.min(600, Number(GlobalState.config.modules.ActiveWindow.maxWidth) || 250))
                        : (moduleId === "musicPlayer" ? 196 : (moduleId === "networkToggle" ? 112 : -1))
                    source: ModuleRegistry.sourceFor(moduleId, "bar")
                    onSourceChanged: if (source === "") console.warn("[DFS] Unknown or disabled center-bar module:", moduleId)
                    onStatusChanged: if (status === Loader.Error) console.warn("[DFS] Failed to load center-bar module:", moduleId, source)
                    onLoaded: {
                        if (ModuleRegistry.isPlugin(moduleId, "bar")) {
                            item.moduleId = moduleId
                            item.settings = Qt.binding(() => ModuleRegistry.settingsFor(moduleId))
                            item.theme = Qt.binding(() => GlobalState.effectiveTheme)
                        }
                    }
                }
            }
        }

        Capsule {
            id: rightCapsule
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9
            visible: GlobalState.config.bar.layout.right.length > 0

            Repeater {
                model: GlobalState.config.bar.layout.right
                delegate: Loader {
                    required property string modelData
                    property string moduleId: modelData
                    // Layout constraints belong to the Loader, not the loaded Text.
                    // Without this, long active-window titles can expand the whole left capsule.
                    Layout.maximumWidth: moduleId === "activeWindow"
                        ? Math.max(100, Math.min(600, Number(GlobalState.config.modules.ActiveWindow.maxWidth) || 250))
                        : (moduleId === "musicPlayer" ? 196 : (moduleId === "networkToggle" ? 112 : -1))
                    source: ModuleRegistry.sourceFor(moduleId, "bar")
                    onSourceChanged: if (source === "") console.warn("[DFS] Unknown or disabled right-bar module:", moduleId)
                    onStatusChanged: if (status === Loader.Error) console.warn("[DFS] Failed to load right-bar module:", moduleId, source)
                    onLoaded: {
                        if (ModuleRegistry.isPlugin(moduleId, "bar")) {
                            item.moduleId = moduleId
                            item.settings = Qt.binding(() => ModuleRegistry.settingsFor(moduleId))
                            item.theme = Qt.binding(() => GlobalState.effectiveTheme)
                        }
                    }
                }
            }
        }
    }
}
