#!/usr/bin/env bash
# Renders GSServerList at desktop and both phone sizes to screenshots/server_list_*.png (xvfb-run: --headless draws nothing).
set -euo pipefail
cd "$(dirname "$0")/.."
exec xvfb-run -a godot --path . --resolution 1280x720 --script tools/server_list_shot.gd
