# <pecofence.type>streamable</pecofence.type>
# PecoFence PC Status: real-time CPU, RAM, Network and Disk monitoring.
# Click the 'Memory used' row to toggle breakdown of user applications with 1-click close.

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
$ip = 'looking'
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

  "CPU $cpu% | color=$cpuColor icon=🧠"

  # Clickable Memory row: toggles application breakdown
  $showApps = Test-Path $flag
  $memTooltip = if ($showApps) { "Click to collapse application breakdown" } else { "Click to see open applications" }
  "Memory used $usedGB / $totalGB GB ($mem%) $(if ($showApps) { '▼' } else { '▶' }) | run=toggle_res.cmd color=$memColor icon=📊 tooltip=""$memTooltip"""

  if ($showApps) {
    "---"
    "【Running Applications (Click ❌ to Close)】 | color=yellow icon=📱"

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

    $topApps = $appMetrics | Sort-Object MemMB -Descending | Select-Object -First 6
    foreach ($app in $topApps) {
      $color = if ($app.MemMB -gt 400 -or $app.CpuPct -gt 15) { 'orange' } else { 'gray' }
      "  $($app.Title) ($($app.MemMB)MB$(if ($app.CpuPct -gt 0) { " CPU:$($app.CpuPct)%" })) | run=killapp.cmd $($app.Pid) color=$color icon=❌ tooltip=Click to terminate this app"
    }
  }

  "---"
  if ($ip -eq 'looking') {
    "IP address: looking it up… | color=gray icon=📋"
  } elseif ($ip) {
    "IP address $ip | copy=$ip icon=📋 tooltip=""Click to copy"""
  } else {
    "IP address: not connected | color=gray icon=📋"
  }
  "Open Task Manager | run=taskmgr.exe icon=📈"

  "---"
  $disks = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType = 2 OR DriveType = 3 OR DriveType = 6' |
    Where-Object { $_.Size -gt 0 } |
    Sort-Object DeviceID

  foreach ($disk in $disks) {
    $free = [int]($disk.FreeSpace / 1GB)
    $pct = [int]($disk.FreeSpace * 100 / $disk.Size)
    "$($disk.DeviceID) free $free GB ($pct%) | open=$($disk.DeviceID)\ color=$(if ($pct -lt 10) { 'red' } else { 'green' }) icon=💽"
  }

  $prevTime = $now
  "~~~"
  Start-Sleep -Seconds 2
}
