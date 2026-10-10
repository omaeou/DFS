import QtQuick
import QtQuick.Layouts
import "../../features/shared"

Rectangle {
    id: root

    default property alias content: layout.data
    property int spacing: 10
    readonly property var theme: GlobalState.effectiveTheme || ({ bg: "#0c0a0e", bgAlt: "#19171c", frame: "#594149", border: "#3b3037", rune: "#c5a47d", accent: "#8a1728", accentActive: "#ff334f", accentGlow: "#ff6579", textMain: "#d7cdd0", textLight: "#fff5f4", textDark: "#7d7179", font: "JetBrainsMono Nerd Font", elementRadius: 8 })

    implicitHeight: Math.max(36, layout.implicitHeight + 14)
    implicitWidth: layout.implicitWidth + 26
    height: implicitHeight
    width: implicitWidth
    radius: Math.max(6, Number(theme.elementRadius) || 8)
    color: theme.bg
    border.color: theme.frame || theme.border
    border.width: 1
    antialiasing: true

    gradient: Gradient {
        GradientStop { position: 0.0; color: theme.surfaceTop || "#26191e" }
        GradientStop { position: 0.48; color: theme.bgAlt || "#19171c" }
        GradientStop { position: 1.0; color: theme.surfaceBottom || theme.bg || "#0c0a0e" }
    }

    // The capsule uses static, lightweight engraving. No blurred shadows or
    // per-frame drawing: the effect is inexpensive even with several panels.
    data: [
        Rectangle {
            anchors.fill: root
            anchors.margins: 3
            radius: Math.max(3, root.radius - 3)
            color: "transparent"
            border.width: GlobalState.ornamentsEnabled ? 1 : 0
            border.color: root.theme.rune || root.theme.frame
            opacity: 0.23
        },
        Rectangle {
            id: sigilLine
            x: 10; y: 0; width: 27; height: 2; radius: 1
            visible: GlobalState.ornamentsEnabled
            color: GlobalState.config.appearance.glow ? (root.theme.accentGlow || root.theme.accentActive) : (root.theme.rune || root.theme.accent)
            opacity: 0.62
            SequentialAnimation on opacity {
                running: GlobalState.idleEffectsEnabled && root.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.28; duration: GlobalState.animationDuration(1700); easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.78; duration: GlobalState.animationDuration(1700); easing.type: Easing.InOutSine }
            }
        },
        Rectangle {
            x: 10; y: root.height - 2; width: 12; height: 1
            visible: GlobalState.ornamentsEnabled
            color: root.theme.rune || root.theme.accent
            opacity: 0.72
        },
        Rectangle {
            x: root.width - 22; y: root.height - 2; width: 12; height: 1
            visible: GlobalState.ornamentsEnabled
            color: root.theme.rune || root.theme.accent
            opacity: 0.72
        },
        Rectangle {
            x: 7; y: 6; width: 4; height: 4; radius: 0.5; rotation: 45
            visible: GlobalState.ornamentsEnabled
            color: root.theme.rune || root.theme.accent
            opacity: 0.85
        },
        Rectangle {
            x: root.width - 11; y: 6; width: 4; height: 4; radius: 0.5; rotation: 45
            visible: GlobalState.ornamentsEnabled
            color: root.theme.rune || root.theme.accent
            opacity: 0.85
        },
        Rectangle { x: 10; y: 7; width: 8; height: 1; visible: GlobalState.ornamentsEnabled; color: root.theme.rune; opacity: 0.55 },
        Rectangle { x: 10; y: 7; width: 1; height: 5; visible: GlobalState.ornamentsEnabled; color: root.theme.rune; opacity: 0.55 },
        Rectangle { x: root.width - 18; y: 7; width: 8; height: 1; visible: GlobalState.ornamentsEnabled; color: root.theme.rune; opacity: 0.55 },
        Rectangle { x: root.width - 11; y: 7; width: 1; height: 5; visible: GlobalState.ornamentsEnabled; color: root.theme.rune; opacity: 0.55 },
        Rectangle { x: 10; y: root.height - 12; width: 1; height: 5; visible: GlobalState.ornamentsEnabled; color: root.theme.rune; opacity: 0.42 },
        Rectangle { x: 10; y: root.height - 8; width: 8; height: 1; visible: GlobalState.ornamentsEnabled; color: root.theme.rune; opacity: 0.42 },
        Rectangle { x: root.width - 11; y: root.height - 12; width: 1; height: 5; visible: GlobalState.ornamentsEnabled; color: root.theme.rune; opacity: 0.42 },
        Rectangle { x: root.width - 18; y: root.height - 8; width: 8; height: 1; visible: GlobalState.ornamentsEnabled; color: root.theme.rune; opacity: 0.42 },
        Text {
            anchors.horizontalCenter: root.horizontalCenter
            y: 1
            visible: GlobalState.ornamentsEnabled && root.width > 120
            text: "ᛉ"
            color: root.theme.rune || root.theme.accent
            font.family: root.theme.font
            font.pixelSize: 8
            opacity: 0.9
        }
    ]

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: 13
        anchors.rightMargin: 13
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        spacing: root.spacing
        z: 1
    }
}
