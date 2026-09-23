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

# Static Python needs the libraries used by its built-in modules (MODLIBS).
# FindPython's library path alone does not carry those dependencies into
# RenderDoc's generated qmake project. Query the interpreter we actually use.
path = root / "qrenderdoc" / "CMakeLists.txt"
text = path.read_text(encoding="utf-8")
original = '''if(STATIC_QRENDERDOC)
    set(PYTHON_LINK "-rdynamic -Wl,--whole-archive ${PYTHON_LINK} -Wl,--no-whole-archive")
endif()'''
replacement = r'''if(STATIC_QRENDERDOC)
    # Match CPython's own executable link dependencies, including built-ins.
    execute_process(
        COMMAND "${PYTHON_EXECUTABLE}" -I -c
            "import shlex, sysconfig; flags = ' '.join(sysconfig.get_config_var(k) or '' for k in ('LIBS', 'MODLIBS', 'LIBM', 'LIBC')); print(shlex.join(f for f in shlex.split(flags) if f.strip()))"
        RESULT_VARIABLE PYTHON_STATIC_FLAGS_RESULT
        OUTPUT_VARIABLE PYTHON_STATIC_FLAGS
        ERROR_VARIABLE PYTHON_STATIC_FLAGS_ERROR
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(NOT PYTHON_STATIC_FLAGS_RESULT EQUAL 0)
        message(FATAL_ERROR "Could not query static Python dependencies: ${PYTHON_STATIC_FLAGS_ERROR}")
    endif()
    message(STATUS "Static Python dependencies: ${PYTHON_STATIC_FLAGS}")
    separate_arguments(PYTHON_STATIC_LIBS UNIX_COMMAND "${PYTHON_STATIC_FLAGS}")

    # Py_Initialize() alone can discover the runner's python3 via PATH and
    # load its incompatible stdlib. Match qrenderdoc's explicit Python home.
    execute_process(
        COMMAND "${PYTHON_EXECUTABLE}" -I -c "import sys; print(sys.base_prefix)"
        RESULT_VARIABLE PYTHON_STATIC_HOME_RESULT
        OUTPUT_VARIABLE PYTHON_STATIC_HOME
        ERROR_VARIABLE PYTHON_STATIC_HOME_ERROR
        OUTPUT_STRIP_TRAILING_WHITESPACE)
    if(NOT PYTHON_STATIC_HOME_RESULT EQUAL 0 OR NOT IS_DIRECTORY "${PYTHON_STATIC_HOME}")
        message(FATAL_ERROR "Could not query static Python home: ${PYTHON_STATIC_HOME_ERROR}")
    endif()

    # Fail at configure time instead of at the end of the RenderDoc build.
    # Use the same whole-archive linking as qrenderdoc, then exercise its
    # matching XML/compression/hash extension modules.
    file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/check_static_python.c" [=[
#include <Python.h>
int main(int argc, char **argv)
{
    if(argc != 3)
        return 2;
    PyConfig config;
    PyConfig_InitIsolatedConfig(&config);
    config.site_import = 0;
    PyStatus status = PyConfig_SetBytesString(&config, &config.home, argv[1]);
    if(!PyStatus_Exception(status))
        status = PyConfig_SetBytesString(&config, &config.program_name, argv[2]);
    if(!PyStatus_Exception(status))
        status = Py_InitializeFromConfig(&config);
    PyConfig_Clear(&config);
    if(PyStatus_Exception(status))
        Py_ExitStatusException(status);

    int result = PyRun_SimpleString(
        "import sys\n"
        "print('Static Python home:', sys.prefix, flush=True)\n"
        "import pyexpat, zlib, _md5, _sha1, _sha2, _sha3, _blake2, _hmac\n"
        "pyexpat.ParserCreate().Parse('<root/>', True)\n"
        "assert _sha2.sha256(b'abc').hexdigest() == 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'\n"
        "assert zlib.decompress(zlib.compress(b'renderdoc')) == b'renderdoc'\n");
    int finalized = Py_FinalizeEx();
    return result == 0 && finalized == 0 ? 0 : 1;
}
]=])
    try_run(PYTHON_STATIC_RUN_RESULT PYTHON_STATIC_COMPILE_RESULT
        "${CMAKE_CURRENT_BINARY_DIR}/check-static-python"
        "${CMAKE_CURRENT_BINARY_DIR}/check_static_python.c"
        CMAKE_FLAGS "-DINCLUDE_DIRECTORIES:STRING=${PYTHON_INCLUDE_DIR}"
        LINK_LIBRARIES
            -rdynamic -Wl,--whole-archive ${PYTHON_LIBRARY}
            -Wl,--no-whole-archive ${PYTHON_STATIC_LIBS}
        COMPILE_OUTPUT_VARIABLE PYTHON_STATIC_COMPILE_OUTPUT
        RUN_OUTPUT_VARIABLE PYTHON_STATIC_RUN_OUTPUT
        ARGS "${PYTHON_STATIC_HOME}" "${PYTHON_EXECUTABLE}")
    if(NOT PYTHON_STATIC_COMPILE_RESULT OR NOT "${PYTHON_STATIC_RUN_RESULT}" STREQUAL "0")
        message(FATAL_ERROR
            "Static Python embedding check failed.\n"
            "${PYTHON_STATIC_COMPILE_OUTPUT}\n${PYTHON_STATIC_RUN_OUTPUT}")
    endif()
    message(STATUS "Static Python embedding check passed (pyexpat, zlib and hashes; home: ${PYTHON_STATIC_HOME})")

    # qmake expects space-separated libraries, not a CMake semicolon list.
    string(REPLACE ";" " " PYTHON_LINK "${PYTHON_LIBRARY}")
    set(PYTHON_LINK "-rdynamic -Wl,--whole-archive ${PYTHON_LINK} -Wl,--no-whole-archive ${PYTHON_STATIC_FLAGS}")
endif()'''
if text.count(original) != 1:
    raise SystemExit(
        "Could not patch static Python linking. Upstream CMake code changed; "
        "update packaging/arm64/patch_source.py for this tag."
    )
path.write_text(text.replace(original, replacement, 1), encoding="utf-8")
print(f"Patched static Python dependencies and embedding check in {path}")
