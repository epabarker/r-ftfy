# Derived from python-ftfy v6.3.1, ftfy/bad_codecs/sloppy.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.
"""What the selection of the outside text (data-raw/outside/select.py) and
the generator of its slice (corpus_inputs_outside.py) share. Not a
generator, and it imports nothing from python-ftfy, so that select.py
does not either.
"""

WESTERN = ["sloppy-windows-1252", "latin-1"]
WESTERN_OTHER = ["windows-1252", "macroman", "cp437"]

# The languages, as CLDR locale codes, by the groups of the resolution of
# #15: Western European, Central European, Cyrillic, Greek, Turkish,
# Baltic, and CJK, Arabic and Hebrew as clean controls; "und" is the emoji
# themselves. With each group, the codecs its text is most often read with
# by mistake, and the others it is sometimes read with.
REGIONS = [
    (("fr", "de", "es", "it", "pt", "nl", "sv", "da", "no", "fi", "is"), WESTERN, WESTERN_OTHER),
    (("pl", "cs", "hu", "ro", "hr", "sk", "sl"), ["sloppy-windows-1250", "iso-8859-2"], WESTERN),
    (("ru", "uk", "bg", "sr"), ["sloppy-windows-1251"], WESTERN),
    (("el",), ["sloppy-windows-1253"], WESTERN),
    (("tr",), ["sloppy-windows-1254"], WESTERN),
    (("lt", "lv", "et"), ["sloppy-windows-1257"], WESTERN),
    (("ja", "zh", "ko", "ar", "he", "und"), WESTERN, ["macroman", "sloppy-windows-1251"]),
]

# The CLDR locales select.py reads, in the order it reads them.
LOCALES = [language for languages, _, _ in REGIONS for language in languages if language != "und"]
