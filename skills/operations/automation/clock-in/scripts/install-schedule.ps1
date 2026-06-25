param(
    [string] $ConfigPath = (Join-Path $env:USERPROFILE ".clock-in\config.local.json"),
    [switch] $Uninstall
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config not found: $ConfigPath. Run /clock-in init first."
}

$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

$taskName = if ($config.schedule.taskName) { $config.schedule.taskName } else { "ClockInDaily" }
$startTime = if ($config.schedule.startTime) { $config.schedule.startTime } else { "08:50" }
$randomDelayMin = if ($null -ne $config.schedule.randomDelayMinutes) { [int] $config.schedule.randomDelayMinutes } else { 5 }
$daysOfWeek = if ($config.schedule.daysOfWeek) { @($config.schedule.daysOfWeek) } else { @("Monday","Tuesday","Wednesday","Thursday","Friday") }

$skillScript = Join-Path $PSScriptRoot "open-dingtalk-and-notify.ps1"
if (-not (Test-Path -LiteralPath $skillScript)) {
    throw "Skill script not found: $skillScript"
}

if ($Uninstall) {
    Write-Host "Uninstalling scheduled task: $taskName"
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($null -eq $existing) {
        Write-Host "Task '$taskName' does not exist. Nothing to do."
        return
    }
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Uninstalled."
    return
}

$existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($null -ne $existing) {
    Write-Host "Task '$taskName' already exists. Removing old version..."
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

Write-Host "Registering scheduled task: $taskName"
Write-Host "  Time:    $startTime"
Write-Host "  Days:    $($daysOfWeek -join ', ')"
Write-Host "  Jitter:  $randomDelayMin min"
Write-Host "  Action:  powershell -> $skillScript"

$arg = "-NoProfile -ExecutionPolicy Bypass -File `"$skillScript`" -ConfigPath `"$ConfigPath`""

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arg
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $daysOfWeek -At $startTime -RandomDelay (New-TimeSpan -Minutes $randomDelayMin)
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Auto-launch DingTalk via ADB (clock-in skill)" -Force | Out-Null

Write-Host ""
Write-Host "Done. Verify with:"
Write-Host "  Get-ScheduledTask -TaskName $taskName"
Write-Host "  schtasks /run /tn $taskName   # run immediately"
