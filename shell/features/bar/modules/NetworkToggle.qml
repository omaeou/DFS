import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Io
import "../../shared"

Item {
    id: root
    implicitWidth: Math.max(92, Math.min(112, 39 + statusLabel.implicitWidth))
    implicitHeight: 30
    property string activeSsid: ""
    property bool wifiEnabled: false
    property bool wiredConnected: false
    readonly property bool connected: activeSsid !== "" || wiredConnected
    readonly property string statusText: activeSsid || (wiredConnected ? "Ethernet" : (wifiEnabled ? "Нет сети" : "Офлайн"))
    readonly property string detailText: "Wi-Fi: " + (activeSsid || (wifiEnabled ? "включён, не подключён" : "выключен")) + "\nEthernet: " + (wiredConnected ? "подключён" : "нет кабеля")

    Timer {
        interval: 3000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { statusProcess.running = false; statusProcess.running = true }
    }
    Process {
        id: statusProcess
        command: ["sh", "-c", "printf '%s|%s|%s\\n' \"$(nmcli -t -f active,ssid dev wifi | awk -F: '$1 ~ /^yes$/ {print substr($0, index($0, \":\") + 1); exit}')\" \"$(nmcli radio wifi)\" \"$(nmcli -t -f TYPE,STATE dev | awk -F: '$1 ~ /ethernet/ && $2 ~ /connected/ {print 1; exit}')\""]
        stdout: SplitParser {
            onRead: data => {
                const values = data.trim().split("|")
                if (values.length < 3) return
                root.activeSsid = values[0]
                root.wifiEnabled = values[1] === "enabled"
                root.wiredConnected = values[2] === "1"
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: 7
        color: hit.containsMouse ? GlobalState.effectiveTheme.bgHover : GlobalState.effectiveTheme.bgAlt
        border.color: hit.containsMouse ? GlobalState.effectiveTheme.accent : GlobalState.effectiveTheme.frame
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
