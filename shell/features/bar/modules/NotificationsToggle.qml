import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import "../../shared"
import "../../../core/services"
import "."

Item {
    id: root

    implicitWidth: 28
    implicitHeight: 28

    readonly property int notificationCount: NotificationService.history.count
    readonly property string performanceMode: GlobalState.config.appearance.animations || "balanced"
    readonly property real configuredMotion: Math.max(0, Math.min(1.5, Number(GlobalState.config.appearance.motionScale) || 0))
    readonly property real motionAmplitude: {
        if (performanceMode === "off") return 0
        const modeAmplitude = performanceMode === "full" ? 1.0
            : performanceMode === "reduced" ? 0.22 : 0.58
        return modeAmplitude * configuredMotion
    }
    readonly property int flickerDuration: performanceMode === "full" ? 680
        : performanceMode === "reduced" ? 2200 : 1120
    property real flickerPhase: 0

    onNotificationCountChanged: {
        if (root.notificationCount > 0 && root.motionAmplitude > 0) {
            badgeCounter.scale = 1.28
            countPop.restart()
        } else {
            countPop.stop()
            badgeCounter.scale = 1
        }
    }

    BarButtonPlate {
        id: buttonPlate
        anchors.fill: parent
        active: root.notificationCount > 0
        hovered: hit.containsMouse

        Text {
            anchors.centerIn: parent
            text: root.notificationCount > 0 ? "✦" : "♧"
            color: GlobalState.effectiveTheme.rune
            font.family: GlobalState.effectiveTheme.font
            font.pixelSize: 15
        }

        Rectangle {
            x: 14
            y: -2
            width: 14
            height: 15
            radius: 7
            color: GlobalState.effectiveTheme.accentGlow
            opacity: root.notificationCount > 0 ? 0.2 + 0.1 * Math.sin(root.flickerPhase * Math.PI * 2) : 0
            visible: root.notificationCount > 0
        }

        Repeater {
            model: root.performanceMode === "full" ? 2 : (root.performanceMode === "off" ? 0 : 1)
            delegate: Rectangle {
                required property int index
                readonly property real progress: (root.flickerPhase + index * 0.48) % 1
                x: 15 + index * 5 + progress * (index === 0 ? 3 : -2)
                y: 11 - progress * (index === 0 ? 9 : 7)
                width: index === 0 ? 2 : 1.5
                height: width
                radius: width / 2
                color: index === 0 ? GlobalState.effectiveTheme.rune : GlobalState.effectiveTheme.accentGlow
                opacity: root.notificationCount > 0 ? (1 - progress) * root.motionAmplitude : 0
                visible: root.notificationCount > 0 && root.motionAmplitude > 0
            }
        }

        Shape {
            id: flameOuter
            x: 11
            y: -4
            width: 18
            height: 20
            visible: root.notificationCount > 0
            transformOrigin: Item.Bottom
            scale: 0.94 + 0.08 * root.motionAmplitude * Math.sin(root.flickerPhase * Math.PI * 2)
            rotation: Math.sin(root.flickerPhase * Math.PI * 2) * 5 * root.motionAmplitude
            opacity: 0.82 + 0.18 * root.motionAmplitude * Math.abs(Math.sin(root.flickerPhase * Math.PI * 2))

            ShapePath {
                fillColor: GlobalState.effectiveTheme.accent
                strokeColor: GlobalState.effectiveTheme.accentGlow
                strokeWidth: 0.8
                startX: 9; startY: 0
                PathCubic { control1X: 12; control1Y: 4; control2X: 18; control2Y: 6; x: 16; y: 12 }
                PathCubic { control1X: 15; control1Y: 17; control2X: 12; control2Y: 20; x: 9; y: 20 }
                PathCubic { control1X: 4; control1Y: 20; control2X: 1; control2Y: 16; x: 2; y: 12 }
                PathCubic { control1X: 2; control1Y: 8; control2X: 6; control2Y: 7; x: 6; y: 4 }
                PathCubic { control1X: 8; control1Y: 6; control2X: 7; control2Y: 2; x: 9; y: 0 }
            }
        }

        Shape {
            id: flameCore
            x: flameOuter.x + 3
            y: flameOuter.y + 7
            width: 11
            height: 11
            visible: root.notificationCount > 0
            transformOrigin: Item.Bottom
            scale: 0.96 + 0.08 * root.motionAmplitude * Math.sin(root.flickerPhase * Math.PI * 2 + 0.8)

            ShapePath {
                fillColor: GlobalState.effectiveTheme.accentGlow
                strokeColor: "transparent"
                startX: 5.5; startY: 0
                PathCubic { control1X: 8; control1Y: 3; control2X: 10; control2Y: 5; x: 9; y: 8 }
                PathCubic { control1X: 8; control1Y: 10; control2X: 7; control2Y: 11; x: 5.5; y: 11 }
                PathCubic { control1X: 3; control1Y: 11; control2X: 1; control2Y: 9; x: 2; y: 7 }
                PathCubic { control1X: 2; control1Y: 5; control2X: 5; control2Y: 4; x: 5.5; y: 0 }
            }
        }

        Text {
            id: badgeCounter
            anchors.horizontalCenter: flameOuter.horizontalCenter
            y: flameOuter.y + 7 - 3.2 * root.motionAmplitude * Math.sin(root.flickerPhase * Math.PI * 2 + 0.4)
            width: 17
            height: 11
            visible: root.notificationCount > 0
            text: root.notificationCount > 99 ? "99+" : String(root.notificationCount)
            color: GlobalState.effectiveTheme.bg
            font.family: GlobalState.effectiveTheme.font
            font.pixelSize: root.notificationCount > 9 ? 6 : 8
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            style: Text.Outline
            styleColor: GlobalState.effectiveTheme.accentGlow
            transformOrigin: Item.Center
        }

        NumberAnimation {
            id: flickerAnimation
            target: root
            property: "flickerPhase"
            from: 0
            to: 1
            duration: root.flickerDuration
            loops: Animation.Infinite
            running: root.notificationCount > 0 && root.motionAmplitude > 0
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            id: countPop
            target: badgeCounter
            property: "scale"
            to: 1
            duration: GlobalState.animationDuration(220)
            easing.type: Easing.OutBack
        }

        MouseArea {
            id: hit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: GlobalState.isNotificationsOpen = !GlobalState.isNotificationsOpen
        }

        ThemeToolTip {
            targetItem: hit
            visible: hit.containsMouse
            text: "Открыть уведомления · " + root.notificationCount
        }
    }
}
