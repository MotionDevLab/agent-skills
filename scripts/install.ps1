#Requires -Version 5.1
# install.ps1 -- one-command skill auto-install for MotionDevLab/agent-skills.
# ASCII-only by design: must parse cleanly under Windows PowerShell 5.1 without a BOM.
#
# Examples:
#   irm https://raw.githubusercontent.com/MotionDevLab/agent-skills/main/scripts/install.ps1 | iex
#   powershell -File scripts\install.ps1 -WhatIf
#   powershell -File scripts\install.ps1 -Skills laya -NoModel
#   powershell -File scripts\install.ps1 -Harness claude

param(
  [string]$Skills = "all",
  [string]$Harness = "auto",
  [switch]$NoModel,
  [switch]$WhatIf
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$registryPath = Join-Path $repoRoot "skill.json"

function Fail([string]$message) {
  Write-Output "ERROR: $message"
  exit 2
}

# --- Resolve requested skills against the registry ---------------------------
if (-not (Test-Path -LiteralPath $registryPath)) {
  Fail "registry not found: $registryPath (run from a full repo clone)"
}
try {
  $registry = Get-Content -LiteralPath $registryPath -Raw | ConvertFrom-Json
} catch {
  Fail "cannot parse registry $registryPath : $_"
}
$registered = @{}
foreach ($entry in $registry.skills) {
  $registered[$entry.name] = $entry.path
}

if ($Skills -eq "all") {
  $wanted = @($registered.Keys)
} else {
  $wanted = $Skills -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
}
foreach ($name in $wanted) {
  if (-not $registered.ContainsKey($name)) {
    Fail "unknown skill '$name' (registered: $($registered.Keys -join ', '))"
  }
}

# --- Harness map: name -> skills dir (verified on real machines) --------------
$harnessMap = @{
  "claude"     = Join-Path $HOME ".claude\skills"
  "opencode"   = Join-Path $HOME ".config\opencode\skills"
  "openclaude" = Join-Path $HOME ".openclaude\skills"
}
$harnessMarker = @{
  "claude"     = Join-Path $HOME ".claude"
  "opencode"   = Join-Path $HOME ".config\opencode"
  "openclaude" = Join-Path $HOME ".openclaude"
}

if ($Harness -eq "auto") {
  $targets = @($harnessMap.Keys | Where-Object { Test-Path -LiteralPath $harnessMarker[$_] })
  if ($targets.Count -eq 0) {
    Fail "no harness detected (looked for ~/.claude, ~/.config/opencode, ~/.openclaude). Pass -Harness claude|opencode|openclaude|all to choose explicitly."
  }
} elseif ($Harness -eq "all") {
  $targets = @($harnessMap.Keys)
} elseif ($harnessMap.ContainsKey($Harness)) {
  $targets = @($Harness)
} else {
  Fail "unknown harness '$Harness' (use auto|claude|opencode|openclaude|all)"
}

# --- Python check (guides, never fails silently) ------------------------------
function Test-Python {
  try {
    $out = & python --version 2>&1 | Out-String
  } catch {
    return $false
  }
  $m = [regex]::Match($out, "Python\s+(\d+)\.(\d+)")
  if (-not $m.Success) { return $false }
  $major = [int]$m.Groups[1].Value
  $minor = [int]$m.Groups[2].Value
  return ($major -gt 3) -or ($major -eq 3 -and $minor -ge 10)
}

$needsModel = ($wanted -contains "laya") -and (-not $NoModel) -and (-not $WhatIf)
if ($needsModel -and -not (Test-Python)) {
  Fail "Python 3.10+ is required for the Laya model bootstrap but was not found. Install Python 3.10+, or re-run with -NoModel to install skill files only."
}

# --- WhatIf: print targets, write nothing -------------------------------------
if ($WhatIf) {
  Write-Output "WhatIf: skills requested: $($wanted -join ', ')"
  Write-Output "WhatIf: harness targets:"
  foreach ($h in $targets) {
    Write-Output "WhatIf:   [$h] $($harnessMap[$h])"
    foreach ($name in $wanted) {
      Write-Output "WhatIf:     link skill '$name' -> $(Join-Path $harnessMap[$h] $name)"
    }
  }
  if ($wanted -contains "laya") {
    if ($NoModel) {
      Write-Output "WhatIf: model bootstrap skipped (-NoModel)"
    } else {
      Write-Output "WhatIf: would run laya-setup.py --download --verify"
    }
  }
  exit 0
}

# --- Model bootstrap -----------------------------------------------------------
if ($needsModel) {
  Write-Output "Bootstrapping Laya model (this downloads weights on first run)..."
  $setup = Join-Path $repoRoot "scripts\laya-setup.py"
  & python $setup --download --verify
  if ($LASTEXITCODE -ne 0) {
    Fail "laya-setup.py failed (exit $LASTEXITCODE). Fix the error above, or re-run with -NoModel for skill files only."
  }
}

# --- Link skills ---------------------------------------------------------------
$linked = 0
$skipped = 0
foreach ($h in $targets) {
  $dir = $harnessMap[$h]
  if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  foreach ($name in $wanted) {
    $source = Join-Path $repoRoot $registered[$name]
    if (-not (Test-Path -LiteralPath $source)) {
      Fail "skill source missing: $source"
    }
    $link = Join-Path $dir $name
    if (Test-Path -LiteralPath $link) {
      Write-Output "already-installed: [$h] $name"
      $skipped++
      continue
    }
    try {
      New-Item -ItemType SymbolicLink -Path $link -Target $source | Out-Null
      Write-Output "linked: [$h] $name -> $source"
    } catch {
      Copy-Item -Recurse -Force -LiteralPath $source -Destination $link
      Write-Output "copied (symlink unavailable): [$h] $name -> $source"
    }
    $linked++
  }
}

Write-Output "Done: $linked linked, $skipped already-installed."
exit 0
