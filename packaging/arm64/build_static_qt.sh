#!/usr/bin/env bash
set -euo pipefail

PREFIX="${1:?usage: build_static_qt.sh <install-prefix>}"

QT_VERSION="5.15.17"
BASE_URL="https://download.qt.io/archive/qt/5.15/${QT_VERSION}/submodules"

QTBASE_FILE="qtbase-everywhere-opensource-src-${QT_VERSION}.tar.xz"
QTSVG_FILE="qtsvg-everywhere-opensource-src-${QT_VERSION}.tar.xz"
QTX11_FILE="qtx11extras-everywhere-opensource-src-${QT_VERSION}.tar.xz"

STAMP="${PREFIX}/.renderdoc-static-qt-${QT_VERSION}"

if [[ -f "$STAMP" && -x "${PREFIX}/bin/qmake" ]]; then
  echo "Static Qt ${QT_VERSION} already available at ${PREFIX}"
  exit 0
fi

for cmd in curl tar md5sum make gcc-14 g++-14; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "Missing build command: $cmd" >&2
    exit 1
  }
done

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

curl -fL --retry 3 --retry-delay 2   -o "${workdir}/md5sums.txt"   "${BASE_URL}/md5sums.txt"

download_and_verify() {
  local file="$1"

  curl -fL --retry 3 --retry-delay 2     -o "${workdir}/${file}"     "${BASE_URL}/${file}"

  local checksum
  checksum="$(awk -v f="$file" '$2 == f { print $1 }' "${workdir}/md5sums.txt")"

  if [[ -z "$checksum" ]]; then
    echo "No official Qt checksum found for $file" >&2
    exit 1
  fi

  printf '%s  %s\n' "$checksum" "${workdir}/${file}" | md5sum -c -
}

download_and_verify "$QTBASE_FILE"
download_and_verify "$QTSVG_FILE"
download_and_verify "$QTX11_FILE"

tar -xf "${workdir}/${QTBASE_FILE}" -C "$workdir"
tar -xf "${workdir}/${QTSVG_FILE}" -C "$workdir"
tar -xf "${workdir}/${QTX11_FILE}" -C "$workdir"

rm -rf "$PREFIX"
mkdir -p "$PREFIX"

find_extracted_source() {
  local prefix="$1"
  local dir

  dir="$(find "$workdir" -mindepth 1 -maxdepth 1 -type d -name "${prefix}*${QT_VERSION}*" -print -quit)"

  if [[ -z "$dir" || ! -d "$dir" ]]; then
    echo "Could not find extracted Qt source directory for ${prefix} ${QT_VERSION}" >&2
    echo "Extracted directories:" >&2
    find "$workdir" -mindepth 1 -maxdepth 1 -type d -printf '  %f\n' >&2
    exit 1
  fi

  printf '%s\n' "$dir"
}

qtbase_src="$(find_extracted_source qtbase)"
qtsvg_src="$(find_extracted_source qtsvg)"
qtx11_src="$(find_extracted_source qtx11extras)"

echo "QtBase source:      $qtbase_src"
echo "QtSvg source:       $qtsvg_src"
echo "QtX11Extras source: $qtx11_src"

qtbase_build="${workdir}/qtbase-build"
mkdir -p "$qtbase_build"

pushd "$qtbase_build"
CC=gcc-14 CXX=g++-14 "${qtbase_src}/configure"   -prefix "$PREFIX"   -release   -opensource   -confirm-license   -static   -accessibility   -qt-zlib   -qt-libpng   -qt-libjpeg   -qt-harfbuzz   -qt-pcre   -qt-doubleconversion   -fontconfig   -openssl-runtime   -xcb   -bundled-xcb-xinput   -xkbcommon   -no-opengl   -no-egl   -no-dbus   -no-glib   -no-cups   -no-icu   -no-libproxy   -no-feature-gssapi   -no-sm   -no-libudev   -nomake examples   -nomake tests
make -j"$(nproc)"
make install
popd

build_qt_module() {
  local source_dir="$1"
  local build_dir="$2"

  mkdir -p "$build_dir"
  pushd "$build_dir"
  CC=gcc-14 CXX=g++-14 "${PREFIX}/bin/qmake" "$source_dir"
  make -j"$(nproc)"
  make install
  popd
}

build_qt_module "$qtsvg_src" "${workdir}/qtsvg-build"

build_qt_module "$qtx11_src" "${workdir}/qtx11extras-build"

test -f "${PREFIX}/lib/libQt5Core.a"
test -f "${PREFIX}/lib/libQt5Gui.a"
test -f "${PREFIX}/lib/libQt5Widgets.a"
test -f "${PREFIX}/lib/libQt5Network.a"
test -f "${PREFIX}/lib/libQt5Svg.a"
test -f "${PREFIX}/lib/libQt5X11Extras.a"

printf '%s\n' "$QT_VERSION" > "$STAMP"

echo "Static Qt ${QT_VERSION} installed to ${PREFIX}"
"${PREFIX}/bin/qmake" -v
