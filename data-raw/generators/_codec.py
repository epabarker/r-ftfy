# Derived from python-ftfy v6.3.1, ftfy/bad_codecs/sloppy.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write one codec table, read from the installed reference version.

Each of the 256 bytes is decoded on its own through the codec, so nothing
about a codec (the sloppy rule included) is derived again here. The table
is written to data-raw/codecs/<codec>.txt: a header line, then one line per
byte in byte order, holding the byte and the code point it decodes to, both
in hexadecimal and separated by a tab. A hole, a byte the codec assigns no
character to, has "hole" in place of the code point.

Not a generator: files whose names start with an underscore are skipped by
data-raw/regenerate.py. A generator for one codec is a few lines; see
codec_latin-1.py.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import require_reference, write_ascii


def write_codec_table(codec):
    require_reference()

    import ftfy.bad_codecs  # noqa: F401  (registers the sloppy codecs)

    lines = ["byte\tcode_point\n"]
    for byte in range(256):
        try:
            char = bytes([byte]).decode(codec)
        except UnicodeDecodeError:
            lines.append("%02X\thole\n" % byte)
            continue
        if len(char) != 1:
            sys.exit(
                "%s decodes byte %02X to %d characters" % (codec, byte, len(char))
            )
        lines.append("%02X\t%04X\n" % (byte, ord(char)))
    write_ascii("data-raw/codecs/%s.txt" % codec, "".join(lines))
