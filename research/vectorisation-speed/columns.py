# PROTOTYPE, throwaway. Builds synthetic benchmark columns and times Python
# ftfy 6.3.1 fix_text on each. Run: venv/bin/python -I columns.py <outdir>
# Writes <outdir>/columns/<name>.json (ASCII-escaped list of strings) and
# <outdir>/python_times.json.
import json
import os
import random
import sys
import time

import ftfy
import ftfy.bad_codecs  # noqa: F401  registers sloppy-* codecs

out_dir = sys.argv[1]
os.makedirs(f"{out_dir}/columns", exist_ok=True)

FIRST = [
    "Ana", "José", "François", "Zoë", "Jürgen", "Søren", "Łukasz", "Dvořák", "Ægir",
    "Björk", "Çelik", "Ñuño", "Mária", "Željko", "Ольга", "Дмитрий", "Νίκος",
    "Αλέξανδρος", "İsmail", "Şebnem", "Grzegorz", "Ewa", "Siobhán", "Seán", "Renée",
    "John", "Mary", "David", "Sarah", "Michael", "Emma", "Oliver", "Chloé", "Noël",
    "Aoife", "Øystein", "Håkon", "Anaïs", "Cécile", "Raphaël", "Jérôme", "Müller",
]
LAST = [
    "García", "Müller", "Nowak", "Kowalski", "Smith", "Jones", "O’Brien", "D’Angelo",
    "Schröder", "Brontë", "Pérez", "Novák", "Dvořáková", "Иванов", "Παπαδόπουλος",
    "Yılmaz", "Öztürk", "Taylor", "Brown", "Lévesque", "Hernández", "Wójcik", "Søndergaard",
    "Ní Bhriain", "MacDonald", "Nguyễn", "Lefèvre", "Straße", "Åberg", "Zieliński",
]
NOTE_WORDS = (
    "patient reports mild pain since Tuesday no fever “stable” reviewed by Dr "
    "follow-up in 2 weeks café visit naïve résumé allergic to penicillin – "
    "dose 5 mg twice daily BP 120/80 °C 37.5 µg ½ tablet ✓ referred to clinic"
).split()


def mojibake(s, rng):
    r = rng.random()
    b = s.encode("utf-8")
    if r < 0.6:
        return b.decode("sloppy-windows-1252")
    if r < 0.8:
        return b.decode("latin-1")
    if r < 0.9:
        return b.decode("sloppy-windows-1252").encode("utf-8").decode("sloppy-windows-1252")
    return b.decode("sloppy-windows-1250")


def name(rng):
    return f"{rng.choice(FIRST)} {rng.choice(LAST)}"


def note(rng):
    lines = []
    for _ in range(rng.randint(2, 5)):
        lines.append(" ".join(rng.choice(NOTE_WORDS) for _ in range(rng.randint(8, 20))))
    return "\n".join(lines)


def make(n, clean, unique, gen, seed):
    """n values; `unique` = distinct fraction; `clean` = fraction not mojibaked."""
    rng = random.Random(seed)
    k = max(1, int(n * unique))
    pool, seen = [], set()
    while len(pool) < k:
        v = gen(rng)
        if rng.random() >= clean:
            v = mojibake(v, rng)
        # make values distinct when asked for high uniqueness
        if v in seen:
            v = f"{v} {len(pool)}"
        seen.add(v)
        pool.append(v)
    col = [pool[i % k] for i in range(n)]
    rng.shuffle(col)
    return col


SPECS = {
    # name: (n, clean fraction, unique fraction, generator)
    "names_n1e4": (10_000, 0.95, 0.2, name),
    "names_n1e5": (100_000, 0.95, 0.2, name),
    "names_n1e6": (1_000_000, 0.95, 0.2, name),
    "names_clean100_u20": (100_000, 1.0, 0.2, name),
    "names_clean50_u20": (100_000, 0.5, 0.2, name),
    "names_clean95_u1": (100_000, 0.95, 0.01, name),
    "names_clean95_u100": (100_000, 0.95, 1.0, name),
    "ascii_n1e5": (100_000, 1.0, 0.2, lambda r: f"Patient {r.randint(1, 10**6)}"),
    "notes_n1e4": (10_000, 0.95, 1.0, note),
}
want = sys.argv[2:] or list(SPECS)

times = {}
for i, key in enumerate(want):
    n, clean, unique, gen = SPECS[key]
    col = make(n, clean, unique, gen, seed=i + 1)
    with open(f"{out_dir}/columns/{key}.json", "w", encoding="ascii") as fh:
        json.dump(col, fh, ensure_ascii=True)
    t0 = time.perf_counter()
    fixed = [ftfy.fix_text(x) for x in col]
    t1 = time.perf_counter()
    with open(f"{out_dir}/columns/{key}.python.json", "w", encoding="ascii") as fh:
        json.dump(fixed, fh, ensure_ascii=True)
    times[key] = {"n": n, "clean": clean, "unique": unique, "seconds": t1 - t0,
                  "changed": sum(a != b for a, b in zip(col, fixed))}
    print(key, times[key], flush=True)

with open(f"{out_dir}/python_times.json", "w") as fh:
    json.dump(times, fh, indent=1)
