# Derived from python-ftfy v6.3.1, ftfy/badness.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write BADNESS_SCREEN_RE, derived from the badness pattern of the installed
reference version (see _badness.py), as a single-line ICU pattern in
data-raw/patterns/BADNESS_SCREEN_RE.txt."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _badness import screen
from _reference import require_reference, write_ascii

require_reference()

from ftfy import badness

write_ascii("data-raw/patterns/BADNESS_SCREEN_RE.txt", screen(badness.BADNESS_RE) + "\n")
