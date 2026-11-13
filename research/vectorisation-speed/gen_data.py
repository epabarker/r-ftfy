# PROTOTYPE, throwaway. Dumps the regexes and tables the R prototype needs
# from installed ftfy 6.3.1 into data.json (not committed: it embeds upstream
# literals). Run: venv/bin/python -I gen_data.py <outdir>
import json
import re
import sys

import ftfy
from ftfy import badness, chardata, fixes

assert ftfy.__version__ == "6.3.1"
out_dir = sys.argv[1]


def ranges(pred):
    out, start = [], None
    for cp in range(0x110000):
        ok = pred(cp)
        if ok and start is None:
            start = cp
        if not ok and start is not None:
            out.append((start, cp - 1))
            start = None
    if start is not None:
        out.append((start, 0x10FFFF))
    return out


def fmt_ranges(rs):
    return "".join(
        "\\x{%x}" % a if a == b else "\\x{%x}-\\x{%x}" % (a, b) for a, b in rs
    )


def is_surrogate(cp):
    return 0xD800 <= cp <= 0xDFFF


S_SET = fmt_ranges(ranges(lambda cp: not is_surrogate(cp) and re.match(r"\s", chr(cp)) is not None))
D_SET = fmt_ranges(ranges(lambda cp: not is_surrogate(cp) and re.match(r"\d", chr(cp)) is not None))
W_SET = fmt_ranges(ranges(lambda cp: not is_surrogate(cp) and re.match(r"\w", chr(cp)) is not None))


def esc(ch):
    o = ord(ch)
    if 0x21 <= o <= 0x7E:
        return ch
    return "\\x{%x}" % o


def to_icu(pat, verbose):
    """Flatten a Python pattern (str or latin-1 bytes) to an ASCII ICU pattern."""
    if isinstance(pat, bytes):
        pat = pat.decode("latin-1")
    out, i, in_class = [], 0, False
    while i < len(pat):
        ch = pat[i]
        if ch == "\\":
            nxt = pat[i + 1]
            if nxt == "s":
                out.append(S_SET if in_class else "[" + S_SET + "]")
            elif nxt == "w":
                out.append(W_SET if in_class else "[" + W_SET + "]")
            elif nxt == "d":
                out.append(D_SET if in_class else "[" + D_SET + "]")
            elif 0x21 <= ord(nxt) <= 0x7E:
                out.append("\\" + nxt)
            else:
                out.append(esc(nxt))
            i += 2
            continue
        if in_class:
            if ch == "]":
                in_class = False
            out.append(esc(ch) if ch != "]" else ch)
        else:
            if verbose and ch in " \t\n\r\f\v":
                pass
            elif verbose and ch == "#":
                while i < len(pat) and pat[i] != "\n":
                    i += 1
                continue
            elif ch == "[":
                in_class = True
                out.append(ch)
            else:
                out.append(esc(ch))
        i += 1
    return "".join(out)


def rx(r):
    return to_icu(r.pattern, bool(r.flags & re.VERBOSE))


def decode_table(enc):
    t = []
    for b in range(256):
        try:
            t.append(ord(bytes([b]).decode(enc)))
        except UnicodeDecodeError:
            t.append(-1)
    return t

codec_tables = {enc: decode_table(enc) for enc in chardata.CHARMAP_ENCODINGS + ["windows-1252"]}

data = {
    "charmap_encodings": chardata.CHARMAP_ENCODINGS,
    "codec_tables": codec_tables,
    "encoding_regexes": {k: rx(v) for k, v in chardata.ENCODING_REGEXES.items()},
    "badness_re": rx(badness.BADNESS_RE),
    "utf8_detector_re": rx(chardata.UTF8_DETECTOR_RE),
    "altered_utf8_re": rx(chardata.ALTERED_UTF8_RE),
    "lossy_utf8_re": rx(chardata.LOSSY_UTF8_RE),
    "a_grave_word_re": rx(fixes.A_GRAVE_WORD_RE),
    "c1_control_re": rx(chardata.C1_CONTROL_RE),
    "html_entity_re": rx(chardata.HTML_ENTITY_RE),
    "ansi_re": rx(fixes.ANSI_RE),
    "single_quote_re": rx(chardata.SINGLE_QUOTE_RE),
    "double_quote_re": rx(chardata.DOUBLE_QUOTE_RE),
    "html_entities": chardata.HTML_ENTITIES,
    "ligatures": {chr(k): v for k, v in chardata.LIGATURES.items()},
    "width_map": {chr(k): v for k, v in chardata.WIDTH_MAP.items()},
    "control_chars": sorted(chardata.CONTROL_CHARS),
}
with open(f"{out_dir}/data.json", "w", encoding="ascii") as fh:
    json.dump(data, fh, ensure_ascii=True)
print("wrote", f"{out_dir}/data.json")
