#!/usr/bin/env bash
set -euo pipefail

PREFIX="${1:?usage: build_static_python.sh <install-prefix>}"
PREFIX="$(realpath -m "$PREFIX")"
if [[ "$PREFIX" == / || "$PREFIX" == /usr || "$PREFIX" == /usr/local ]]; then
  echo "Refusing to replace a system prefix: $PREFIX" >&2
  exit 1
fi

PYTHON_VERSION=3.14.7
# SHA-256 published at https://www.python.org/downloads/release/python-3147/
PYTHON_SHA256=3b48dac8fb59f62eaa67ac83c1eb12bda1b7a08406dd286e252c11a66be27f81
CC="${CC:-gcc-14}"
export CC

workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT
archive="$workdir/Python-${PYTHON_VERSION}.tar.xz"
curl -fL --retry 3 --retry-delay 2 \
  -o "$archive" "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tar.xz"
printf '%s  %s\n' "$PYTHON_SHA256" "$archive" | sha256sum -c -
mkdir "$workdir/source" "$workdir/build"
tar -xf "$archive" --strip-components=1 -C "$workdir/source"

# Always rebuild. Neither the interpreter nor its stdlib comes from apt or
# a previous workflow run. PIC also permits linking the archive into .so files.
rm -rf "$PREFIX"
mkdir -p "$PREFIX"
cd "$workdir/build"
py_cv_module__tkinter=disabled CFLAGS="-O2 -fPIC" "$workdir/source/configure" \
  --prefix="$PREFIX" \
  --disable-shared \
  --with-static-libpython \
  --with-ensurepip=no \
  --disable-test-modules
make -j"${BUILD_JOBS:-$(nproc)}"
make -j"${BUILD_JOBS:-$(nproc)}" altinstall

test -f "$PREFIX/lib/libpython3.14.a"
if find "$PREFIX/lib" -maxdepth 1 -name 'libpython*.so*' -print -quit | grep -q .; then
  echo "ERROR: a shared libpython was produced." >&2
  exit 1
fi
ldd "$PREFIX/bin/python3.14" > "$PREFIX/python-ldd.txt"
if grep -E 'libpython[0-9]|not found' "$PREFIX/python-ldd.txt"; then
  echo "ERROR: static Python has invalid runtime dependencies." >&2
  exit 1
fi

"$PREFIX/bin/python3.14" - <<'PY'
import hashlib
import pyexpat
import ssl
import zlib
import _md5, _sha1, _sha2, _sha3, _blake2, _hmac

pyexpat.ParserCreate().Parse('<root/>', True)
assert zlib.decompress(zlib.compress(b'renderdoc')) == b'renderdoc'
assert _sha2.sha256(b'abc').hexdigest() == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
print('Static Python passed: XML, compression, SSL and HACL hash modules')
PY

mkdir -p "$PREFIX/share/licenses/python"
cp "$workdir/source/LICENSE" "$PREFIX/share/licenses/python/LICENSE"
echo "Static Python ${PYTHON_VERSION} installed to ${PREFIX}"
