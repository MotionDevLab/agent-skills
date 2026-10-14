$ErrorActionPreference = "Stop"
# lint-repo.ps1 -- asserts required repo layout for MotionDevLab/agent-skills.
# ASCII-only by design: must parse cleanly under Windows PowerShell 5.1 without a BOM.
# Task-1-owned files are hard FAIL; skill payloads owned by later tasks are WARN-only.
# Usage: powershell -File scripts\lint-repo.ps1

$repoRoot = Split-Path -Parent $PSScriptRoot

$required = @(
  "README.md",
  "LICENSE",
  "skill.json",
  "templates\new-skill\SKILL.md",
  "templates\new-skill\skill.json"
)

$warnOnly = @(
  "skills\laya\SKILL.md",
  "skills\jev\SKILL.md"
)

$failed = $false

foreach ($rel in $required) {
  $full = Join-Path $repoRoot $rel
  if (Test-Path -LiteralPath $full) {
    Write-Output "OK    $rel"
  } else {
    Write-Output "FAIL  $rel -- missing"
    $failed = $true
  }
}

foreach ($rel in $warnOnly) {
  $full = Join-Path $repoRoot $rel
  if (Test-Path -LiteralPath $full) {
    Write-Output "OK    $rel"
  } else {
    Write-Output "WARN  $rel -- missing (owned by a later task, not blocking)"
  }
}

if ($failed) {
  Write-Output "RESULT: FAIL"
  exit 1
}

Write-Output "RESULT: PASS"
exit 0
