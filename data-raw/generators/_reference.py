# Derived from python-ftfy v6.3.1, ftfy/. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Shared helpers for generator scripts. Not a generator: files whose names
start with an underscore are skipped by data-raw/regenerate.py."""

import os
import sys
import unicodedata

REPO = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)

FTFY_VERSION = "6.3.1"
PYTHON_VERSION = (3, 13)
UNICODE_VERSION = "15.1.0"


def require_reference():
    """Stop unless this interpreter is the reference version."""
    import ftfy

    found = (ftfy.__version__, sys.version_info[:2], unicodedata.unidata_version)
    wanted = (FTFY_VERSION, PYTHON_VERSION, UNICODE_VERSION)
    if found != wanted:
        sys.exit(
            "not the reference version: found ftfy %s on Python %s with "
            "Unicode %s, need ftfy %s on Python %s with Unicode %s"
            % (
                found[0],
                ".".join(map(str, found[1])),
                found[2],
                wanted[0],
                ".".join(map(str, wanted[1])),
                wanted[2],
            )
        )


def write_ascii(relative_path, text):
    """Write a generated file, ASCII only with LF line ends, under the repo."""
    path = os.path.join(REPO, *relative_path.split("/"))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="ascii", newline="\n") as handle:
        handle.write(text)
    print("wrote", relative_path)


def escape(text):
    """Write text as printable ASCII, for R's stringi::stri_unescape_unicode().

    Every character outside U+0020 to U+007E, and the backslash, becomes
    \\uXXXX or \\UXXXXXXXX, so a field never holds a tab or a line end.
    """
    out = []
    for ch in text:
        cp = ord(ch)
        if 0x20 <= cp <= 0x7E and ch != "\\":
            out.append(ch)
        elif cp <= 0xFFFF:
            out.append("\\u%04X" % cp)
        else:
            out.append("\\U%08X" % cp)
    return "".join(out)
