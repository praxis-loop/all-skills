$ErrorActionPreference = "Stop"

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$SkillsRoot = Join-Path $RepoRoot "skills"

function Test-SkillEntry {
    param([string]$Path)
    return (Test-Path (Join-Path $Path "SKILL.md")) -or (Test-Path (Join-Path $Path "skill.md"))
}

function Get-SkillDirs {
    if (-not (Test-Path $SkillsRoot)) {
        return @()
    }

    $items = @()
    foreach ($categoryDir in (Get-ChildItem -Path $SkillsRoot -Directory | Sort-Object Name)) {
        foreach ($skillDir in (Get-ChildItem -Path $categoryDir.FullName -Directory | Sort-Object Name)) {
            if (Test-SkillEntry $skillDir.FullName) {
                $items += [PSCustomObject]@{
                    Display = "$($categoryDir.Name)/$($skillDir.Name)"
                    Category = $categoryDir.Name
                    Name = $skillDir.Name
                    FullName = $skillDir.FullName
                }
            }
        }
    }
    return $items
}

function Get-TargetDir {
    Write-Host ""
    Write-Host "Choose install target:"
    Write-Host "  1) Codex user: ~/.agents/skills"
    Write-Host "  2) Claude Code project: ./.claude/skills"
    Write-Host "  3) Claude Code user: ~/.claude/skills"
    Write-Host "  4) Custom directory"
    $choice = Read-Host "Enter choice [1-4]"

    switch ($choice) {
        "1" { return (Join-Path $HOME ".agents\skills") }
        "2" { return (Join-Path (Get-Location) ".claude\skills") }
        "3" { return (Join-Path $HOME ".claude\skills") }
        "4" {
            $custom = Read-Host "Enter target directory"
            if ([string]::IsNullOrWhiteSpace($custom)) {
                throw "Custom directory cannot be empty"
            }
            if ([System.IO.Path]::IsPathRooted($custom)) {
                return $custom
            }
            return (Join-Path (Get-Location) $custom)
        }
        default { throw "Invalid choice" }
    }
}

function Install-SkillLink {
    param(
        [object]$Skill,
        [string]$TargetDir
    )

    $sourceDir = $Skill.FullName
    $linkPath = Join-Path $TargetDir $Skill.Name

    if (-not (Test-SkillEntry $sourceDir)) {
        Write-Host "Skip: $($Skill.Display) is not a valid skill directory"
        return
    }

    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

    if (Test-Path $linkPath) {
        $item = Get-Item $linkPath -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            Remove-Item $linkPath -Force
        } else {
            Write-Host "Target exists and is not a symlink or junction, skipped: $linkPath"
            Write-Host "Move or remove it manually if you want to replace it."
            return
        }
    }

    try {
        New-Item -ItemType SymbolicLink -Path $linkPath -Target $sourceDir | Out-Null
        Write-Host "Installed symlink: $linkPath -> $sourceDir"
    } catch [System.UnauthorizedAccessException] {
        New-Item -ItemType Junction -Path $linkPath -Target $sourceDir | Out-Null
        Write-Host "Installed junction: $linkPath -> $sourceDir"
    }
}

$skills = @(Get-SkillDirs)
if ($skills.Count -eq 0) {
    throw "No skill directories found. Use skills/<category>/<skill-name>/SKILL.md."
}

Write-Host "Found skills:"
for ($i = 0; $i -lt $skills.Count; $i++) {
    Write-Host ("  {0}) {1}" -f ($i + 1), $skills[$i].Display)
}
Write-Host "  a) Install all"

$selection = Read-Host "Choose skills to install, for example 1,3 or a"
$targetDir = Get-TargetDir

$selected = @()
if ($selection -eq "a" -or $selection -eq "A") {
    $selected = $skills
} else {
    foreach ($part in $selection.Split(',')) {
        $trimmed = $part.Trim()
        if (-not ($trimmed -match '^[0-9]+$')) {
            throw "Invalid choice: $trimmed"
        }
        $idx = [int]$trimmed - 1
        if ($idx -lt 0 -or $idx -ge $skills.Count) {
            throw "Choice out of range: $trimmed"
        }
        $selected += $skills[$idx]
    }
}

Write-Host ""
Write-Host "Install target: $targetDir"
foreach ($skill in $selected) {
    Install-SkillLink -Skill $skill -TargetDir $targetDir
}

Write-Host ""
Write-Host "Done. Restart the target CLI if it does not detect the new skills immediately."
