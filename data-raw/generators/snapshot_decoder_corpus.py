# Derived from python-ftfy v6.3.1, ftfy/bad_codecs/utf8_variants.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""Write the decoder corpus to tests/testthat/reference/decoder_corpus.tsv.

One row per byte sequence, with what the reference version's strict
decoders give for it. Columns, tab separated:

bytes                the sequence, as hexadecimal pairs without spaces
utf8                 "text" or "fails": the codec utf-8
utf8_text            the decoded text, escaped (see _reference.escape)
variants             "text" or "fails": what the R package must give for
                     the codec utf-8-variants
variants_text        that text, escaped
python_variants      "text" or "fails": what the reference version gives
                     for utf-8-variants
python_variants_text that text, escaped; it may hold \\u0000, which R must
                     not unescape
departure            empty, or the id of the departure registry entry
                     (inst/departures/) by which the two differ

Nothing about the R decoder is written again here. The R columns are made
from the reference version's own answers by two rules:

- utf8-variants-trailing-newline (ADR 0004): the R package reads the end
  of the input as the true end. The reference version's answer for that
  is its answer to the same bytes with one more byte, 41, after them. If
  that fails where the bytes alone decode, the R package fails.
- decoded-nul-dropped (ADR 0007): otherwise the R package gives the
  reference version's text without its U+0000 characters.

