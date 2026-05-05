#Requires -Version 5.1
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# --------------------------------------------------------
# Robust Console Logging Function
# Format: [YYYY-MM-DD HH:MM:SS] [LEVEL] Message
# --------------------------------------------------------
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("INFO", "WARN", "ERROR", "DEBUG")]
        [string]$Level,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    switch ($Level) {
        "INFO"    { $Color = "Green" }
        "WARN"    { $Color = "Yellow" }
        "ERROR"   { $Color = "Red" }
        "DEBUG"   { $Color = "Gray" }
    }
    Write-Host "[$Timestamp] [$Level] $Message" -ForegroundColor $Color
}

# --------------------------------------------------------
# Dynamic Path Resolution (No hardcoded game directory names)
# --------------------------------------------------------
$ScriptDir = $PSScriptRoot
$GameRoot  = Split-Path $ScriptDir -Parent
$ModsDir   = Join-Path $ScriptDir "mods"
$OutputDir = Join-Path $ScriptDir "output"

if (-not (Test-Path $ModsDir)) {
    Write-Log "ERROR" "Mods directory not found at: $ModsDir"
    Write-Log "ERROR" "Please ensure this script is executed from the tarkov-modbuilder folder."
    exit 1
}

Write-Log "INFO" "Starting mod build process..."
Write-Log "INFO" "Game root detected at: $GameRoot"

# --------------------------------------------------------
# STEP 1: Create or clear the output directory
# --------------------------------------------------------
Write-Log "INFO" "Step 1: Preparing output directory..."
try {
    if (Test-Path $OutputDir) {
        Write-Log "INFO" "Output directory exists. Clearing all contents..."
        Get-ChildItem -Path $OutputDir -Recurse -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Log "INFO" "Creating new output directory..."
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
} catch {
    Write-Log "ERROR" "Failed to prepare output directory: $_"
    exit 1
}

# --------------------------------------------------------
# STEP 2: Merge mod contents into output directory
# --------------------------------------------------------
Write-Log "INFO" "Step 2: Merging mod contents into output directory..."
$ModCount = 0
$ModDirs  = Get-ChildItem -Path $ModsDir -Directory -ErrorAction SilentlyContinue

if ($ModDirs.Count -eq 0) {
    Write-Log "WARN" "No mod subdirectories found in: $ModsDir"
} else {
    foreach ($Mod in $ModDirs) {
        Write-Log "INFO" "Processing mod: $($Mod.Name)"
        try {
            # Copy contents only, not the mod folder itself
            Copy-Item -Path "$($Mod.FullName)\*" -Destination $OutputDir -Recurse -Force -ErrorAction Stop
            $ModCount++
        } catch {
            Write-Log "WARN" "Failed to merge contents from '$($Mod.Name)': $_"
        }
    }
}
Write-Log "INFO" "Finished merging $ModCount mod(s) into output."

# --------------------------------------------------------
# STEP 3: Prepare game root directories
# --------------------------------------------------------
Write-Log "INFO" "Step 3: Preparing game root directories..."
$UserModsDir      = Join-Path $GameRoot "SPT\user\mods"
$BepInExPluginsDir = Join-Path $GameRoot "BepInEx\plugins"

# Handle SPT/user/mods
try {
    if (Test-Path $UserModsDir) {
        Write-Log "INFO" "Purging existing SPT/user/mods directory contents..."
        Get-ChildItem -Path $UserModsDir -Recurse -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Write-Log "INFO" "Creating SPT/user/mods directory..."
        New-Item -ItemType Directory -Path $UserModsDir -Force | Out-Null
    }
} catch {
    Write-Log "ERROR" "Failed to prepare SPT/user/mods directory: $_"
    exit 1
}

# Handle BepInEx/plugins (preserve spt folder)
try {
    if (Test-Path $BepInExPluginsDir) {
        Write-Log "INFO" "Purging existing BepInEx/plugins directory contents (preserving spt folder)..."
        # Filter out the protected 'spt' directory before removing
        $ItemsToRemove = Get-ChildItem -Path $BepInExPluginsDir -Force -ErrorAction SilentlyContinue |
                         Where-Object { $_.Name -ne "spt" }
        foreach ($Item in $ItemsToRemove) {
            Remove-Item -Path $Item.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    } else {
        Write-Log "INFO" "Creating BepInEx/plugins directory..."
        New-Item -ItemType Directory -Path $BepInExPluginsDir -Force | Out-Null
    }
} catch {
    Write-Log "ERROR" "Failed to prepare BepInEx/plugins directory: $_"
    exit 1
}

# --------------------------------------------------------
# STEP 4: Merge output contents into game root
# --------------------------------------------------------
Write-Log "INFO" "Step 4: Merging output contents into game root directory..."
try {
    $OutputItems = Get-ChildItem -Path $OutputDir -Force -ErrorAction SilentlyContinue
    if ($OutputItems -and $OutputItems.Count -gt 0) {
        foreach ($Item in $OutputItems) {
            try {
                Copy-Item -Path $Item.FullName -Destination $GameRoot -Recurse -Force -ErrorAction Stop
                Write-Log "INFO" "Copied: $($Item.Name)"
            } catch {
                Write-Log "WARN" "Failed to copy '$($Item.Name)' to game root: $_"
            }
        }
        Write-Log "INFO" "Successfully copied mod files to game root."
    } else {
        Write-Log "WARN" "Output directory is empty. Nothing to copy to game root."
    }
} catch {
    Write-Log "ERROR" "Failed to merge output contents into game root: $_"
    exit 1
}

Write-Log "INFO" "Mod build process completed successfully!"
Write-Log "INFO" "Final structure applied to: $GameRoot"
exit 0