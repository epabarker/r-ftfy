"""Select the outside text of the larger corpus (ticket #45) and write it to
data-raw/outside/values.tsv.xz.

Run by a maintainer, never by the `reference` workflow, with the reference
interpreter (Python 3.13), from the root of the repository:

    python data-raw/outside/select.py --downloads <empty directory outside the repo>

This is the only script that downloads anything. It fetches the files
listed in pins.tsv beside it, each a pinned version of a source named in
SOURCES, into the directory given (a file already there is used again),
and stops with an error, writing nothing, if any file's SHA-256 is not
the one pinned. It then selects values from them with a fixed seed, so
that a rerun on the same files writes the same values byte for byte.
`--pin` instead downloads every file the script reads and writes its
checksum to pins.tsv; a maintainer does that only to move to a new
version of a source, and reviews what it downloaded.

The values file is committed. data-raw/generators/corpus_inputs_outside.py
builds the inputs of the slice `outside` from it with no network access,
and corpus_snapshot.py the snapshot. The columns of the values file, tab
separated:

- source: the Id of the source in SOURCES.
- language: the language of the value, as a CLDR locale code ("und" for
  the emoji themselves).
- kind: what the value is (see KINDS).
- text: the value, escaped (see _reference.escape).

Only values with a character outside ASCII are kept: an ASCII value says
nothing about encoding. A value holding a character that Unicode 15.1 has
not assigned is left out, since what the reference version does with it
is not reference behaviour (data-raw/unicode/age.txt says which are
assigned). Nothing from python-ftfy is used here.
"""

import argparse
import hashlib
import json
import os
import random
import sys
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "generators"))

from _corpus import age  # noqa: E402
from _reference import REPO, escape, storable  # noqa: E402
from _xz import write_xz  # noqa: E402

SEED = 45
PINS = os.path.join(HERE, "pins.tsv")
VALUES = "data-raw/outside/values.tsv.xz"
COLUMNS = ["source", "language", "kind", "text"]

# Unicode CLDR, as JSON, at the release whose Unicode version is the
# reference interpreter's (15.1).
CLDR_VERSION = "44.1.0"
CLDR_BASE = "https://raw.githubusercontent.com/unicode-org/cldr-json/%s/cldr-json/" % CLDR_VERSION

# The locales, by the groups of the resolution of #15: Western European,
# Central European, Cyrillic, Greek, Turkish, Baltic, and CJK, Arabic and
# Hebrew as clean controls.
LOCALES = [
    "fr", "de", "es", "it", "pt", "nl", "sv", "da", "no", "fi", "is",
    "pl", "cs", "hu", "ro", "hr", "sk", "sl",
    "ru", "uk", "bg", "sr",
    "el",
    "tr",
    "lt", "lv", "et",
    "ja", "zh", "ko", "ar", "he",
]

# How many values of each kind are taken from each locale or book.
KINDS = {
    "territory": 15,  # the name of a territory (CLDR)
    "language": 10,  # the name of a language (CLDR)
    "month": 10,  # the name of a month, wide or abbreviated (CLDR)
    "weekday": 6,  # the name of a day of the week (CLDR)
    "emoji-name": 25,  # the name of an emoji (CLDR annotations)
    "emoji": 150,  # an emoji itself, from all locales together (CLDR)
    "prose": 45,  # a paragraph of a book on one line (Project Gutenberg)
    "paragraph": 15,  # a paragraph with its line breaks (Project Gutenberg)
}

# Project Gutenberg books, each in its original language, released by
# Project Gutenberg as public domain in the US, by an author who died
# before 1940, so also public domain where copyright lasts life plus 70
# years. No translations. SOURCES lists them with their authors.
BOOKS = [
    (798, "fr"),  # Stendhal, Le rouge et le noir
    (22367, "de"),  # Franz Kafka, Die Verwandlung
    (2000, "es"),  # Miguel de Cervantes, Don Quijote
    (45334, "it"),  # Alessandro Manzoni, I promessi sposi
    (55752, "pt"),  # Machado de Assis, Dom Casmurro
    (27729, "pl"),  # Adam Mickiewicz, Bajki
    (13083, "cs"),  # Karel Capek, R.U.R.
    (27685, "hu"),  # Gergely Csiky, Az Atlasz-csalad
    (64597, "ro"),  # I. L. Caragiale, Nuvele
    (34126, "sl"),  # Ivan Cankar, Za narodov blagor
    (5316, "ru"),  # Aleksandr Pushkin, a poem
    (14741, "ru"),  # Gavriil Derzhavin, Dukhovnye ody
    (15008, "sr"),  # Branislav Nusic, Svet
    (27301, "el"),  # Emmanouel Rhoides, Syriana diegemata
]
GUTENBERG_URL = "https://www.gutenberg.org/cache/epub/%d/pg%d.txt"


