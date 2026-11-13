# Derived from python-ftfy v6.3.1, ftfy/chardata.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Shared code for the generators of data tables (table_*.py). Not a
generator: files whose names start with an underscore are skipped by
data-raw/regenerate.py."""


def code_point(number):
    """One code point as four to six upper-case hexadecimal digits."""
    return "%04X" % number


def code_points(text):
    """A string as its code points in hexadecimal, separated by spaces."""
    return " ".join(code_point(ord(ch)) for ch in text)


def storable(text):
    """Can an R string hold this text? Not U+0000, not a surrogate."""
    return not any(ord(ch) == 0 or 0xD800 <= ord(ch) <= 0xDFFF for ch in text)


def translate_table(mapping):
    """The lines of a str.translate() mapping from one character to text:
    the header, then one line for each character in code point order."""
    lines = ["code_point\treplacement\n"]
    for number in sorted(mapping):
        replacement = mapping[number]
        assert isinstance(replacement, str) and replacement and storable(replacement)
        # str.translate() makes one pass. The R side may make several, which
        # is only the same when no replacement holds a character of the map.
        assert not any(ord(ch) in mapping for ch in replacement)
        lines.append("%s\t%s\n" % (code_point(number), code_points(replacement)))
    return "".join(lines)
