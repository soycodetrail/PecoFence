# <pecofence.type>streamable</pecofence.type>
# 当前窗口应用列表 | 点击立即关闭
while ($true) {
    $apps = Get-Process | Where-Object { $_.MainWindowTitle -ne '' } | Select-Object Id, MainWindowTitle
    foreach ($app in $apps) {
        $title = $app.MainWindowTitle
        if ($title.Length -gt 25) { $title = $title.Substring(0, 25) + "..." }
        "$title (PID: $($app.Id)) | run=killapp.cmd $($app.Id) icon=❌"
    }
    "~~~"
    Start-Sleep -Seconds 3
}