def files():
    """Every file the script reads, as (source, url), in a fixed order."""
    out = []
    for locale in LOCALES:
        for part in (
            "cldr-localenames-full/main/%s/territories.json",
            "cldr-localenames-full/main/%s/languages.json",
            "cldr-dates-full/main/%s/ca-gregorian.json",
            "cldr-annotations-full/annotations/%s/annotations.json",
        ):
            out.append(("cldr", CLDR_BASE + part % locale))
    for number, _ in BOOKS:
        out.append(("gutenberg", GUTENBERG_URL % (number, number)))
    return out


# ------------------------------------------------------------ downloading


def read_pins():
    with open(PINS, encoding="ascii") as handle:
        lines = handle.read().splitlines()
    assert lines[0] == "source\turl\tsha256", lines[0]
    pins = {}
    for line in lines[1:]:
        source, url, sha256 = line.split("\t")
        pins[url] = (source, sha256)
    return pins


def write_pins(found):
    with open(PINS, "w", encoding="ascii", newline="\n") as handle:
        handle.write("source\turl\tsha256\n")
        for source, url, sha256 in found:
            handle.write("%s\t%s\t%s\n" % (source, url, sha256))
    print("wrote", os.path.relpath(PINS, REPO))


def local_name(url):
    return hashlib.sha256(url.encode("ascii")).hexdigest()[:16] + "-" + url.rsplit("/", 1)[1]


def fetch(url, downloads):
    """The bytes of a file: from the downloads directory if it is there,
    else downloaded into it."""
    path = os.path.join(downloads, local_name(url))
    if not os.path.exists(path):
        request = urllib.request.Request(url, headers={"User-Agent": "corpus-selection-script"})
        with urllib.request.urlopen(request, timeout=120) as response:
            data = response.read()
        with open(path, "wb") as handle:
            handle.write(data)
        if "gutenberg.org" in url:
            time.sleep(2)
    with open(path, "rb") as handle:
        return handle.read()


class ChecksumMismatch(Exception):
    pass


def verified(url, data, pins):
    """The bytes, if their checksum is the pinned one."""
    if url not in pins:
        raise ChecksumMismatch("%s is not pinned in pins.tsv" % url)
    found = hashlib.sha256(data).hexdigest()
    if found != pins[url][1]:
        raise ChecksumMismatch(
            "checksum mismatch for %s: pinned %s, downloaded %s" % (url, pins[url][1], found)
        )
    return data


# -------------------------------------------------------------- selecting


def keep(text):
    """Whether a value may be in the corpus."""
    return (
        bool(text)
        and not text.isascii()
        and storable(text)
        and all(age(ord(ch)) is not None for ch in text)
    )


def sample(rng, candidates, count):
    candidates = sorted(set(candidate for candidate in candidates if keep(candidate)))
    return rng.sample(candidates, min(count, len(candidates)))


def names_of(table):
    return [value for key, value in sorted(table.items()) if "-alt-" not in key]


def cldr_values(locale, documents, rng):
    territories, languages, calendar, annotations = documents
    names = territories["main"][locale]["localeDisplayNames"]
    out = [("territory", value) for value in sample(rng, names_of(names["territories"]), KINDS["territory"])]
    names = languages["main"][locale]["localeDisplayNames"]
    out += [("language", value) for value in sample(rng, names_of(names["languages"]), KINDS["language"])]
    gregorian = calendar["main"][locale]["dates"]["calendars"]["gregorian"]
    for kind, key in (("month", "months"), ("weekday", "days")):
        found = []
        for context in ("format", "stand-alone"):
            for width in ("abbreviated", "wide"):
                found += list(gregorian[key][context][width].values())
        out += [(kind, value) for value in sample(rng, found, KINDS[kind])]
    table = annotations["annotations"]["annotations"]
    found = [entry["tts"][0] for _, entry in sorted(table.items()) if entry.get("tts")]
    out += [("emoji-name", value) for value in sample(rng, found, KINDS["emoji-name"])]
    return out


def emoji_of(annotations):
    """The emoji among the keys of an annotations file: those with a
    character outside the Basic Multilingual Plane or a variation
    selector."""
    return [
        key for key in annotations["annotations"]["annotations"]
        if any(ord(ch) > 0xFFFF or ch == "\ufe0f" for ch in key)
    ]


