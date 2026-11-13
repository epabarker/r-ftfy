# Derived from python-ftfy v6.3.1, ftfy/chardata.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the table of the codec sloppy-windows-1251 to data-raw/codecs/sloppy-windows-1251.txt."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _codec import write_codec_table

write_codec_table("sloppy-windows-1251")
