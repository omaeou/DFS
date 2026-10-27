import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../core/modules"
import "../shared"
import "../../core/ui"

PanelWindow {
    id: barRoot

    readonly property int capsuleHeight: Math.max(48, Number(GlobalState.config.bar.height) - 12)
    readonly property int capsuleGap: 8
    readonly property real leftWidth: leftCapsule.visible ? leftCapsule.implicitWidth : 0
    readonly property real centerWidth: centerCapsule.visible ? centerCapsule.implicitWidth : 0
    readonly property real rightWidth: rightCapsule.visible ? rightCapsule.implicitWidth : 0
    readonly property bool hasMusicPlayer: GlobalState.config.bar.layout.left.indexOf("musicPlayer") >= 0 ||
        GlobalState.config.bar.layout.center.indexOf("musicPlayer") >= 0 ||
        GlobalState.config.bar.layout.right.indexOf("musicPlayer") >= 0
    readonly property int visibleGroups: (leftCapsule.visible ? 1 : 0) +
        (centerCapsule.visible ? 1 : 0) + (rightCapsule.visible ? 1 : 0)
    readonly property int capsuleGapCount: Math.max(0, visibleGroups - 1)
    readonly property real naturalRowWidth: leftWidth + centerWidth + rightWidth + capsuleGapCount * capsuleGap
    readonly property real fitScale: contentArea.width > 0 && naturalRowWidth > contentArea.width
        ? contentArea.width / naturalRowWidth
        : 1
    readonly property bool anchoredRowFits:
        (!leftCapsule.visible || !centerCapsule.visible || (contentArea.width - centerWidth) / 2 >= leftWidth + capsuleGap) &&
        (!centerCapsule.visible || !rightCapsule.visible || (contentArea.width - centerWidth) / 2 + centerWidth + capsuleGap <= contentArea.width - rightWidth) &&
        (!leftCapsule.visible || !rightCapsule.visible || leftWidth + capsuleGap <= contentArea.width - rightWidth)
    readonly property bool packedLayout: fitScale < 1 || !anchoredRowFits
    readonly property real packedStartX: Math.max(0, (contentArea.width - naturalRowWidth * fitScale) / 2)
    property bool compactPlayer: false

    function updateCompactPlayer() {
        if (!hasMusicPlayer) {
            compactPlayer = false
            return
        }

        // Add back the width saved by compact mode so this decision is based on
        // the full player size and is independent of the current presentation.
        const fullPlayerRowWidth = naturalRowWidth + (compactPlayer ? 196 - 72 : 0)
        const fullPlayerScale = Math.min(1, contentArea.width / Math.max(1, fullPlayerRowWidth))
        // Keep the full player through small layout compression. Switch only
        // when it would make the entire row too small, and restore it at 90%.
        const compactThreshold = compactPlayer ? 0.90 : 0.82
        const shouldCompact = fullPlayerScale < compactThreshold
        if (shouldCompact !== compactPlayer)
            compactPlayer = shouldCompact
    }

    onNaturalRowWidthChanged: Qt.callLater(updateCompactPlayer)
    onWidthChanged: Qt.callLater(updateCompactPlayer)
    Component.onCompleted: Qt.callLater(updateCompactPlayer)

    anchors.top: true
    anchors.left: true
    anchors.right: true
    anchors.bottom: false
    implicitHeight: fitScale < 1
        ? Math.ceil(capsuleHeight * fitScale) + 6
        : Math.max(GlobalState.config.bar.height, capsuleHeight + 6)
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    exclusiveZone: GlobalState.config.bar.autoHide ? 0 : implicitHeight

    Item {
        id: contentArea
        anchors.fill: parent
        anchors.leftMargin: GlobalState.config.bar.margin
        anchors.rightMargin: GlobalState.config.bar.margin
        anchors.topMargin: 3
        anchors.bottomMargin: 3
        onWidthChanged: Qt.callLater(barRoot.updateCompactPlayer)
        opacity: GlobalState.config.bar.autoHide && !reveal.hovered ? 0.05 : 1
        Behavior on opacity { NumberAnimation { duration: GlobalState.animationDuration(180) } }

        HoverHandler {
            id: reveal
        }

        // Keep the three groups on one row. Scale them together when needed, and
        // pack them in order if their usual left/center/right anchors would overlap.
        Capsule {
            id: leftCapsule
            x: barRoot.packedLayout ? barRoot.packedStartX : 0
            y: (contentArea.height - height * barRoot.fitScale) / 2
            scale: barRoot.fitScale
            transformOrigin: Item.TopLeft
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
                    Layout.minimumWidth: moduleId === "musicPlayer" ? (barRoot.compactPlayer ? 72 : 196) : 0
                    Layout.fillWidth: moduleId === "activeWindow" || moduleId === "networkToggle"
                    source: ModuleRegistry.sourceFor(moduleId, "bar")
                    onSourceChanged: if (source === "") console.warn("[DFS] Unknown or disabled left-bar module:", moduleId)
                    onStatusChanged: if (status === Loader.Error) console.warn("[DFS] Failed to load left-bar module:", moduleId, source)
                    onLoaded: {
                        if (moduleId === "musicPlayer")
                            item.compact = Qt.binding(() => barRoot.compactPlayer)
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
            x: barRoot.packedLayout
                ? barRoot.packedStartX + (leftCapsule.visible ? leftWidth + barRoot.capsuleGap : 0) * barRoot.fitScale
                : (contentArea.width - width) / 2
            y: (contentArea.height - height * barRoot.fitScale) / 2
            scale: barRoot.fitScale
            transformOrigin: Item.TopLeft
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
                    Layout.minimumWidth: moduleId === "musicPlayer" ? (barRoot.compactPlayer ? 72 : 196) : 0
                    Layout.fillWidth: moduleId === "activeWindow" || moduleId === "networkToggle"
                    source: ModuleRegistry.sourceFor(moduleId, "bar")
                    onSourceChanged: if (source === "") console.warn("[DFS] Unknown or disabled center-bar module:", moduleId)
                    onStatusChanged: if (status === Loader.Error) console.warn("[DFS] Failed to load center-bar module:", moduleId, source)
                    onLoaded: {
                        if (moduleId === "musicPlayer")
                            item.compact = Qt.binding(() => barRoot.compactPlayer)
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
            x: barRoot.packedLayout
                ? barRoot.packedStartX + (leftWidth + centerWidth + barRoot.capsuleGap *
                    ((leftCapsule.visible ? 1 : 0) + (centerCapsule.visible ? 1 : 0))) * barRoot.fitScale
                : contentArea.width - width
            y: (contentArea.height - height * barRoot.fitScale) / 2
            scale: barRoot.fitScale
            transformOrigin: Item.TopLeft
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
                    Layout.minimumWidth: moduleId === "musicPlayer" ? (barRoot.compactPlayer ? 72 : 196) : 0
                    Layout.fillWidth: moduleId === "activeWindow" || moduleId === "networkToggle"
                    source: ModuleRegistry.sourceFor(moduleId, "bar")
                    onSourceChanged: if (source === "") console.warn("[DFS] Unknown or disabled right-bar module:", moduleId)
                    onStatusChanged: if (status === Loader.Error) console.warn("[DFS] Failed to load right-bar module:", moduleId, source)
                    onLoaded: {
                        if (moduleId === "musicPlayer")
                            item.compact = Qt.binding(() => barRoot.compactPlayer)
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
