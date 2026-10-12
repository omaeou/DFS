import QtQuick
import QtQuick.Controls
import QtQuick.Window
import "."

ToolTip {
    id: root

    property Item targetItem: null
    readonly property var shellTheme: GlobalState.effectiveTheme
    readonly property var targetWindow: targetItem ? targetItem.Window.window : null
    readonly property point targetGlobalPosition: targetItem ? targetItem.mapToItem(null, 0, 0) : Qt.point(0, 0)

    parent: targetItem
    x: {
        if (!targetItem)
            return 0
        const hostWidth = targetWindow ? targetWindow.width : 1920
        const centered = targetGlobalPosition.x + (targetItem.width - width) / 2
        const clamped = Math.max(4, Math.min(hostWidth - width - 4, centered))
        return clamped - targetGlobalPosition.x
    }
    y: {
        if (!targetItem)
            return 0
        const globalTop = targetGlobalPosition.y
        const hostHeight = targetWindow ? targetWindow.height : 1080
        const roomBelow = hostHeight - (globalTop + targetItem.height)
        if (hostHeight < 120)
            return targetItem.height + 7
        return roomBelow >= implicitHeight + 10 ? targetItem.height + 7 : -implicitHeight - 7
    }
    delay: 380
    timeout: 5000
    leftPadding: 10
    rightPadding: 10
    topPadding: 7
    bottomPadding: 7
    implicitWidth: Math.min(320, label.implicitWidth + leftPadding + rightPadding)
    implicitHeight: label.implicitHeight + topPadding + bottomPadding

    contentItem: Text {
        id: label
        text: root.text
        color: root.shellTheme.textLight
        font.family: root.shellTheme.font
        font.pixelSize: 9
        wrapMode: Text.WordWrap
        maximumLineCount: 4
    }

    background: Rectangle {
        radius: Math.max(5, Number(root.shellTheme.elementRadius) - 2)
        color: root.shellTheme.bgAlt
        border.width: 1
        border.color: root.shellTheme.rune
        gradient: Gradient {
            GradientStop { position: 0; color: root.shellTheme.surfaceTop }
            GradientStop { position: 1; color: root.shellTheme.surfaceBottom }
        }
        Rectangle {
            x: 8; y: 0; width: 24; height: 2; radius: 1
            color: root.shellTheme.accentGlow
            opacity: GlobalState.config.appearance.glow ? 0.82 : 0.38
        }
    }
}
