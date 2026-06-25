param(
    [string] $ConfigPath = (Join-Path $env:USERPROFILE ".clock-in\config.local.json")
)

& (Join-Path $PSScriptRoot "install-schedule.ps1") -ConfigPath $ConfigPath -Uninstall
