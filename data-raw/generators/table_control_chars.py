# Derived from python-ftfy v6.3.1, ftfy/chardata.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the control characters that remove_control_chars() removes, read
from the installed reference version (chardata.CONTROL_CHARS), to
data-raw/tables/control_chars.txt.

One column, code_point, in hexadecimal and in code point order. U+0000 is
listed because the reference version removes it, though no R string holds
it."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import require_reference, write_ascii
from _table import code_point

require_reference()

from ftfy import chardata

assert len(chardata.CONTROL_CHARS) == 40
assert all(value is None for value in chardata.CONTROL_CHARS.values())
lines = ["code_point\n"]
lines += ["%s\n" % code_point(number) for number in sorted(chardata.CONTROL_CHARS)]
write_ascii("data-raw/tables/control_chars.txt", "".join(lines))
