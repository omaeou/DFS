import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../shared"
import "../../../core/services"
import "."

Item {
    id: root
    implicitWidth: Math.max(92, Math.min(112, 39 + statusLabel.implicitWidth))
    implicitHeight: 30
    readonly property string activeSsid: ConnectivityService.activeSsid
    readonly property bool wifiEnabled: ConnectivityService.wifiEnabled
    readonly property bool wiredConnected: ConnectivityService.wiredConnected
    readonly property bool connected: activeSsid !== "" || wiredConnected
    readonly property string statusText: activeSsid || (wiredConnected ? "Ethernet" : (wifiEnabled ? "Нет сети" : "Офлайн"))
    readonly property string detailText: "Wi-Fi: " + (activeSsid || (wifiEnabled ? "включён, не подключён" : "выключен")) + "\nEthernet: " + (wiredConnected ? "подключён" : "нет кабеля")

    BarButtonPlate {
        anchors.fill: parent
        active: root.connected
        hovered: hit.containsMouse
        RowLayout {
            anchors.fill: parent; anchors.leftMargin: 7; anchors.rightMargin: 7; spacing: 5
            Text {
                text: root.wiredConnected && !root.activeSsid ? "󰈀" : (root.wifiEnabled ? "" : "󰖪")
                color: root.connected ? GlobalState.effectiveTheme.accentGlow : GlobalState.effectiveTheme.textDark
                font.pixelSize: 14
            }
            Text {
                id: statusLabel
                Layout.fillWidth: true; Layout.minimumWidth: 0
                text: root.statusText
                textFormat: Text.PlainText
                color: root.connected ? GlobalState.effectiveTheme.textMain : GlobalState.effectiveTheme.textDark
                font.family: GlobalState.effectiveTheme.font; font.pixelSize: 8
                elide: Text.ElideRight
            }
            Rectangle {
                Layout.preferredWidth: 6; Layout.preferredHeight: 6; radius: 3
                color: root.connected ? GlobalState.effectiveTheme.accentActive : GlobalState.effectiveTheme.textDark
            }
        }
        MouseArea {
            id: hit; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: GlobalState.toggleNetworkPortal()
        }
        ThemeToolTip { targetItem: hit; visible: hit.containsMouse; text: root.detailText + "\n" + (GlobalState.isControlPanelOpen && GlobalState.isNetworkPortalOpen ? "Закрыть окно сетей" : "Открыть управление сетями") }
    }
}
