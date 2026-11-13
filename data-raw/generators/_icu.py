# Derived from python-ftfy v6.3.1, ftfy/. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Rewrite a compiled Python pattern as a single-line, ASCII-only ICU pattern.

The pattern is not translated as text. Python's own parser reads it, and the
ICU pattern is written from the parse tree, so verbose-mode spacing, comments
and escapes mean exactly what they mean to Python. Every literal is written
as \\x{...}, and Python's \\s, \\w and \\d become explicit code-point sets
taken from the running interpreter.

The pattern must be used with ICU's UNIX_LINES option on and COMMENTS off
(ADR 0005). Anything this module has not been taught raises an error; it
never guesses.

Not a generator: files whose names start with an underscore are skipped by
data-raw/regenerate.py.
"""

import re
from re import _constants as C
from re import _parser

_ALLOWED_FLAGS = re.UNICODE | re.VERBOSE


def _ranges(codes):
    out = []
    for cp in codes:
        if out and out[-1][1] == cp - 1:
            out[-1][1] = cp
        else:
            out.append([cp, cp])
    return out


def _format_ranges(ranges):
    return "".join(
        "\\x{%X}" % lo if lo == hi else "\\x{%X}-\\x{%X}" % (lo, hi)
        for lo, hi in ranges
    )


def _category_set(escape):
    """The code points Python's `escape` matches, as ICU set contents.

    Surrogates are left out: they match none of \\s, \\w and \\d, and R
    strings cannot hold them.
    """
    one = re.compile(escape)
    codes = [
        cp
        for cp in range(0x110000)
        if not 0xD800 <= cp <= 0xDFFF and one.fullmatch(chr(cp))
    ]
    return _format_ranges(_ranges(codes))


_CATEGORY_ESCAPES = {
    C.CATEGORY_SPACE: r"\s",
    C.CATEGORY_WORD: r"\w",
    C.CATEGORY_DIGIT: r"\d",
}
_category_cache = {}


def _category(category):
    if category not in _CATEGORY_ESCAPES:
        raise NotImplementedError("category %s" % category)
    if category not in _category_cache:
        _category_cache[category] = _category_set(_CATEGORY_ESCAPES[category])
    return _category_cache[category]


def _literal(cp):
    return "\\x{%X}" % cp


def _class(items):
    out = ["["]
    for op, arg in items:
        if op is C.NEGATE:
            out.append("^")
        elif op is C.LITERAL:
            out.append(_literal(arg))
        elif op is C.RANGE:
            out.append("%s-%s" % (_literal(arg[0]), _literal(arg[1])))
        elif op is C.CATEGORY:
            out.append(_category(arg))
        else:
            raise NotImplementedError("in a character class: %s" % op)
    out.append("]")
    return "".join(out)


def _repeat(low, high):
    if (low, high) == (0, 1):
        return "?"
    if (low, high) == (0, C.MAXREPEAT):
        return "*"
    if (low, high) == (1, C.MAXREPEAT):
        return "+"
    if high == C.MAXREPEAT:
        return "{%d,}" % low
    if low == high:
        return "{%d}" % low
    return "{%d,%d}" % (low, high)


_SINGLE = (C.LITERAL, C.IN, C.ANY)


def _sequence(items):
    out = []
    for op, arg in items:
        if op is C.LITERAL:
            out.append(_literal(arg))
        elif op is C.IN:
            out.append(_class(arg))
        elif op is C.ANY:
            # Python's "." without DOTALL is anything but a line feed, which
            # is what ICU's "." means under UNIX_LINES.
            out.append(".")
        elif op is C.BRANCH:
            out.append(
                "(?:%s)" % "|".join(_sequence(branch) for branch in arg[1])
            )
        elif op is C.MAX_REPEAT:
            low, high, body = arg
            inner = _sequence(body)
            if not (len(body) == 1 and body[0][0] in _SINGLE):
                inner = "(?:%s)" % inner
            out.append(inner + _repeat(low, high))
        elif op is C.AT and arg is C.AT_BEGINNING:
            # Without MULTILINE, both engines match "^" only at the start.
            out.append("^")
        else:
            raise NotImplementedError("%s %r" % (op, arg))
    return "".join(out)


def to_icu(compiled):
    """The ICU pattern equivalent to a compiled Python str pattern."""
    if not isinstance(compiled.pattern, str):
        raise NotImplementedError("byte patterns")
    if compiled.flags & ~_ALLOWED_FLAGS:
        raise NotImplementedError("flags %r" % re.RegexFlag(compiled.flags))
    tree = _parser.parse(compiled.pattern, compiled.flags)
    if tree.state.flags != compiled.flags:
        raise NotImplementedError("flags set inside the pattern")
    pattern = _sequence(tree)
    pattern.encode("ascii")
    return pattern
