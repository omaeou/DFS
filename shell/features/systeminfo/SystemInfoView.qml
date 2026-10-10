import QtQuick
import Quickshell
import Quickshell.Io
import "../shared"

Row {
    id: root
    spacing: 12

    property string cpuText: "--%"
    property string memText: "--MB"
    property string tempText: "--°C"
    property string gpuText: "--%"
    readonly property var settings: GlobalState.config.modules.SystemInfo || ({})

    Timer {
        interval: Math.max(500, Number(root.settings.refreshInterval) || 2000)
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: sysProcess.running = true
    }

    Process {
        id: sysProcess
        // Собираем CPU, RAM, температуру и доступную NVIDIA GPU-статистику через разделитель |
        command: [
            "sh", "-c",
            "cpu=$(top -bn1 | grep 'Cpu(s)' | awk '{print int(100 - $8)}'); " +
            "ram=$(free -m | awk 'NR==2{printf \"%.1f/%.1fGB\", $3/1024, $2/1024}'); " +
            "temp=$(sensors 2>/dev/null | awk '/Package id 0:/ {print int($4)}'); " +
            "[ -z \"$temp\" ] && temp=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print int($1/1000)}'); " +
            "gpu=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | awk -F', ' '{print $1\"% \"$2\"°C\"}'); " +
            "echo \"${cpu:-N/A}%|${ram:-N/A}|${temp:-N/A}°C|${gpu:-N/A}\""
        ]

        stdout: SplitParser {
            onRead: data => {
                let parts = data.trim().split("|")
                if (parts.length >= 4) {
                    root.cpuText = parts[0]
                    root.memText = parts[1]
                    root.tempText = parts[2]
                    root.gpuText = parts[3]
                }
            }
        }
    }

    // CPU
    Row {
        visible: root.settings.showCpu !== false
        spacing: 4
        Text { text: ""; color: GlobalState.effectiveTheme.accent; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
        Text { text: root.cpuText; color: GlobalState.effectiveTheme.textMain; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
    }

    // RAM
    Row {
        visible: root.settings.showMemory !== false
        spacing: 4
        Text { text: ""; color: GlobalState.effectiveTheme.accent; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
        Text { text: root.memText; color: GlobalState.effectiveTheme.textMain; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
    }

    // CPU Temp
    Row {
        visible: root.settings.showTemperature !== false
        spacing: 4
        Text { text: ""; color: GlobalState.effectiveTheme.accent; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
        Text { text: root.tempText; color: GlobalState.effectiveTheme.textMain; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
    }

    // GPU (NVIDIA; unavailable on systems without nvidia-smi)
    Row {
        visible: root.settings.showGpu !== false
        spacing: 4
        Text { text: "󰢮"; color: GlobalState.effectiveTheme.accent; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
        Text { text: root.gpuText; color: GlobalState.effectiveTheme.textMain; font.family: GlobalState.effectiveTheme.font; font.pixelSize: 12 }
    }
}