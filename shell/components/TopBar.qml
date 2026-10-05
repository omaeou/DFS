import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

PanelWindow {
    id: topBarRoot

    property string workspaceRuneText: "1"
    property string activeEntityText: "Void"

    anchors.top: true
    anchors.left: true
    anchors.right: true
    height: 48
    color: "transparent"

    // Общий контейнер, чтобы развести островки по краям экрана
    Item {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        anchors.topMargin: 5
        anchors.bottomMargin: 5

        // ==========================================
        // ЛЕВАЯ КАПСУЛА (Меню, CPU/Temp, Активное окно)
        // ==========================================
        Rectangle {
            id: leftCapsule
            height: parent.height
            width: leftLayout.implicitWidth + 30
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            radius: 8
            color: Qt.rgba(0, 0, 0)
            border.color: '#8a0303'
            border.width: 1

            RowLayout {
                id: leftLayout
                anchors.centerIn: parent
                spacing: 15

                // Кнопка меню
                Text { 
                    text: "󰣇" 
                    color: "#8a0303"; font.pixelSize: 20; font.family: "JetBrainsMono Nerd Font" 
                }

                // Метрики (заглушка)
                Text { 
                    text: " 15% |  45°C" 
                    color: "#aaaaaa"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                }

                Rectangle { width: 1; height: 14; color: "#333333" }

                // Активное окно
                Text {
                    text: topBarRoot.activeEntityText
                    color: '#d4af37'
                    font.family: "JetBrainsMono Nerd Font"
                    font.bold: true
                    font.pixelSize: 12
                    Layout.maximumWidth: 250
                    elide: Text.ElideRight
                }
            }
        }

        // ==========================================
        // ЦЕНТРАЛЬНАЯ КАПСУЛА (Воркспейсы, Часы, Плеер)
        // ==========================================
        Rectangle {
            id: centerCapsule
            height: parent.height
            width: centerLayout.implicitWidth + 30
            anchors.centerIn: parent
            radius: 8
            color: Qt.rgba(0, 0, 0)
            border.color: '#8a0303'
            border.width: 1

            RowLayout {
                id: centerLayout
                anchors.centerIn: parent
                spacing: 20

                // Воркспейсы
                Text { 
                    text: "Realm: " + topBarRoot.workspaceRuneText
                    color: "#d4af37"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true 
                }

                Rectangle { width: 1; height: 14; color: "#333333" }

                // Часы (живые QML-таймер)
                Text { 
                    id: clockText
                    color: "#ffffff"; font.family: "JetBrainsMono Nerd Font"; font.bold: true; font.pixelSize: 13
                    
                    Timer {
                        interval: 1000; running: true; repeat: true; triggeredOnStart: true
                        onTriggered: {
                            let d = new Date()
                            // Формат: Mon 05 Oct 05:44
                            let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                            let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
                            let dayName = days[d.getDay()]
                            let dayNum = ("0" + d.getDate()).slice(-2)
                            let monthName = months[d.getMonth()]
                            let timeStr = d.toTimeString().split(" ")[0].slice(0,5)
                            clockText.text = dayName + " " + dayNum + " " + monthName + "  " + timeStr
                        }
                    }
                }

                Rectangle { width: 1; height: 14; color: "#333333" }

                // Плеер
                RowLayout {
                    spacing: 6
                    Text { text: ""; color: "#8a0303"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }
                    Text { 
                        text: "Artist - Song Name" 
                        color: "#aaaaaa"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                        elide: Text.ElideRight; Layout.maximumWidth: 140 
                    }
                }
            }
        }

        // ==========================================
        // ПРАВАЯ КАПСУЛА (Трей, Сеть, Звук, Питание)
        // ==========================================
        Rectangle {
            id: rightCapsule
            height: parent.height
            width: rightLayout.implicitWidth + 30
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            radius: 8
            color: Qt.rgba(0, 0, 0)
            border.color: '#8a0303'
            border.width: 1

            RowLayout {
                id: rightLayout
                anchors.centerIn: parent
                spacing: 12

                // Трей
                Text { text: ""; color: "#aaaaaa"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }

                Rectangle { width: 1; height: 14; color: "#333333" }

                // VPN, Сеть, Bluetooth
                Text { text: "󰦄"; color: "#aaaaaa"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 } 
                Text { text: "󰤨"; color: "#aaaaaa"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 } 
                Text { text: "󰂯"; color: "#aaaaaa"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 } 

                Rectangle { width: 1; height: 14; color: "#333333" }

                // Звук и Яркость
                Text { text: " 75%"; color: "#aaaaaa"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
                Text { text: "󰃠 100%"; color: "#aaaaaa"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }

                Rectangle { width: 1; height: 14; color: "#333333" }

                // Уведомления
                Text { text: "󰂚 3"; color: "#aaaaaa"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13 }

                // Кнопка питания
                Text { text: ""; color: "#8a0303"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 16 }
            }
        }
    }
}