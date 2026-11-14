# Derived from python-ftfy v6.3.1, ftfy/badness.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Two patterns derived from upstream's BADNESS_RE, read from its parse
tree, that answer only whether a string holds a match of it (#52).

Both rest on one fact about upstream's pattern, which `branches()` checks
rather than assumes: it is one alternation, and each branch is a sequence
of items, each item one character (possibly optional) or the anchor "^".
Call an item "non-ASCII" when it is one character, not optional, that no
ASCII character matches. A branch's first non-ASCII item is its *core*.

- The screen, BADNESS_SCREEN_RE: every match holds either two adjacent
  non-ASCII characters (when the item after a branch's core is non-ASCII
  too), or one of the characters its core alone can match. The screen is
  the set of those characters, or two adjacent non-ASCII characters. A
  string it does not match cannot match BADNESS_RE. It compiles about 40
  times faster than BADNESS_RE, and most clean text does not match it.
- The detect form, BADNESS_DETECT_RE: each branch with items before its
  core has them moved into a lookbehind, `L C R` becoming `(?<=L)C R`.
  A string holds a match of one exactly when it holds a match of the other:
  L matches up to a point q and C R matches from q, in both. Only where the
  matches start differs, so the form is for detection and never for
  counting or locating. Every branch then starts on a non-ASCII item or at
  "^", so ICU skips each ASCII character instead of trying all 37 branches
  there, which made BADNESS_RE 11 times slower on long text.

Python cannot compile the detect form (its lookbehind must be of fixed
width), so tests/testthat/test-patterns.R checks both against what the
reference version's BADNESS_RE matches in the span fixture.

Not a generator: files whose names start with an underscore are skipped by
data-raw/regenerate.py.
"""

import re
from re import _compiler, _constants as C, _parser

from _icu import _ALLOWED_FLAGS, _format_ranges, _ranges, items_to_icu

_ONE = (C.LITERAL, C.IN, C.ANY)


def _matcher(item, flags):
    """A compiled pattern that matches what the single item `item` matches."""
    return _compiler.compile(_parser.SubPattern(_parser.State(), [item]), flags)


def _is_non_ascii(item, flags):
    op, _ = item
    if op not in _ONE:
        return False
    one = _matcher(item, flags)
    return not any(one.fullmatch(chr(cp)) for cp in range(0x80))


def _characters(item, flags):
    """Every code point the single item matches, surrogates left out."""
    one = _matcher(item, flags)
    return [
        cp
        for cp in range(0x80, 0x110000)
        if not 0xD800 <= cp <= 0xDFFF and one.fullmatch(chr(cp))
    ]


def branches(compiled):
    """The branches of the pattern, each a list of parse-tree items, and the
    flags to match a single item with."""
    # The flags `to_icu()` accepts, and nothing set inside the pattern: the
    # items are matched here with these flags and written without them.
    if not isinstance(compiled.pattern, str) or compiled.flags & ~_ALLOWED_FLAGS:
        raise NotImplementedError("flags %r" % re.RegexFlag(compiled.flags))
    if compiled.groups:
        raise NotImplementedError("groups")
    flags = compiled.flags & ~re.VERBOSE
    tree = _parser.parse(compiled.pattern, compiled.flags)
    if tree.state.flags != compiled.flags:
        raise NotImplementedError("flags set inside the pattern")
    if len(tree) != 1 or tree[0][0] is not C.BRANCH:
        raise NotImplementedError("a pattern that is not one alternation")
    out = []
    for branch in tree[0][1][1]:
        items = list(branch)
        for op, arg in items:
            if op in _ONE or (op is C.AT and arg is C.AT_BEGINNING):
                continue
            if op is C.MAX_REPEAT and arg[:2] == (0, 1) and len(arg[2]) == 1 and arg[2][0][0] in _ONE:
                continue
            raise NotImplementedError("in a branch: %s %r" % (op, arg))
        out.append(items)
    return out, flags


def _core(items, flags):
    for place, item in enumerate(items):
        if _is_non_ascii(item, flags):
            return place
    raise NotImplementedError("a branch that can match ASCII alone")


def screen(compiled):
    """BADNESS_SCREEN_RE, as an ICU pattern."""
    found, flags = branches(compiled)
    alone = set()
    for items in found:
        place = _core(items, flags)
        after = items[place + 1] if place + 1 < len(items) else None
        if after is None or not _is_non_ascii(after, flags):
            alone.update(_characters(items[place], flags))
    if not alone:
        raise NotImplementedError("no branch with a core of one character")
    return "[%s]|[^\\x{0}-\\x{7F}]{2}" % _format_ranges(_ranges(sorted(alone)))


def detect(compiled):
    """BADNESS_DETECT_RE, as an ICU pattern."""
    found, flags = branches(compiled)
    written = []
    for items in found:
        place = _core(items, flags)
        before = items[:place]
        if any(op is C.AT for op, _ in before):
            if before != [(C.AT, C.AT_BEGINNING)]:
                raise NotImplementedError("'^' with other items before the core")
            written.append(items_to_icu(items))
        elif before:
            written.append("(?<=%s)%s" % (items_to_icu(before), items_to_icu(items[place:])))
        else:
            written.append(items_to_icu(items))
    return "(?:%s)" % "|".join(written)
