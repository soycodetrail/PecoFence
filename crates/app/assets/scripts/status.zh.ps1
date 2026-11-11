# <pecofence.type>streamable</pecofence.type>
# PecoFence 电脑状态栅栏：实时监控系统 CPU、总内存与网络/磁盘状态
# 支持点击「内存已用」就地展开/折叠每个打开的应用与资源消耗，支持点击❌一键关闭应用

$flag = "$env:TEMP\pecofence_app_breakdown.flag"
$cores = [System.Environment]::ProcessorCount
$prevCpu = @{}
$prevTime = [System.DateTime]::UtcNow

$ip = (Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } |
  Select-Object -First 1).IPAddress

while ($true) {
  $now = [System.DateTime]::UtcNow
  $dt = ($now - $prevTime).TotalSeconds
  if ($dt -lt 0.5) { $dt = 1.0 }

  $cpu = [int](Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
  $os = Get-CimInstance Win32_OperatingSystem
  $totalGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
  $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)
  $usedGB = [math]::Round($totalGB - $freeGB, 1)
  $mem = [int](100 - ($os.FreePhysicalMemory * 100 / $os.TotalVisibleMemorySize))

  $cpuColor = if ($cpu -gt 80) { 'red' } elseif ($cpu -gt 50) { 'orange' } else { 'green' }
  $memColor = if ($mem -gt 85) { 'red' } elseif ($mem -gt 70) { 'orange' } else { 'green' }

  "CPU $cpu% | color=$cpuColor icon=🧠"

  $showApps = Test-Path $flag
  $arrow = if ($showApps) { '▼' } else { '▶' }
  $memTip = if ($showApps) { '点击折叠应用明细' } else { '点击查看每个打开的应用' }
  "内存已用 $usedGB / $totalGB GB ($mem%) $arrow | run=toggle_res.cmd refresh=true color=$memColor icon=📊 tooltip=$memTip"

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
      if ($title.Length -gt 15) { $title = $title.Substring(0, 13) + '..' }

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
      $cpuTxt = if ($app.CpuPct -gt 0) { " CPU:$($app.CpuPct)%" } else { "" }
      "  $($app.Title) ($($app.MemMB)MB$cpuTxt) | run=killapp.cmd $($app.Pid) refresh=true color=$color icon=❌ tooltip=点击完全关闭此应用"
    }
  }

  $c = Get-PSDrive C
  $free = [int]($c.Free / 1GB)
  $pct = [int]($c.Free * 100 / ($c.Free + $c.Used))
  "C 盘剩余 $free GB ($pct%) | open=C:\ color=$(if ($pct -lt 10) { 'red' } else { 'green' }) icon=💽"
  "---"
  "本机 IP $ip | copy=$ip icon=📋 tooltip=点一下复制"
  "打开任务管理器 | run=taskmgr.exe icon=📈"

  $prevTime = $now
  "~~~"
  Start-Sleep -Seconds 2
}