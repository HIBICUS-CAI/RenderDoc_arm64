#!/usr/bin/env bash
set -euo pipefail

REPO="HIBICUS-CAI/renderdoc-arm64-build"
RELEASE_TAG="${RENDERDOC_ARM64_RELEASE_TAG:-__RELEASE_TAG__}"
PACKAGE_NAME="renderdoc-linux-arm64.tar.gz"

if [[ "$RELEASE_TAG" == "__RELEASE_TAG__" ]]; then
  latest_url="$(curl -fsSL -o /dev/null -w '%{url_effective}' "https://github.com/${REPO}/releases/latest")"
  RELEASE_TAG="${latest_url##*/}"
fi

PACKAGE_URL="https://github.com/${REPO}/releases/download/${RELEASE_TAG}/${PACKAGE_NAME}"

APP_ROOT="${HOME}/.local/opt/renderdoc-arm64"
BIN_DIR="${HOME}/.local/bin"
DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}"
DESKTOP_FILE="${DATA_DIR}/applications/renderdoc-arm64.desktop"
ICON_FILE="${DATA_DIR}/icons/hicolor/scalable/apps/renderdoc-arm64.svg"
MIME_FILE="${DATA_DIR}/mime/packages/renderdoc-capture.xml"
VULKAN_FILE="${DATA_DIR}/vulkan/implicit_layer.d/renderdoc_capture.json"
STATE_DIR="${DATA_DIR}/renderdoc-arm64"
MANIFEST="${STATE_DIR}/install-manifest.txt"

case "$(uname -m)" in
  aarch64|arm64) ;;
  *)
    echo "Error: this package is for ARM64 Linux only." >&2
    exit 1
    ;;
esac

for cmd in curl tar; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Error: required command not found: $cmd" >&2
    exit 1
  }
done

if pgrep -f "${APP_ROOT}/bin/qrenderdoc" >/dev/null 2>&1; then
  echo "Error: RenderDoc is currently running from ${APP_ROOT}." >&2
  echo "Close it before updating." >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

echo "Installing RenderDoc ARM64 release: ${RELEASE_TAG}"
echo "Downloading package..."
curl -fL --retry 3 --retry-delay 2 -o "${tmpdir}/${PACKAGE_NAME}" "$PACKAGE_URL"

mkdir -p "${tmpdir}/root"
tar -xzf "${tmpdir}/${PACKAGE_NAME}" -C "${tmpdir}/root"

for required in bin/qrenderdoc bin/renderdoccmd lib/librenderdoc.so; do
  if [[ ! -e "${tmpdir}/root/${required}" ]]; then
    echo "Error: package is missing ${required}." >&2
    exit 1
  fi
done

new_root="${APP_ROOT}.new"
old_root="${APP_ROOT}.old"
rm -rf "$new_root" "$old_root"
mkdir -p "$(dirname "$APP_ROOT")"
mv "${tmpdir}/root" "$new_root"

if [[ -e "$APP_ROOT" ]]; then
  mv "$APP_ROOT" "$old_root"
fi
mv "$new_root" "$APP_ROOT"
rm -rf "$old_root"

mkdir -p "$BIN_DIR"
ln -sfn "${APP_ROOT}/bin/qrenderdoc" "${BIN_DIR}/qrenderdoc"
ln -sfn "${APP_ROOT}/bin/renderdoccmd" "${BIN_DIR}/renderdoccmd"

mkdir -p "$(dirname "$DESKTOP_FILE")"
cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Version=1.0
Name=RenderDoc ARM64
Comment=Personal ARM64 build of RenderDoc
GenericName=Graphics Debugger
Exec=${APP_ROOT}/bin/qrenderdoc %f
Icon=renderdoc-arm64
Terminal=false
Type=Application
Categories=Development;Graphics;
Keywords=RenderDoc;Graphics;Vulkan;
StartupNotify=true
MimeType=application/x-renderdoc-capture;
EOF

mkdir -p "$(dirname "$ICON_FILE")"
if [[ -f "${APP_ROOT}/share/renderdoc/renderdoc-logo.svg" ]]; then
  install -m 0644 "${APP_ROOT}/share/renderdoc/renderdoc-logo.svg" "$ICON_FILE"
else
  echo "Warning: application icon was not found in the package." >&2
fi

if [[ -f "${APP_ROOT}/share/mime/packages/renderdoc-capture.xml" ]]; then
  mkdir -p "$(dirname "$MIME_FILE")"
  install -m 0644 "${APP_ROOT}/share/mime/packages/renderdoc-capture.xml" "$MIME_FILE"
fi

QT_QPA_PLATFORM=offscreen "${APP_ROOT}/bin/qrenderdoc" --install_vulkan_layer user

mkdir -p "$STATE_DIR"
cat > "$MANIFEST" <<EOF
D|${APP_ROOT}
L|${BIN_DIR}/qrenderdoc
L|${BIN_DIR}/renderdoccmd
F|${DESKTOP_FILE}
F|${ICON_FILE}
F|${MIME_FILE}
F|${VULKAN_FILE}
EOF

command -v update-desktop-database >/dev/null 2>&1 &&   update-desktop-database "${DATA_DIR}/applications" >/dev/null 2>&1 || true
command -v update-mime-database >/dev/null 2>&1 &&   update-mime-database "${DATA_DIR}/mime" >/dev/null 2>&1 || true
command -v gtk-update-icon-cache >/dev/null 2>&1 &&   gtk-update-icon-cache -f -t "${DATA_DIR}/icons/hicolor" >/dev/null 2>&1 || true

echo
echo "RenderDoc ARM64 ${RELEASE_TAG} installed."
echo "Application: ${APP_ROOT}/bin/qrenderdoc"
echo "Launcher:    GNOME application menu -> RenderDoc ARM64"
echo "Manifest:    ${MANIFEST}"
