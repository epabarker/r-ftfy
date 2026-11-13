# Derived from python-ftfy v6.3.1, ftfy/chardata.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the bytes pattern for UTF-8 with bytes lost to a replacement, read from the installed
reference version, as a single-line ICU pattern in
data-raw/patterns/LOSSY_UTF8_RE.txt.

A bytes pattern: it is written over the code points U+0000 to U+00FF and
matches a byte string held as text, with byte b as the character U+00b."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _icu import to_icu
from _reference import require_reference, write_ascii

require_reference()

from ftfy import chardata

write_ascii("data-raw/patterns/LOSSY_UTF8_RE.txt", to_icu(chardata.LOSSY_UTF8_RE) + "\n")
