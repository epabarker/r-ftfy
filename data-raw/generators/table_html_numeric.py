# Derived from python-ftfy v6.3.1, ftfy/fixes.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write what unescape_html() makes of a numeric HTML reference, where that
is not simply the character with that number, to
data-raw/tables/html_numeric.txt.

Found by probing the installed reference version: fixes.unescape_html() on
the decimal reference for every number from 0 to U+10FFFF, and for some
numbers above. Python's own html tables are not copied.

Columns, tab separated: first and last (a range of numbers in hexadecimal,
both included; the last range ends in the word inf) and result:

- a code point in hexadecimal: the reference becomes that character;
- empty: the reference is removed;
- unchanged: the reference is left as it was written (number 3B, the
  semicolon, which the reference version takes for a reference that was
  only partly decoded).

A number in no range becomes the character with that number. The script
also checks that the hexadecimal forms and the forms with leading zeros
give the same result as the decimal form."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import require_reference, write_ascii
from _table import code_point

require_reference()

from ftfy import fixes

LAST = 0x10FFFF
# Numbers above the last code point, up to the 24 digits HTML_ENTITY_RE
# allows. All of them must give U+FFFD.
ABOVE = [
    LAST + 1,
    LAST + 2,
    2**31 - 1,
    2**31,
    2**32,
    2**53,
    2**63,
    2**64,
    10**23,
    10**24 - 1,
]


def result_of(number):
    written = "&#%d;" % number
    out = fixes.unescape_html(written)
    forms = ["&#x%x;" % number, "&#X%X;" % number, "&#x%X;" % number]
    if len(written) <= 20:
        forms += ["&#000%d;" % number, "&#x000%x;" % number]
    for form in forms:
        other = fixes.unescape_html(form)
        assert (other == form) if out == written else (other == out), form
    if out == written:
        return "unchanged"
    if out == "":
        return "empty"
    assert len(out) == 1, written
    if number <= LAST and out == chr(number):
        return None
    return code_point(ord(out))


ranges = []
for number in range(LAST + 1):
    result = result_of(number)
    if result is None:
        continue
    if ranges and ranges[-1][1] == number - 1 and ranges[-1][2] == result:
        ranges[-1][1] = number
    else:
        ranges.append([number, number, result])
for number in ABOVE:
    assert result_of(number) == "FFFD", number

lines = ["first\tlast\tresult\n"]
lines += [
    "%s\t%s\t%s\n" % (code_point(first), code_point(last), result)
    for first, last, result in ranges
]
lines.append("%s\tinf\tFFFD\n" % code_point(LAST + 1))
write_ascii("data-raw/tables/html_numeric.txt", "".join(lines))