def book_text(data):
    """The text of a Project Gutenberg file between its start and end
    markers, with LF line ends: nothing of Project Gutenberg's own."""
    text = data.decode("utf-8")
    text = text.lstrip("\ufeff").replace("\r\n", "\n").replace("\r", "\n")
    lines = text.split("\n")
    start = [at for at, line in enumerate(lines) if line.startswith("*** START OF")]
    end = [at for at, line in enumerate(lines) if line.startswith("*** END OF")]
    assert len(start) == 1 and len(end) == 1 and start[0] < end[0], (start, end)
    return "\n".join(lines[start[0] + 1 : end[0]])


# Paragraphs near the markers that are about the edition, not the book.
EDITION_WORDS = ("gutenberg", "produced by", "proofread", "http", "www.", "e-text", "ebook", "transcriber")


def paragraphs(text):
    out = []
    for block in text.split("\n\n"):
        lines = [line.rstrip() for line in block.strip("\n").split("\n")]
        lines = [line for line in lines if line.strip()]
        if not lines:
            continue
        if any(word in block.lower() for word in EDITION_WORDS):
            continue
        out.append(lines)
    return out


def book_values(data, rng):
    found = paragraphs(book_text(data))
    prose = [" ".join(line.strip() for line in lines) for lines in found]
    prose = [text for text in prose if 20 <= len(text) <= 400]
    several = ["\n".join(lines) for lines in found if 2 <= len(lines) <= 8]
    several = [text for text in several if len(text) <= 800]
    out = [("prose", value) for value in sample(rng, prose, KINDS["prose"])]
    out += [("paragraph", value) for value in sample(rng, several, KINDS["paragraph"])]
    return out


def select(documents):
    """The rows of the values file, from the parsed files by url."""
    rows = []
    seen = set()

    def add(source, language, kind, text):
        if text not in seen:
            seen.add(text)
            rows.append((source, language, kind, text))

    emoji = []
    for locale in LOCALES:
        urls = [url for source, url in files() if source == "cldr" and "/%s/" % locale in url]
        parsed = [json.loads(documents[url].decode("utf-8")) for url in urls]
        rng = random.Random("%d:cldr:%s" % (SEED, locale))
        for kind, text in cldr_values(locale, parsed, rng):
            add("cldr", locale, kind, text)
        emoji += emoji_of(parsed[3])
    rng = random.Random("%d:cldr:emoji" % SEED)
    for text in sample(rng, emoji, KINDS["emoji"]):
        add("cldr", "und", "emoji", text)
    for number, language in BOOKS:
        rng = random.Random("%d:gutenberg:%d" % (SEED, number))
        for kind, text in book_values(documents[GUTENBERG_URL % (number, number)], rng):
            add("gutenberg", language, kind, text)
    return rows


def write_values(rows):
    lines = ["\t".join(COLUMNS) + "\n"]
    for source, language, kind, text in rows:
        assert kind in KINDS
        lines.append("\t".join([source, language, kind, escape(text)]) + "\n")
    write_xz(VALUES, "".join(lines))
    counts = {}
    for source, language, _, _ in rows:
        counts[(source, language)] = counts.get((source, language), 0) + 1
    for key in sorted(counts):
        print("%6d %s %s" % (counts[key], key[0], key[1]))
    print("%6d values" % len(rows))


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--downloads", required=True, help="a directory outside the repository")
    parser.add_argument("--pin", action="store_true", help="write pins.tsv from what is downloaded")
    args = parser.parse_args()
    downloads = os.path.abspath(args.downloads)
    if os.path.commonpath([downloads, REPO]) == REPO:
        sys.exit("the downloads directory must be outside the repository")
    os.makedirs(downloads, exist_ok=True)

    wanted = files()
    if args.pin:
        found = []
        for source, url in wanted:
            found.append((source, url, hashlib.sha256(fetch(url, downloads)).hexdigest()))
        write_pins(found)
        return
    pins = read_pins()
    extra = set(pins) - {url for _, url in wanted}
    if extra:
        sys.exit("pins.tsv pins files the script does not read: %s" % ", ".join(sorted(extra)))
    documents = {}
    try:
        for source, url in wanted:
            documents[url] = verified(url, fetch(url, downloads), pins)
    except ChecksumMismatch as error:
        sys.exit("stopped, nothing written: %s" % error)
    write_values(select(documents))


if __name__ == "__main__":
    main()