No sequence holds byte 00, which an R string cannot hold. The random part
is seeded, so a rerun gives the same file byte for byte.
"""

import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from _reference import escape, require_reference, write_ascii

require_reference()

import ftfy.bad_codecs  # noqa: E402,F401  (registers utf-8-variants)

SEED = 33


def cesu8_of(text):
    """Encode text as CESU-8: astral characters as two three-byte surrogates."""
    out = b""
    for ch in text:
        if ord(ch) >= 0x10000:
            units = ch.encode("utf-16-be")
            high = int.from_bytes(units[:2], "big")
            low = int.from_bytes(units[2:], "big")
            out += chr(high).encode("utf-8", "surrogatepass")
            out += chr(low).encode("utf-8", "surrogatepass")
        else:
            out += ch.encode("utf-8")
    return out


def sequences():
    seen = set()
    out = []

    def add(seq):
        seq = bytes(seq)
        if seq and 0 not in seq and seq not in seen:
            seen.add(seq)
            out.append(seq)

    # Upstream's own examples: the doctest at utf8_variants.py:13, and
    # tests/test_encodings.py:9, tests/test_encodings.py:15,
    # tests/test_bytes.py:31 and tests/test_bytes.py:38.
    add(b"here comes a null! \xc0\x80")
    add(b"\xed\xa6\x9d\xed\xbd\xb7 is an unassigned character, and \xc0\x80 is null")
    add(b"\xe8\xed\xe2\xe5\xed\xf2\xe0\xf0\xe8\xe7\xe0\xf6\xe8\xff ")
    add(b"null\xc0\x80separated")
    add(b"surrogates: \xed\xa0\x80\xed\xb0\x80 / null: \xc0\x80")

    # The departures and what stands around them.
    pair = b"\xed\xa0\xbd\xed\xb8\x8a"
    for prefix in (b"", b"abc", b"sch\xc3\xb6n ", b"\n", b"\xf0\x9f\x98\x8a"):
        add(prefix + b"\xc0\x80")
        add(prefix + b"\xc0")
        add(prefix + b"\xc0\n")
        add(prefix + b"\xc0\n\n")
        add(prefix + b"\xc0\r\n")
        add(prefix + b"\xc0\nabc")
        add(prefix + b"\xc0\x80\n")
        add(prefix + b"\xc0\x80\xc0\n")
        add(prefix + b"\xc0\x80\xc0\x80")
        add(prefix + b"\xc0A")
        add(prefix + pair)
        for length in range(1, 6):
            cut = pair[:length]
            add(prefix + cut)
            add(prefix + cut + b"\n")
            add(prefix + cut + b"\n\n")
            add(prefix + cut + b"\nabc")
            add(prefix + cut + b"A")
        add(prefix + pair + b"\n")
        add(prefix + pair + pair)
        add(prefix + pair + pair[:5] + b"\n")
        add(prefix + pair + b"\xc0\x80" + pair)

    # Every five bytes of a pair followed by a newline, at the corners.
    for b1 in (0xA0, 0xAF):
        for b2 in (0x80, 0xBF):
            for b4 in (0xB0, 0xBF):
                add(bytes([0xED, b1, b2, 0xED, b4, 0x0A]))
                add(bytes([0xED, b1, b2, 0xED, b4, 0x80]))
                add(bytes([0xED, b1, b2, 0xED, b4, 0xBF]))
                add(bytes([0xED, b1, b2, 0xED, b4, 0x7F]))
                add(bytes([0xED, b1, b2, 0xED, b4, 0xC0]))
    # Just outside a pair, lone surrogates, and pairs the wrong way round.
    add(b"\xed\x9f\xbf\xed\xb0\x80")
    add(b"\xed\xb0\x80\xed\xb0\x80")
    add(b"\xed\xa0\x80\xed\xa0\x80")
    add(b"\xed\xa0\x80\xed\xaf\xbf")
    add(b"\xed\xb0\x80\xed\xa0\x80")
    add(b"\xed\xa0\x80")
    add(b"\xed\xbf\xbf")
    add(b"\xed\xa0\x80\xed\xa0\x80\xed\xb0\x80")
    add(b"\xed\xa0\x80\xed\xb0\x80\xed\xb0\x80")
    add(b"\xed\xa0\x80A\xed\xb0\x80")
    add(b"\xed\x95\x9c\xea\xb5\xad\xec\x96\xb4")
    add(b"\xed\x95\x9c\xed\xa0\x80\xed\xb0\x80\xed\x95\x9c")
    # C0 80 and a pair must not join the bytes on their two sides.
    add(b"\xe2\xc0\x80\x82\xac")
    add(b"\xe2\x82\xc0\x80\xac")
    add(b"\xe2\x82\xc0\x80")
    add(b"\xc0\x80\x82\xac")
    add(b"\xc3\xc0\x80\xa9")
    add(b"\xe2\x82" + pair + b"\xac")
    add(b"\xe2" + pair + b"\x82\xac")
    add(pair + b"\x80")
    add(b"\xf0\x9f" + pair + b"\x98\x8a")
    add(b"\xc0\xc0\x80\x80")
    add(b"\xc0\x80\x80")
    add(b"\xc1\x80")
    add(b"\xc0\x81")
    add(b"\xc0\xbf")
    add(b"\xe0\x80\x80")
    add(b"\xf0\x80\x80\x80")
    add(b"\xef\xbb\xbfbyte order mark")
    add(b"\xef\xbb\xbf\xc0\x80")
    add(b"\xef\xbb\xbf" + pair)

    # Every single byte, and every sequence of two to four bytes whose
    # bytes come from the edges of the ranges in the Unicode standard's
    # table of well-formed UTF-8 (Table 3-7).
    for b1 in range(1, 256):
        add([b1])
    edges = (0x01, 0x0A, 0x41, 0x7F, 0x80, 0x8F, 0x90, 0x9F, 0xA0, 0xAF,
             0xB0, 0xBF, 0xC0, 0xED, 0xFF)
    for b1 in range(0xC0, 0x100):
        for b2 in edges:
            add([b1, b2])
    few = (0x0A, 0x7F, 0x80, 0x9F, 0xA0, 0xBF, 0xC0, 0xED)
    for b1 in range(0xE0, 0xF0):
        for b2 in edges:
            for b3 in few:
                add([b1, b2, b3])
    fewer = (0x0A, 0x80, 0xBF, 0xC0)
    for b1 in range(0xF0, 0xF8):
        for b2 in edges:
            for b3 in fewer:
                for b4 in fewer:
                    add([b1, b2, b3, b4])

    # Seeded: texts in UTF-8 and in CESU-8, whole, cut short, with a
    # final newline, and with one byte changed.
    rng = random.Random(SEED)
    alphabet = (
        "abc xyz\n\r\t"
        "\u00e9\u00f6\u00df\u00c0\u00ed"
        "\u0416\u03a9\u05d0\u0e01"
        "\u2019\u20ac\u2603\ud55c\ufeff\ufffd\uffff"
        "\U00010000\U0001f60a\U0001f600\U00077777\U0010ffff"
    )
    for _ in range(600):
        text = "".join(rng.choice(alphabet) for _ in range(rng.randint(1, 8)))
        for encoded in (text.encode("utf-8"), cesu8_of(text)):
            add(encoded)
            add(encoded + b"\n")
            cut = rng.randint(1, len(encoded))
            add(encoded[:cut])
            add(encoded[:cut] + b"\n")
            changed = bytearray(encoded)
            changed[rng.randrange(len(changed))] = rng.randint(1, 255)
            add(changed)
            if rng.random() < 0.3:
                at = rng.randint(0, len(encoded))
                add(encoded[:at] + b"\xc0\x80" + encoded[at:])
    # Seeded: short strings of the bytes that matter to the two codecs.
    special = (0x0A, 0x41, 0x80, 0x8A, 0xA0, 0xAF, 0xB0, 0xB8, 0xBD, 0xBF,
               0xC0, 0xC3, 0xE2, 0xED, 0xF0)
    for _ in range(1500):
        add(rng.choice(special) for _ in range(rng.randint(2, 8)))
    return out


def decode(seq, codec):
    try:
        return seq.decode(codec)
    except UnicodeDecodeError:
        return None


def cell(text):
    if text is None:
        return "fails\t"
    return "text\t" + escape(text)


def main():
    lines = [
        "bytes\tutf8\tutf8_text\tvariants\tvariants_text\t"
        "python_variants\tpython_variants_text\tdeparture\n"
    ]
    for seq in sequences():
        strict = decode(seq, "utf-8")
        python = decode(seq, "utf-8-variants")
        ours = python
        departure = ""
        if python is not None:
            true_end = decode(seq + b"A", "utf-8-variants")
            if true_end is None:
                ours = None
                departure = "utf8-variants-trailing-newline"
            elif true_end[:-1] != python or true_end[-1] != "A":
                sys.exit("unexpected: %r decodes differently before a byte" % seq)
            elif "\x00" in python:
                ours = python.replace("\x00", "")
                departure = "decoded-nul-dropped"
        if strict is not None and "\x00" in strict:
            sys.exit("unexpected: U+0000 from %r" % seq)
        lines.append(
            "%s\t%s\t%s\t%s\t%s\n"
            % (seq.hex().upper(), cell(strict), cell(ours), cell(python), departure)
        )
    write_ascii("tests/testthat/reference/decoder_corpus.tsv", "".join(lines))


main()
