#!/usr/bin/env python3
import pathlib
import re
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch_source.py <renderdoc-source-root>")

root = pathlib.Path(sys.argv[1])
path = root / "qrenderdoc" / "Windows" / "MainWindow.cpp"
text = path.read_text(encoding="utf-8")

pattern = re.compile(
    r'''  if\(RENDERDOC_STABLE_BUILD\)\n'''
    r'''    text \+= lit\(FULL_VERSION_STRING\);\n'''
    r'''  else\n'''
    r'''    text \+= tr\("Unstable %1 Build \(%2 - %3\)"\)\n'''
    r'''\s+\.arg\(RENDERDOC_IsReleaseBuild\(\) \? lit\("Release"\) : lit\("Development"\)\)\n'''
    r'''\s+\.arg\(lit\(FULL_VERSION_STRING\)\)\n'''
    r'''\s+\.arg\(QString::fromLatin1\(RENDERDOC_GetCommitHash\(\)\)\);'''
)

replacement = '''  if(RENDERDOC_STABLE_BUILD)
    text += lit(FULL_VERSION_STRING);
  else
    text += tr("%1 (Personal ARM64 Build)").arg(lit(FULL_VERSION_STRING));'''

patched, count = pattern.subn(replacement, text, count=1)
if count != 1:
    raise SystemExit(
        "Could not patch RenderDoc title bar. Upstream title code changed; "
        "update packaging/arm64/patch_source.py for this tag."
    )

path.write_text(patched, encoding="utf-8")
print(f"Patched personal ARM64 title in {path}")
