# Derived from python-ftfy v6.3.1, ftfy/chardata.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the named HTML entities that unescape_html() decodes, read from the
installed reference version (chardata.HTML_ENTITIES), to
data-raw/tables/html_entities.txt.

Columns, tab separated: entity (as written in text, from the ampersand to
the semicolon; ASCII) and replacement (the code points of the text it
becomes, in hexadecimal, separated by spaces). In order of entity. Every
entry is written, including the few whose name is longer than
HTML_ENTITY_RE can match."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import require_reference, write_ascii
from _table import code_points, storable

require_reference()

from ftfy import chardata

entities = chardata.HTML_ENTITIES
assert len(entities) == 3501
lines = ["entity\treplacement\n"]
for entity in sorted(entities):
    replacement = entities[entity]
    assert entity.isascii()
    assert entity.startswith("&") and entity.endswith(";") and entity[1:-1].isalnum()
    assert replacement and storable(replacement)
    lines.append("%s\t%s\n" % (entity, code_points(replacement)))
write_ascii("data-raw/tables/html_entities.txt", "".join(lines))
