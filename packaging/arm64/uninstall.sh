#!/usr/bin/env bash
set -euo pipefail

APP_ROOT="${HOME}/.local/opt/renderdoc-arm64"
BIN_DIR="${HOME}/.local/bin"
DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}"
STATE_DIR="${DATA_DIR}/renderdoc-arm64"
MANIFEST="${STATE_DIR}/install-manifest.txt"

remove_entry() {
  local kind="$1"
  local path="$2"

  case "$kind" in
    F|L)
      rm -f -- "$path"
      ;;
    D)
      if [[ "$path" == "$APP_ROOT" ]]; then
        rm -rf -- "$path"
      fi
      ;;
  esac
}

if [[ -f "$MANIFEST" ]]; then
  while IFS='|' read -r kind path; do
    [[ -n "${kind:-}" && -n "${path:-}" ]] || continue
    remove_entry "$kind" "$path"
  done < "$MANIFEST"
else
  echo "Warning: install manifest not found; removing known RenderDoc ARM64 paths." >&2
  rm -rf -- "$APP_ROOT"
  rm -f --     "${BIN_DIR}/qrenderdoc"     "${BIN_DIR}/renderdoccmd"     "${DATA_DIR}/applications/renderdoc-arm64.desktop"     "${DATA_DIR}/icons/hicolor/scalable/apps/renderdoc-arm64.svg"     "${DATA_DIR}/mime/packages/renderdoc-capture.xml"     "${DATA_DIR}/vulkan/implicit_layer.d/renderdoc_capture.json"
fi

rm -f -- "$MANIFEST"
rmdir -- "$STATE_DIR" 2>/dev/null || true

command -v update-desktop-database >/dev/null 2>&1 &&   update-desktop-database "${DATA_DIR}/applications" >/dev/null 2>&1 || true
command -v update-mime-database >/dev/null 2>&1 &&   update-mime-database "${DATA_DIR}/mime" >/dev/null 2>&1 || true
command -v gtk-update-icon-cache >/dev/null 2>&1 &&   gtk-update-icon-cache -f -t "${DATA_DIR}/icons/hicolor" >/dev/null 2>&1 || true

echo "RenderDoc ARM64 uninstalled."
