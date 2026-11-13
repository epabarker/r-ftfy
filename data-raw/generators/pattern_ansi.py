# Derived from python-ftfy v6.3.1, ftfy/fixes.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the pattern for ANSI terminal escapes, read from the installed
reference version, as a single-line ICU pattern in
data-raw/patterns/ANSI_RE.txt."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _icu import to_icu
from _reference import require_reference, write_ascii

require_reference()

from ftfy import fixes

write_ascii("data-raw/patterns/ANSI_RE.txt", to_icu(fixes.ANSI_RE) + "\n")
