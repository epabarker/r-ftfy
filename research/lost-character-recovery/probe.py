"""Lost-character recovery: how often can a lossy value be matched to an intact
value elsewhere in the same column, and how often is the match wrong?

Run: uv run --python 3.13 --with ftfy==6.3.1 python probe.py > output.txt

Columns are drawn with repetition (Zipf weights over a language's distinct
values), so a lossy row can have an intact twin: an uncorrupted row of the same
clean value, or a row of the same value that the corruption did not damage.

Loss kinds
- fffd: UTF-8 bytes decoded with a codec that has holes, errors="replace";
  per-value encoding repair leaves U+FFFD where a character was lost.
- qmark: clean text encoded to a narrower codec with errors="replace", so each
  unrepresentable character became "?"; no mojibake, fix_text leaves it.
- a0: UTF-8 read as windows-1252 with every NBSP then turned into a space.

Matching rule (the one under test): candidates are distinct values in the column
that, after per-value repair, contain no loss marker, have the same length, equal
the lossy value at every non-site position, and carry a non-ASCII character at
every site. Variant "holes" (fffd only) also requires each site's character to
have a UTF-8 byte that is a hole of the column's codec.
"""
import random
import sys
from collections import Counter

import ftfy
import ftfy.bad_codecs  # noqa
from ftfy import fix_encoding, fix_text

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from words import LANGS, build_values  # noqa: E402

FFFD = "�"
HOLED = ["windows-1252", "windows-1250", "windows-1251", "windows-1253", "windows-1254"]
QMARK = {  # language group -> narrow export codec
    "Western": ["ascii"], "Central": ["latin-1", "windows-1252"],
    "Cyrillic": ["latin-1"], "Greek": ["latin-1"], "Turkish": ["latin-1"],
}
# Minimal pairs: real names/words that differ in one non-ASCII letter only.
PAIRS = ["José", "Josè", "Müller", "Möller", "Mäller", "Göran", "Gøran", "Ångström",
         "Angström", "Léa", "Léo", "Zoé", "Zoë", "Hélène", "Hélèna", "Renée", "Renéé",
         "Ébène", "Èbène", "Ónix", "Ònix", "Íñigo", "Ìñigo", "Ýmir", "Ümir",
         "ÁLVARO", "ÄLVARO", "ÍÑIGO", "ÏÑIGO", "ÐÓRA", "ÞÓRA", "Šárka", "Šárko",
         "Łódź", "Łódż", "Ńowak", "Nowák"]


def holes(codec):
    return {b for b in range(256) if _fails(bytes([b]), codec)}


def _fails(b, codec):
    try:
        b.decode(codec)
        return False
    except UnicodeDecodeError:
        return True


def corrupt(kind, s, codec):
    if kind == "fffd":
        return s.encode("utf-8").decode(codec, errors="replace")
    if kind == "qmark":
        return s.encode(codec, errors="replace").decode(codec)
    if kind == "a0":
        return s.encode("utf-8").decode("sloppy-windows-1252").replace("\xa0", " ")
    raise ValueError(kind)


def column(pool, n, p, kind, codec, rng):
    w = [1 / (i + 1) for i in range(len(pool))]
    clean = rng.choices(pool, weights=w, k=n)
    return [(s, corrupt(kind, s, codec) if rng.random() < p else s) for s in clean]


def reachable(kind, s, codec):
    """The reachable target: each destroyed character becomes the marker left."""
    if kind == "fffd":
        H = holes(codec)
        return "".join(FFFD if set(ch.encode("utf-8")) & H else ch for ch in s)
    if kind == "qmark":
        return s.encode(codec, errors="replace").decode(codec)
    return s  # a0: nothing is destroyed in principle


def match(lossy, marker, intact, H=None):
    sites = [i for i, ch in enumerate(lossy) if ch == marker]
    out = []
    for c in intact:
        if len(c) != len(lossy):
            continue
        if any(c[i] != lossy[i] for i in range(len(c)) if i not in sites):
            continue
        if not all(not c[i].isascii() for i in sites):
            continue
        if H is not None and not all(set(c[i].encode("utf-8")) & H for i in sites):
            continue
        out.append(c)
    return out


