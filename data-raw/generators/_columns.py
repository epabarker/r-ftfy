# Derived from python-ftfy v6.3.1, ftfy/. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""The benchmark-column generator. Not a generator script: bench_columns.py
writes the committed benchmark columns with it, and corpus_inputs.py builds
part of the larger corpus from the same values.

It is the generator of the prototype (columns.py on the branch
research/vectorisation-speed) with its nine column specifications and their
seeds unchanged, so that a column here holds the values the prototype
timed. What is gone is the timing of the reference version, which is not
reproducible and belongs to the bench, and the shuffle of each column
(see bench_columns.py).

All the text is our own: a few names and the words of an invented clinical
note. Nothing here comes from outside text.
"""

import random

FIRST = [
    "Ana", "Jos\xe9", "Fran\xe7ois", "Zo\xeb", "J\xfcrgen", "S\xf8ren",
    "\u0141ukasz", "Dvo\u0159\xe1k", "\xc6gir", "Bj\xf6rk", "\xc7elik",
    "\xd1u\xf1o", "M\xe1ria", "\u017deljko",
    "\u041e\u043b\u044c\u0433\u0430",
    "\u0414\u043c\u0438\u0442\u0440\u0438\u0439",
    "\u039d\u03af\u03ba\u03bf\u03c2",
    "\u0391\u03bb\u03ad\u03be\u03b1\u03bd\u03b4\u03c1\u03bf\u03c2",
    "\u0130smail", "\u015eebnem", "Grzegorz", "Ewa", "Siobh\xe1n",
    "Se\xe1n", "Ren\xe9e", "John", "Mary", "David", "Sarah", "Michael",
    "Emma", "Oliver", "Chlo\xe9", "No\xebl", "Aoife", "\xd8ystein",
    "H\xe5kon", "Ana\xefs", "C\xe9cile", "Rapha\xebl", "J\xe9r\xf4me",
    "M\xfcller",
]
LAST = [
    "Garc\xeda", "M\xfcller", "Nowak", "Kowalski", "Smith", "Jones",
    "O\u2019Brien", "D\u2019Angelo", "Schr\xf6der", "Bront\xeb", "P\xe9rez",
    "Nov\xe1k", "Dvo\u0159\xe1kov\xe1",
    "\u0418\u0432\u0430\u043d\u043e\u0432",
    "\u03a0\u03b1\u03c0\u03b1\u03b4\u03cc\u03c0\u03bf\u03c5\u03bb\u03bf\u03c2",
    "Y\u0131lmaz", "\xd6zt\xfcrk", "Taylor", "Brown", "L\xe9vesque",
    "Hern\xe1ndez", "W\xf3jcik", "S\xf8ndergaard", "N\xed Bhriain",
    "MacDonald", "Nguy\u1ec5n", "Lef\xe8vre", "Stra\xdfe", "\xc5berg",
    "Zieli\u0144ski",
]
NOTE_WORDS = [
    "patient", "reports", "mild", "pain", "since", "Tuesday", "no", "fever",
    "\u201cstable\u201d", "reviewed", "by", "Dr", "follow-up", "in", "2",
    "weeks", "caf\xe9", "visit", "na\xefve", "r\xe9sum\xe9", "allergic",
    "to", "penicillin", "\u2013", "dose", "5", "mg", "twice", "daily", "BP",
    "120/80", "\xb0C", "37.5", "\xb5g", "\xbd", "tablet", "\u2713",
    "referred", "to", "clinic",
]


def mojibake(text, rng):
    """One of four mix-ups of UTF-8 text, as the prototype drew them."""
    draw = rng.random()
    data = text.encode("utf-8")
    if draw < 0.6:
        return data.decode("sloppy-windows-1252")
    if draw < 0.8:
        return data.decode("latin-1")
    if draw < 0.9:
        once = data.decode("sloppy-windows-1252")
        return once.encode("utf-8").decode("sloppy-windows-1252")
    return data.decode("sloppy-windows-1250")


def name(rng):
    return "%s %s" % (rng.choice(FIRST), rng.choice(LAST))


def note(rng):
    lines = []
    for _ in range(rng.randint(2, 5)):
        lines.append(
            " ".join(rng.choice(NOTE_WORDS) for _ in range(rng.randint(8, 20)))
        )
    return "\n".join(lines)


def patient(rng):
    return "Patient %d" % rng.randint(1, 10**6)


def pool(n, clean, unique, gen, rng):
    """The distinct values of a column, in the order they were drawn.
    `unique` is the fraction of distinct values and `clean` the fraction
    that is not a mix-up."""
    k = max(1, int(n * unique))
    values, seen = [], set()
    while len(values) < k:
        value = gen(rng)
        if rng.random() >= clean:
            value = mojibake(value, rng)
        # A value drawn before is made distinct by a number.
        if value in seen:
            value = "%s %d" % (value, len(values))
        seen.add(value)
        values.append(value)
    return values


# name: (n, clean fraction, distinct fraction, generator). The seed of a
# column is its place in this list, counted from 1.
SPECS = {
    "names_n1e4": (10_000, 0.95, 0.2, name),
    "names_n1e5": (100_000, 0.95, 0.2, name),
    "names_n1e6": (1_000_000, 0.95, 0.2, name),
    "names_clean100_u20": (100_000, 1.0, 0.2, name),
    "names_clean50_u20": (100_000, 0.5, 0.2, name),
    "names_clean95_u1": (100_000, 0.95, 0.01, name),
    "names_clean95_u100": (100_000, 0.95, 1.0, name),
    "ascii_n1e5": (100_000, 1.0, 0.2, patient),
    "notes_n1e4": (10_000, 0.95, 1.0, note),
}


def seed_of(column):
    return list(SPECS).index(column) + 1


def distinct_values(column):
    """The distinct values of a column, in the order they were drawn. The
    column is these recycled to its n."""
    n, clean, unique, gen = SPECS[column]
    return pool(n, clean, unique, gen, random.Random(seed_of(column)))
