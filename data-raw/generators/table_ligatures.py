# Derived from python-ftfy v6.3.1, ftfy/chardata.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the Latin ligatures and digraphs that fix_latin_ligatures() takes
apart, read from the installed reference version (chardata.LIGATURES), to
data-raw/tables/ligatures.txt.

Columns, tab separated: code_point (hexadecimal) and replacement (the code
points of the text it becomes, in hexadecimal, separated by spaces)."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import require_reference, write_ascii
from _table import translate_table

require_reference()

from ftfy import chardata

assert len(chardata.LIGATURES) == 22
write_ascii("data-raw/tables/ligatures.txt", translate_table(chardata.LIGATURES))
