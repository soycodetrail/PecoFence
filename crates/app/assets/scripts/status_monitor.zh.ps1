# <pecofence.type>streamable</pecofence.type>
# PecoFence 综合系统状态与应用资源监控栅栏（支持点击下钻与一键杀进程）

$flag = "$env:TEMP\pecofence_res_mode.flag"
$cores = [System.Environment]::ProcessorCount
$prevCpu = @{}
$prevTime = [System.DateTime]::UtcNow

while ($true) {
    $now = [System.DateTime]::UtcNow
    $dt = ($now - $prevTime).TotalSeconds
    if ($dt -lt 0.5) { $dt = 1.0 }

    $isDetailMode = Test-Path $flag

    if (-not $isDetailMode) {
        # ======== 模式 1：系统总体概览 (Overview) ========
        $cpu = [int](Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
        $os = Get-CimInstance Win32_OperatingSystem
        $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
        $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
        $usedGB = [math]::Round($totalGB - $freeGB, 1)
        $memPct = [int](100 - ($os.FreePhysicalMemory * 100 / $os.TotalVisibleMemorySize))

        $cpuColor = if ($cpu -gt 80) { 'red' } elseif ($cpu -gt 50) { 'orange' } else { 'green' }
        $memColor = if ($memPct -gt 85) { 'red' } elseif ($memPct -gt 70) { 'orange' } else { 'green' }

        "系统总体 CPU：$cpu% | color=$cpuColor icon=🧠"
        "总体内存已用：$usedGB / $totalGB GB ($memPct%) | color=$memColor icon=📊"
        "---"
        "▶ 点击查看每个应用内存/CPU占用 | run=toggle_res.cmd color=cyan icon=🔍 tooltip=点击展开各应用详情"
        "打开任务管理器 | run=taskmgr.exe icon=📈"
    } else {
        # ======== 模式 2：用户打开的应用资源排行 (User App Breakdown) ========
        "【用户应用资源排行】 | color=yellow icon=📱"
        "◀ 点击返回系统概览 | run=toggle_res.cmd color=cyan icon=↩ tooltip=点击折叠回总览"
        "---"

        # 仅取具有活动窗口的用户态应用（排除后台系统驱动与静默服务）
        $rawProcs = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -ne '' }
        $currentSession = [System.Diagnostics.Process]::GetCurrentProcess().SessionId

        $appMetrics = @()
        foreach ($p in $rawProcs) {
            # 过滤会话，跳过资源管理器与 PecoFence 自身避免误关
            if ($p.SessionId -ne $currentSession -or $p.ProcessName -in @('explorer', 'PecoFence', 'Taskmgr')) {
                continue
            }

            $pidNum = $p.Id
            $memMB = [math]::Round($p.WorkingSet64 / 1MB, 1)
            $totalSec = $p.TotalProcessorTime.TotalSeconds

            $cpuPct = 0.0
            if ($prevCpu.ContainsKey($pidNum)) {
                $dSec = [math]::Max(0.0, ($totalSec - $prevCpu[$pidNum]))
                $cpuPct = [math]::Round(($dSec / ($dt * $cores)) * 100, 1)
            }
            $prevCpu[$pidNum] = $totalSec

            $title = $p.MainWindowTitle.Trim()
            if ($title.Length -gt 16) { $title = $title.Substring(0, 14) + ".." }

            $appMetrics += [PSCustomObject]@{
                Pid = $pidNum
                Name = $p.ProcessName
                Title = $title
                MemMB = $memMB
                CpuPct = $cpuPct
            }
        }

        # 按内存消耗从高到低排序，显示 Top 8
        $topApps = $appMetrics | Sort-Object MemMB -Descending | Select-Object -First 8
        foreach ($app in $topApps) {
            $tagColor = if ($app.MemMB -gt 400 -or $app.CpuPct -gt 15) { 'orange' } else { 'gray' }
            "$($app.Title) | $($app.MemMB)MB $(if ($app.CpuPct -gt 0) { "CPU:$($app.CpuPct)%" }) | run=killapp.cmd $($app.Pid) color=$tagColor icon=❌ tooltip=点击完全关闭此应用"
        }
    }

    $prevTime = $now
    "~~~"
    Start-Sleep -Seconds 3
}
