# Derived from python-ftfy v6.3.1, ftfy/. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Rewrite a compiled Python pattern as a single-line, ASCII-only ICU pattern.

The pattern is not translated as text. Python's own parser reads it, and the
ICU pattern is written from the parse tree, so verbose-mode spacing, comments
and escapes mean exactly what they mean to Python. Every literal is written
as \\x{...}, and Python's \\s, \\w and \\d become explicit code-point sets
taken from the running interpreter.

A bytes pattern becomes a pattern over the code points U+0000 to U+00FF:
byte b is written as the character U+00b, so the ICU pattern matches a byte
string held as text in that form. In a bytes pattern Python's \\s, \\w, \\d
and "." mean something else, and they are refused.

Capturing groups stay capturing groups with the same numbers. Negative
lookahead and fixed-width negative lookbehind are written as ICU's.

The pattern must be used with ICU's UNIX_LINES option on and COMMENTS off
(ADR 0005). Anything this module has not been taught raises an error; it
never guesses. That includes "$", lazy and possessive repeats, positive
lookarounds, backreferences, named groups, flags set inside the pattern
and negated categories such as \\S.

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


class _Writer:
    """Writes one pattern. `is_bytes` says whether it is a bytes pattern."""

    def __init__(self, is_bytes):
        self.is_bytes = is_bytes
        self.groups_written = 0


def _class(items, writer):
    out = ["["]
    for op, arg in items:
        if op is C.NEGATE:
            out.append("^")
        elif op is C.LITERAL:
            out.append(_literal(arg))
        elif op is C.RANGE:
            out.append("%s-%s" % (_literal(arg[0]), _literal(arg[1])))
        elif op is C.CATEGORY and not writer.is_bytes:
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


def _width(items):
    """The fixed number of characters `items` matches, or an error."""
    low, high = items.getwidth()
    if low != high:
        raise NotImplementedError("a lookbehind that is not of fixed width")
    return low


def _sequence(items, writer):
    out = []
    for op, arg in items:
        if op is C.LITERAL:
            out.append(_literal(arg))
        elif op is C.IN:
            out.append(_class(arg, writer))
        elif op is C.ANY and not writer.is_bytes:
            # Python's "." without DOTALL is anything but a line feed, which
            # is what ICU's "." means under UNIX_LINES.
            out.append(".")
        elif op is C.BRANCH:
            out.append(
                "(?:%s)"
                % "|".join(_sequence(branch, writer) for branch in arg[1])
            )
        elif op is C.MAX_REPEAT:
            low, high, body = arg
            inner = _sequence(body, writer)
            if not (len(body) == 1 and body[0][0] in _SINGLE + (C.SUBPATTERN,)):
                inner = "(?:%s)" % inner
            out.append(inner + _repeat(low, high))
        elif op is C.AT and arg is C.AT_BEGINNING:
            # Without MULTILINE, both engines match "^" only at the start.
            out.append("^")
        elif op is C.SUBPATTERN:
            group, add_flags, del_flags, body = arg
            if group is None or add_flags or del_flags:
                raise NotImplementedError("a group that sets flags")
            # Groups are numbered by their opening bracket in both engines;
            # check that this one is written in its turn.
            writer.groups_written += 1
            if group != writer.groups_written:
                raise NotImplementedError("group %r out of order" % group)
            out.append("(%s)" % _sequence(body, writer))
        elif op is C.ASSERT_NOT:
            direction, body = arg
            if direction == 1:
                out.append("(?!%s)" % _sequence(body, writer))
            elif direction == -1:
                # ICU needs a bounded lookbehind; Python a fixed-width one.
                _width(body)
                out.append("(?<!%s)" % _sequence(body, writer))
            else:
                raise NotImplementedError("lookaround direction %r" % direction)
        else:
            raise NotImplementedError("%s %r" % (op, arg))
    return "".join(out)


def to_icu(compiled):
    """The ICU pattern equivalent to a compiled Python pattern.

    For a bytes pattern the result matches text in which byte b is the
    character U+00b.
    """
    is_bytes = isinstance(compiled.pattern, bytes)
    if is_bytes:
        allowed = 0
    elif isinstance(compiled.pattern, str):
        allowed = _ALLOWED_FLAGS
        if not compiled.flags & re.UNICODE:
            raise NotImplementedError("a str pattern without re.UNICODE")
    else:
        raise NotImplementedError("pattern type %r" % type(compiled.pattern))
    if compiled.flags & ~allowed:
        raise NotImplementedError("flags %r" % re.RegexFlag(compiled.flags))
    if compiled.groupindex:
        raise NotImplementedError("named groups")
    tree = _parser.parse(compiled.pattern, compiled.flags)
    if tree.state.flags != compiled.flags:
        raise NotImplementedError("flags set inside the pattern")
    writer = _Writer(is_bytes)
    pattern = _sequence(tree, writer)
    if writer.groups_written != compiled.groups:
        raise NotImplementedError("groups that were not all written")
    pattern.encode("ascii")
    return pattern
