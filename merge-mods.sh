#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# Robust Logging Function
# Format: [YYYY-MM-DD HH:MM:SS] [LEVEL] Message
# -----------------------------------------------------------------------------
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
}

# -----------------------------------------------------------------------------
# Path Resolution (Dynamic, no hardcoded game directory names)
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_ROOT="$SCRIPT_DIR/.."
MODS_DIR="$SCRIPT_DIR/mods"
OUTPUT_DIR="$SCRIPT_DIR/output"

# Validate that the script is running inside the tarkov-modbuilder folder
if [[ ! -d "$MODS_DIR" ]]; then
    log "ERROR" "Mods directory not found at: $MODS_DIR"
    log "ERROR" "Please ensure this script is executed from the tarkov-modbuilder folder."
    exit 1
fi

log "INFO" "Starting mod build process..."
log "INFO" "Game root detected at: $GAME_ROOT"

# -----------------------------------------------------------------------------
# STEP 1: Create or clear the output directory
# -----------------------------------------------------------------------------
log "INFO" "Step 1: Preparing output directory..."
if [[ -d "$OUTPUT_DIR" ]]; then
    log "INFO" "Output directory exists. Clearing all contents..."
    find "$OUTPUT_DIR" -mindepth 1 -delete
else
    log "INFO" "Creating new output directory..."
    mkdir -p "$OUTPUT_DIR"
fi

# -----------------------------------------------------------------------------
# STEP 2: Merge mod contents into output directory
# -----------------------------------------------------------------------------
log "INFO" "Step 2: Merging mod contents into output directory..."
shopt -s dotglob nullglob

mod_count=0
for mod_dir in "$MODS_DIR"/*/; do
    # Ensure we are only processing directories
    if [[ -d "$mod_dir" ]]; then
        mod_name="$(basename "$mod_dir")"
        log "INFO" "Processing mod: $mod_name"
        cp -a "${mod_dir}"/* "$OUTPUT_DIR"/
        ((mod_count++)) || true
    fi
done
shopt -u dotglob nullglob
log "INFO" "Finished merging $mod_count mod(s) into output."

# -----------------------------------------------------------------------------
# STEP 3: Prepare game root directories
# -----------------------------------------------------------------------------
log "INFO" "Step 3: Preparing game root directories..."
USER_MODS_DIR="$GAME_ROOT/SPT/user/mods"
BEPINEX_PLUGINS_DIR="$GAME_ROOT/BepInEx/plugins"
SPT_PLUGINS_DIR="$BEPINEX_PLUGINS_DIR/spt"

# Handle SPT/user/mods
if [[ -d "$USER_MODS_DIR" ]]; then
    log "INFO" "Purging existing SPT/user/mods directory contents..."
    find "$USER_MODS_DIR" -mindepth 1 -delete
else
    log "INFO" "Creating SPT/user/mods directory..."
    mkdir -p "$USER_MODS_DIR"
fi

# Handle BepInEx/plugins (preserve spt folder)
if [[ -d "$BEPINEX_PLUGINS_DIR" ]]; then
    log "INFO" "Purging existing BepInEx/plugins directory contents (preserving spt folder)..."
    # -mindepth 1 avoids deleting the plugins folder itself
    # -maxdepth 1 ensures we only look at immediate children
    # ! -name "spt" skips the protected folder
    find "$BEPINEX_PLUGINS_DIR" -mindepth 1 -maxdepth 1 ! -name "spt" -exec rm -rf {} +
else
    log "INFO" "Creating BepInEx/plugins directory..."
    mkdir -p "$BEPINEX_PLUGINS_DIR"
fi

# -----------------------------------------------------------------------------
# STEP 4: Merge output contents into game root
# -----------------------------------------------------------------------------
log "INFO" "Step 4: Merging output contents into game root directory..."
shopt -s dotglob nullglob

output_files=("$OUTPUT_DIR"/*)
if [[ ${#output_files[@]} -gt 0 ]]; then
    cp -a "${output_files[@]}" "$GAME_ROOT"/
    log "INFO" "Successfully copied mod files to game root."
else
    log "WARN" "Output directory is empty. Nothing to copy to game root."
fi
shopt -u dotglob nullglob

log "INFO" "Mod build process completed successfully!"
log "INFO" "Final structure applied to: $GAME_ROOT"
exit 0