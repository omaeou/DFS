pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../features/shared"

// A single host-metrics poll is shared by all connected displays.
Singleton {
    id: service

    property string cpuText: "--%"
    property string memText: "--MB"
    property string tempText: "--°C"
    property string gpuText: "--%"
    readonly property var settings: GlobalState.config.modules.SystemInfo || ({})

    function readMetrics(output) {
        const fields = String(output || "").trim().split("|")
        if (fields.length < 4)
            return
        cpuText = fields[0]
        memText = fields[1]
        tempText = fields[2]
        gpuText = fields[3]
    }

    Process {
        id: metricsProcess
        command: [
            "sh", "-c",
            "cpu=$(top -bn1 | awk '/Cpu\\(s\\)/ {print int(100 - $8); exit}'); " +
            "ram=$(free -m | awk 'NR==2{printf \"%.1f/%.1fGB\", $3/1024, $2/1024}'); " +
            "temp=$(sensors 2>/dev/null | awk '/Package id 0:/ {print int($4); exit}'); " +
            "[ -z \"$temp\" ] && temp=$(awk '{print int($1/1000)}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null); " +
            "gpu=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null | awk -F', ' 'NR==1 {print $1\"% \"$2\"°C\"}'); " +
            "printf '%s|%s|%s|%s\\n' \"${cpu:-N/A}%\" \"${ram:-N/A}\" \"${temp:-N/A}°C\" \"${gpu:-N/A}\""
        ]
        environment: ({"LC_ALL": "C"})
        stdout: StdioCollector { onStreamFinished: service.readMetrics(text) }
    }

    Timer {
        interval: Math.max(1000, Math.min(60000, Number(service.settings.refreshInterval) || 3000))
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!metricsProcess.running) metricsProcess.running = true
    }
}
