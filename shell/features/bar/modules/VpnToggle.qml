import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../shared"
import "../../../core/services"
import "."

Item {
    id: root
    implicitWidth: 42
    implicitHeight: 28

    Loader {
        id: pickerLoader
        active: true
        source: Qt.resolvedUrl("VpnPicker.qml")
    }

    function statusDescription() {
        if (VpnService.lastError)
            return "Ошибка VPN: " + VpnService.lastError
        if (VpnService.connectionStatus === "connected")
            return "VPN подключён: " + VpnService.activeProfileName
        if (VpnService.connectionStatus === "connecting")
            return "Подключение VPN: " + VpnService.activeProfileName
        if (VpnService.connectionStatus === "awaitingOtp")
            return "VPN ожидает код двухфакторной проверки"
        if (VpnService.connectionStatus === "disconnecting")
            return "Отключение VPN: " + VpnService.activeProfileName
        return "VPN отключён"
    }

    BarButtonPlate {
        anchors.fill: parent
        active: VpnService.connected || VpnService.connectionStatus === "error"
        hovered: hit.containsMouse

        RowLayout {
            anchors.centerIn: parent
            spacing: 3

            Text {
                text: "VPN"
                color: VpnService.connected ? GlobalState.effectiveTheme.textLight : GlobalState.effectiveTheme.rune
                font.family: GlobalState.effectiveTheme.font
                font.pixelSize: 10
                font.bold: true
            }

            Rectangle {
                Layout.preferredWidth: 5
                Layout.preferredHeight: 5
                radius: 3
                color: VpnService.connectionStatus === "connected" ? "#75d99a"
                    : VpnService.connectionStatus === "error" ? GlobalState.effectiveTheme.accentActive
                    : VpnService.connected ? GlobalState.effectiveTheme.accentGlow
                    : GlobalState.effectiveTheme.textDark
            }
        }

        MouseArea {
            id: hit
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (pickerLoader.item)
                    pickerLoader.item.showFor(root)
            }
        }

        ThemeToolTip {
            targetItem: hit
            visible: hit.containsMouse
            text: root.statusDescription() + "\nОткрыть список профилей"
        }
    }
}
