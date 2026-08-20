pragma Singleton
pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Polled resource usage service with RAM, Swap, CPU, Disk and GPU usage/temps.
 */
Singleton {
    id: root
    property real memoryTotal: 1
    property real memoryFree: 0
    property real memoryUsed: memoryTotal - memoryFree
    property real memoryUsedPercentage: memoryUsed / memoryTotal
    property real swapTotal: 1
    property real swapFree: 0
    property real swapUsed: swapTotal - swapFree
    property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property real cpuUsage: 0
    property var previousCpuStats

    property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)
    property string maxAvailableSwapString: kbToGbString(ResourceUsage.swapTotal)
    property string maxAvailableCpuString: "--"

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60
    property list<real> cpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    property real cpuTemp: 0

    property real diskTotal: 1
    property real diskUsed: 0
    property real diskFree: 0
    property real diskUsedPercentage: diskTotal > 0 ? diskUsed / diskTotal : 0
    property list<real> diskUsageHistory: []
    property string maxAvailableDiskString: kbToGbString(diskTotal)

    property real gpuTemp: 0
    property real gpuUsage: 0
    property real vramTotal: 1
    property real vramUsed: 0
    property real vramUsedPercentage: vramTotal > 0 ? vramUsed / vramTotal : 0
    property list<real> gpuUsageHistory: []
    property list<real> vramUsageHistory: []
    property string maxAvailableVramString: kbToGbString(vramTotal)

    property string gpuVendor: ""

    Process {
        id: tempProc
        command: ["bash", "-c", "sensors 2>/dev/null | grep -E 'Package id 0|Tctl|Tdie' | grep -oP '\\+\\K[0-9.]+(?=°C)' | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.cpuTemp = parseFloat(text.trim()) || 0
            }
        }
    }

    Process {
        id: diskProc
        command: ["bash", "-c", "df -k / | awk 'NR==2{print $2,$3,$4}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = root.parseDf(text)
                if (parsed) {
                    root.diskTotal = parsed.diskTotal
                    root.diskUsed  = parsed.diskUsed
                    root.diskFree  = parsed.diskFree
                }
            }
        }
    }

    Process {
        id: gpuDetectProc
        running: true
        command: ["bash", "-c", "if command -v nvidia-smi >/dev/null 2>&1; then echo nvidia; elif ls /sys/class/drm/card*/device/gpu_busy_percent >/dev/null 2>&1; then echo amd; elif ls /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input >/dev/null 2>&1; then echo intel; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.gpuVendor = text.trim()
            }
        }
    }

    Process {
        id: gpuProc
        command: ["bash", "-c", "nvidia-smi --query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = root.parseNvidiaSmi(text)
                if (parsed) {
                    root.gpuTemp   = parsed.gpuTemp
                    root.gpuUsage  = parsed.gpuUsage
                    root.vramUsed  = parsed.vramUsed
                    root.vramTotal = parsed.vramTotal
                }
            }
        }
    }

    Process {
        id: gpuFallbackProc
        command: ["bash", "-c", "for d in /sys/class/drm/card*/device; do [ -d \"$d\" ] || continue; busy=$(cat \"$d/gpu_busy_percent\" 2>/dev/null); temp=$(cat \"$d\"/hwmon/hwmon*/temp1_input 2>/dev/null | head -1); vu=$(cat \"$d/mem_info_vram_used\" 2>/dev/null); vt=$(cat \"$d/mem_info_vram_total\" 2>/dev/null); if [ -n \"$busy\" ] || [ -n \"$temp\" ]; then echo \"${busy:-0} ${temp:-0} ${vu:-0} ${vt:-0}\"; break; fi; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parsed = root.parseAmdGpu(text)
                if (parsed) {
                    root.gpuTemp   = parsed.gpuTemp
                    root.gpuUsage  = parsed.gpuUsage
                    root.vramUsed  = parsed.vramUsed
                    root.vramTotal = parsed.vramTotal
                }
            }
        }
    }

    Timer {
        id: diskTimer
        interval: 30000 // Disk storage does not change rapidly; 30s cadence reduces continuous subshell spawns
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            diskProc.running = false
            diskProc.running = true
        }
    }

    Timer {
        interval: Config?.options.resources.updateInterval ?? 3000
        running: true
        repeat: true
        onTriggered: {
            tempProc.running = false
            tempProc.running = true
            if (root.gpuVendor === "nvidia") {
                gpuProc.running = false
                gpuProc.running = true
            } else if (root.gpuVendor === "amd" || root.gpuVendor === "intel") {
                gpuFallbackProc.running = false
                gpuFallbackProc.running = true
            }
        }
    }

    function kbToGbString(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB"
    }

    function parseMeminfo(text) {
        return {
            memoryTotal: Number(text.match(/MemTotal: *(\d+)/)?.[1] ?? 1),
            memoryFree:  Number(text.match(/MemAvailable: *(\d+)/)?.[1] ?? 0),
            swapTotal:   Number(text.match(/SwapTotal: *(\d+)/)?.[1] ?? 1),
            swapFree:    Number(text.match(/SwapFree: *(\d+)/)?.[1] ?? 0)
        };
    }

    function parseDf(text) {
        const parts = text.trim().split(/\s+/).map(Number)
        if (parts.length >= 3 && !parts.some(isNaN)) {
            return {
                diskTotal: parts[0],
                diskUsed:  parts[1],
                diskFree:  parts[2]
            };
        }
        return null;
    }

    function parseNvidiaSmi(text) {
        const parts = text.trim().split(",").map(s => parseFloat(s.trim()))
        if (parts.length >= 4 && !parts.some(isNaN)) {
            return {
                gpuTemp:   parts[0],
                gpuUsage:  parts[1] / 100,
                vramUsed:  parts[2] * 1024,
                vramTotal: parts[3] * 1024
            };
        }
        return null;
    }

    function parseAmdGpu(text) {
        const parts = text.trim().split(/\s+/).map(s => parseFloat(s))
        if (parts.length < 4 || isNaN(parts[0]) || isNaN(parts[1])) {
            return null;
        }
        const vramUsed  = isNaN(parts[2]) ? 0 : parts[2]
        const vramTotal = (isNaN(parts[3]) || parts[3] <= 0) ? 1024 : parts[3]
        return {
            gpuTemp:   parts[1] / 1000,
            gpuUsage:  parts[0] / 100,
            vramUsed:  vramUsed / 1024,
            vramTotal: vramTotal / 1024
        };
    }

    function pushHistory(list, value) {
        list.push(value);
        if (list.length > historyLength) list.shift();
        return list;
    }

    property bool historyActive: (GlobalStates?.sidebarRightOpen ?? false)

    function updateMemoryUsageHistory() {
        memoryUsageHistory = pushHistory(memoryUsageHistory, memoryUsedPercentage)
    }
    function updateSwapUsageHistory() {
        swapUsageHistory = pushHistory(swapUsageHistory, swapUsedPercentage)
    }
    function updateCpuUsageHistory() {
        cpuUsageHistory = pushHistory(cpuUsageHistory, cpuUsage)
    }
    function updateDiskUsageHistory() {
        diskUsageHistory = pushHistory(diskUsageHistory, diskUsedPercentage)
    }
    function updateGpuUsageHistory() {
        gpuUsageHistory = pushHistory(gpuUsageHistory, gpuUsage)
    }
    function updateVramUsageHistory() {
        vramUsageHistory = pushHistory(vramUsageHistory, vramUsedPercentage)
    }
    function updateHistories() {
        if (!root.historyActive) return;
        updateMemoryUsageHistory()
        updateSwapUsageHistory()
        updateCpuUsageHistory()
        updateDiskUsageHistory()
        updateGpuUsageHistory()
        updateVramUsageHistory()
    }

    Timer {
        interval: 1
        running: true
        repeat: true
        onTriggered: {
            fileMeminfo.reload()
            fileStat.reload()

            const textMeminfo = fileMeminfo.text()
            const parsed = root.parseMeminfo(textMeminfo)
            memoryTotal = parsed.memoryTotal
            memoryFree  = parsed.memoryFree
            swapTotal   = parsed.swapTotal
            swapFree    = parsed.swapFree

            const textStat = fileStat.text()
            const cpuLine  = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle  = stats[3]
                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff  = idle  - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }
                previousCpuStats = { total, idle }
            }

            root.updateHistories()
            interval = Config.options?.resources?.updateInterval ?? 3000
        }
    }

    FileView { id: fileMeminfo; path: "/proc/meminfo" }
    FileView { id: fileStat;    path: "/proc/stat" }

    Process {
        id: findCpuMaxFreqProc
        environment: ({ LANG: "C", LC_ALL: "C" })
        command: ["bash", "-c", "lscpu | grep 'CPU max MHz' | awk '{print $4}'"]
        running: true
        stdout: StdioCollector {
            id: outputCollector
            onStreamFinished: {
                root.maxAvailableCpuString = (parseFloat(outputCollector.text) / 1000).toFixed(0) + " GHz"
            }
        }
    }
}
