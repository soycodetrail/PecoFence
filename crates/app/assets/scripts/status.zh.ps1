# <pecofence.type>streamable</pecofence.type>
# PecoFence 电脑状态栅栏：实时监控系统 CPU、总内存与网络/磁盘状态
# 支持点击「内存已用」展开查看每个打开的应用及资源消耗，支持点击一键关闭应用

function Get-LocalIP {
  Get-NetIPConfiguration |
    Where-Object { $_.NetAdapter.Status -eq 'Up' -and $_.IPv4DefaultGateway } |
    Sort-Object { -not $_.NetAdapter.ConnectorPresent }, { $_.NetIPv4Interface.InterfaceMetric } |
    Select-Object -ExpandProperty IPv4Address |
    Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
    Select-Object -First 1 -ExpandProperty IPAddress
}

$flag = "$env:TEMP\pecofence_app_breakdown.flag"
$cores = [System.Environment]::ProcessorCount
$prevCpu = @{}
$prevTime = [System.DateTime]::UtcNow
$ip = '查找中'
$tick = 0

while ($true) {
  $now = [System.DateTime]::UtcNow
  $dt = ($now - $prevTime).TotalSeconds
  if ($dt -lt 0.5) { $dt = 1.0 }

  if ($tick % 15 -eq 1) { $ip = Get-LocalIP }
  $tick++

  $cpu = [int](Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
  $os = Get-CimInstance Win32_OperatingSystem
  $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
  $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
  $usedGB = [math]::Round($totalGB - $freeGB, 1)
  $mem = [int](100 - $os.FreePhysicalMemory * 100 / $os.TotalVisibleMemorySize)

  $cpuColor = if ($cpu -gt 80) { 'red' } elseif ($cpu -gt 50) { 'orange' } else { 'green' }
  $memColor = if ($mem -gt 85) { 'red' } elseif ($mem -gt 70) { 'orange' } else { 'green' }

  # 系统 CPU 行
  "CPU $cpu% | color=$cpuColor icon=🧠"

  # 统计总内存行：直接绑定点击切换事件！点击即可展开/收起应用明细
  $showApps = Test-Path $flag
  $memTooltip = if ($showApps) { "点击折叠应用明细" } else { "点击展开查看每个打开的应用" }
  "内存已用 $usedGB / $totalGB GB ($mem%) $(if ($showApps) { '▼' } else { '▶' }) | run=toggle_res.cmd color=$memColor icon=📊 tooltip=""$memTooltip"""

  # 展开时：列出用户当前打开的应用（过滤系统服务、后台进程与资源管理器）
  if ($showApps) {
    "---"
    "【正在运行的应用 (点击❌强制关闭)】 | color=yellow icon=📱"

    $rawProcs = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle -ne '' }
    $currentSession = [System.Diagnostics.Process]::GetCurrentProcess().SessionId

    $appMetrics = @()
    foreach ($p in $rawProcs) {
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
      if ($title.Length -gt 15) { $title = $title.Substring(0, 13) + ".." }

      $appMetrics += [PSCustomObject]@{
        Pid = $pidNum
        Title = $title
        MemMB = $memMB
        CpuPct = $cpuPct
      }
    }

    # 按内存大小降序，最多显示 Top 6
    $topApps = $appMetrics | Sort-Object MemMB -Descending | Select-Object -First 6
    foreach ($app in $topApps) {
      $color = if ($app.MemMB -gt 400 -or $app.CpuPct -gt 15) { 'orange' } else { 'gray' }
      "  $($app.Title) ($($app.MemMB)MB$(if ($app.CpuPct -gt 0) { " CPU:$($app.CpuPct)%" })) | run=killapp.cmd $($app.Pid) color=$color icon=❌ tooltip=点击完全关闭此应用"
    }
  }

  "---"
  if ($ip -eq '查找中') {
    "本机 IP：正在查找… | color=gray icon=📋"
  } elseif ($ip) {
    "本机 IP $ip | copy=$ip icon=📋 tooltip=点一下复制"
  } else {
    "本机 IP：没有连接网络 | color=gray icon=📋"
  }
  "打开任务管理器 | run=taskmgr.exe icon=📈"

  # 磁盘驱动器信息
  "---"
  $disks = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 2 OR DriveType = 3 OR DriveType = 6' |
    Where-Object { $_.Size -gt 0 } |
    Sort-Object DeviceID

  foreach ($disk in $disks) {
    $free = [int]($disk.FreeSpace / 1GB)
    $pct = [int]($disk.FreeSpace * 100 / $disk.Size)
    "$($disk.DeviceID.TrimEnd(':')) 盘剩余 $free GB（$pct%） | open=$($disk.DeviceID)\ color=$(if ($pct -lt 10) { 'red' } else { 'green' }) icon=💽"
  }

  $prevTime = $now
  "~~~"
  Start-Sleep -Seconds 2
}
