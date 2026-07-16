param(
    [string] $ConfigPath = (Join-Path $env:USERPROFILE ".clock-in\config.local.json"),
    [switch] $Uninstall
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config not found: $ConfigPath. Run /clock-in init first."
}

$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Get-Schedules {
    param(
        $Config
    )

    if ($null -ne $Config.schedules) {
        $schedules = @($Config.schedules)
        if ($schedules.Count -eq 0) {
            throw "Missing required config value: schedules"
        }
        return $schedules
    }

    if ($null -ne $Config.schedule) {
        return @($Config.schedule)
    }

    return @([pscustomobject]@{
        taskName = "ClockInDaily"
        startTime = "08:50"
        randomDelayMinutes = 5
        daysOfWeek = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
    })
}

function Get-ScheduleValue {
    param(
        $Schedule,
        [string] $Name,
        $Default
    )

    if ($null -ne $Schedule.$Name -and -not [string]::IsNullOrWhiteSpace([string] $Schedule.$Name)) {
        return $Schedule.$Name
    }

    return $Default
}

function Register-ClockInTask {
    param(
        $Schedule,
        [string] $SkillScript,
        [string] $ConfigPath
    )

    $taskName = Get-ScheduleValue -Schedule $Schedule -Name "taskName" -Default "ClockInDaily"
    $startTime = Get-ScheduleValue -Schedule $Schedule -Name "startTime" -Default "08:50"
    $randomDelayMin = [int] (Get-ScheduleValue -Schedule $Schedule -Name "randomDelayMinutes" -Default 5)
    $daysOfWeek = if ($Schedule.daysOfWeek) { @($Schedule.daysOfWeek) } else { @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday") }

    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($null -ne $existing) {
        Write-Host "Task '$taskName' already exists. Removing old version..."
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }

    Write-Host "Registering scheduled task: $taskName"
    Write-Host "  Time:    $startTime"
    Write-Host "  Days:    $($daysOfWeek -join ', ')"
    Write-Host "  Jitter:  $randomDelayMin min"
    Write-Host "  Action:  powershell -> $SkillScript"

    $arg = "-NoProfile -ExecutionPolicy Bypass -File `"$SkillScript`" -ConfigPath `"$ConfigPath`""

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arg
    $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $daysOfWeek -At $startTime -RandomDelay (New-TimeSpan -Minutes $randomDelayMin)
    $settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 10)

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Auto-launch DingTalk via ADB (clock-in skill)" -Force | Out-Null

    Write-Host ""
    Write-Host "Done. Verify with:"
    Write-Host "  Get-ScheduledTask -TaskName $taskName"
    Write-Host "  schtasks /run /tn $taskName   # run immediately"
}

function Unregister-ClockInTask {
    param(
        $Schedule
    )

    $taskName = Get-ScheduleValue -Schedule $Schedule -Name "taskName" -Default "ClockInDaily"
    Write-Host "Uninstalling scheduled task: $taskName"
    $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if ($null -eq $existing) {
        Write-Host "Task '$taskName' does not exist. Nothing to do."
        return
    }
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Write-Host "Uninstalled."
}

$schedules = @(Get-Schedules -Config $config)
$skillScript = Join-Path $PSScriptRoot "open-dingtalk-and-notify.ps1"
if (-not (Test-Path -LiteralPath $skillScript)) {
    throw "Skill script not found: $skillScript"
}

foreach ($schedule in $schedules) {
    if ($Uninstall) {
        Unregister-ClockInTask -Schedule $schedule
    } else {
        Register-ClockInTask -Schedule $schedule -SkillScript $skillScript -ConfigPath $ConfigPath
    }
}
