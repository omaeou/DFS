import QtQuick
import QtQuick.Layouts
import "../shared"
import "../../core/services"

Row {
    id: root
    spacing: 12

    readonly property var settings: GlobalState.config.modules.SystemInfo || ({})

    Row {
        visible: root.settings.showCpu !== false
        spacing: 4
        Text { text: ""; color: GlobalState.effectiveTheme.accent; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
        Text { text: SystemInfoService.cpuText; textFormat: Text.PlainText; color: GlobalState.effectiveTheme.textMain; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
    }

    Row {
        visible: root.settings.showMemory !== false
        spacing: 4
        Text { text: ""; color: GlobalState.effectiveTheme.accent; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
        Text { text: SystemInfoService.memText; textFormat: Text.PlainText; color: GlobalState.effectiveTheme.textMain; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
    }

    Row {
        visible: root.settings.showTemperature !== false
        spacing: 4
        Text { text: ""; color: GlobalState.effectiveTheme.accent; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
        Text { text: SystemInfoService.tempText; textFormat: Text.PlainText; color: GlobalState.effectiveTheme.textMain; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
    }

    Row {
        visible: root.settings.showGpu !== false
        spacing: 4
        Text { text: "󰢮"; color: GlobalState.effectiveTheme.accent; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
        Text { text: SystemInfoService.gpuText; textFormat: Text.PlainText; color: GlobalState.effectiveTheme.textMain; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
    }
}
