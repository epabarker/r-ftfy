# Derived from python-ftfy v6.3.1, ftfy/. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Reading and writing the generated files that are kept compressed with xz
(the benchmark columns and the larger corpus). Not a generator.

The compression settings are fixed and an xz stream holds no file name and
no time, so the same text gives the same bytes on every run with the same
liblzma. A different liblzma may choose other bytes for the same text, so
write_xz() leaves a file alone when it already holds the text: what the
`reference` workflow then compares is the text, byte for byte, and not the
choices of one compressor. Set FTFY_REWRITE_XZ=true to write every file
again whatever it holds.

R reads these files with base R alone: readLines(xzfile(path)) or
read.delim(xzfile(path), ...).
"""

import lzma
import os

from _reference import REPO

PRESET = 9
# A committed xz file larger than this is a mistake.
MAX_FILE_BYTES = 20_000_000


def path_of(relative_path):
    return os.path.join(REPO, *relative_path.split("/"))


def read_xz(relative_path):
    """The text of a compressed file. Every such file is ASCII."""
    with open(path_of(relative_path), "rb") as handle:
        return lzma.decompress(handle.read(), format=lzma.FORMAT_XZ).decode("ascii")


def write_xz(relative_path, text):
    """Write a generated file, ASCII only with LF line ends, compressed."""
    assert "\r" not in text
    data = text.encode("ascii")
    path = path_of(relative_path)
    if os.path.exists(path) and os.environ.get("FTFY_REWRITE_XZ") != "true":
        try:
            with open(path, "rb") as handle:
                same = lzma.decompress(handle.read(), format=lzma.FORMAT_XZ) == data
        except lzma.LZMAError:
            same = False
        if same:
            print("unchanged", relative_path)
            return
    packed = lzma.compress(
        data, format=lzma.FORMAT_XZ, check=lzma.CHECK_CRC64, preset=PRESET
    )
    assert len(packed) <= MAX_FILE_BYTES, (relative_path, len(packed))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as handle:
        handle.write(packed)
    print("wrote", relative_path, "(%d bytes of text, %d compressed)" % (len(data), len(packed)))
