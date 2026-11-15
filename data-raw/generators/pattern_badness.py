# Derived from python-ftfy v6.3.1, ftfy/badness.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the badness pattern, read from the installed reference version, as
a single-line ICU pattern in data-raw/patterns/BADNESS_RE.txt."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _icu import to_icu
from _reference import require_reference, write_ascii

require_reference()

from ftfy import badness

write_ascii("data-raw/patterns/BADNESS_RE.txt", to_icu(badness.BADNESS_RE) + "\n")