def run(kind, label, pool, codec, rng, tally, examples):
    H = holes(codec) if kind == "fffd" else None
    for n in (100, 1000):
        for p in (0.1, 0.5, 0.9):
            rows = column(pool, n, p, kind, codec, rng)
            repair = fix_encoding if kind != "a0" else fix_text
            fixed = {c: repair(c) for _, c in rows}
            truth = {}
            for s, c in rows:
                truth.setdefault(c, s)
            marker = FFFD if kind == "fffd" else "?"
            intact = {o for o in fixed.values() if marker not in o}
            key = (kind, label, codec)
            for c, s in truth.items():
                o = fixed[c]
                if kind == "a0":
                    if c != s:
                        tally[key]["a0 rows"] += 1
                        tally[key]["a0 fix_text repairs" if o == s else "a0 left"] += 1
                        if o != s:
                            examples.append((key, "a0 left", s, c, o))
                    continue
                if c == s and marker in s:
                    # clean values with a literal "?" are the false-trigger risk
                    if True:
                        m = match(o, marker, intact - {o})
                        tally[key]["literal ? values"] += 1
                        if m:
                            tally[key]["literal ? matched"] += 1
                            examples.append((key, "literal", s, m[:3]))
                    continue
                if marker not in o:
                    continue
                tally[key]["lossy"] += 1
                if o != reachable(kind, s, codec):
                    tally[key]["not reachable target"] += 1
                    if len(examples) < 2000:
                        examples.append((key, "unreachable", s, o, reachable(kind, s, codec)))
                for vname, h in (("plain", None), ("holes", H)) if H else (("plain", None),):
                    m = match(o, marker, intact - {o}, h)
                    if not m:
                        r = "none"
                    elif len(m) == 1:
                        r = "unique right" if m[0] == s else "unique WRONG"
                    else:
                        r = "several (truth in)" if s in m else "several (truth out)"
                    tally[key][f"{vname}: {r}"] += 1
                    if r in ("unique WRONG", "several (truth in)") and len(examples) < 400:
                        examples.append((key, vname, s, o, m[:4]))


def main():
    rng = random.Random(20261113)
    print(f"ftfy {ftfy.__version__}; python {sys.version.split()[0]}")
    tally = {}
    examples = []
    jobs = []
    for lang, (group, words) in LANGS.items():
        base = list(dict.fromkeys(build_values(words)))
        pool = base + [v.upper() for v in base[:100]]  # all-caps fields hit more holes
        rng.shuffle(pool)
        for codec in HOLED:
            jobs.append(("fffd", lang, pool, codec))
        for codec in QMARK[group]:
            jobs.append(("qmark", lang, pool, codec))
        if group == "Western":
            jobs.append(("a0", lang, pool, "windows-1252"))
    pairs_pool = PAIRS * 3
    for codec in HOLED:
        jobs.append(("fffd", "pairs", pairs_pool, codec))
    jobs.append(("qmark", "pairs", pairs_pool, "ascii"))
    for kind, label, pool, codec in jobs:
        tally.setdefault((kind, label, codec), Counter())
        run(kind, label, pool, codec, rng, tally, examples)

    print("\n== per column family (distinct lossy values, summed over n in {100,1000}, p in {.1,.5,.9})")
    agg = {}
    for key, c in tally.items():
        if not c:
            continue
        print(key, dict(sorted(c.items())))
        fam = (key[0], "pairs" if key[1] == "pairs" else "words")
        agg.setdefault(fam, Counter()).update(c)
    print("\n== totals")
    for fam, c in sorted(agg.items()):
        print(fam)
        for k, v in sorted(c.items()):
            print(f"    {k:28s} {v}")
    print("\n== examples (wrong or ambiguous)")
    seen = set()
    for e in examples:
        t = repr(e)
        if t in seen:
            continue
        seen.add(t)
        print(t)


if __name__ == "__main__":
    main()
