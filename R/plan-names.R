# Derived from python-ftfy v6.3.1, ftfy/__init__.py and ftfy/chardata.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# The names a step may hold. These four vectors are the only copies in the
# package: `ftfy_plan()` checks plans against them, and the codec tables and
# the replay are keyed by the same names.

# The actions of a step. Upstream's `apply_plan()` knows the first four
# (ftfy/__init__.py:727); `fix_and_explain()` also records `normalize`
# (ftfy/__init__.py:417), which this package replays (ADR 0002).
plan_actions <- c("encode", "decode", "transcode", "apply", "normalize")

# The closed set of 13 codecs (ADR 0003), each under its one name: the ten
# upstream tries, in the order of `CHARMAP_ENCODINGS` (ftfy/chardata.py:15),
# then `windows-1252` (ftfy/__init__.py:565), `utf-8` and `utf-8-variants`.
# An `encode` or `decode` step names one of these.
plan_codecs <- c(
  "latin-1",
  "sloppy-windows-1252",
  "sloppy-windows-1251",
  "sloppy-windows-1250",
  "sloppy-windows-1253",
  "sloppy-windows-1254",
  "sloppy-windows-1257",
  "iso-8859-2",
  "macroman",
  "cp437",
  "windows-1252",
  "utf-8",
  "utf-8-variants"
)

# The fixers a `transcode` or `apply` step may name: upstream's `FIXERS`
# (ftfy/__init__.py:75) in its order, without `fix_surrogates`, which is not
# ported. Upstream accepts every name with either action, and records
# `transcode fix_c1_controls` although that fixer works on text
# (ftfy/__init__.py:573), so the two actions share one list.
plan_fixers <- c(
  "unescape_html",
  "remove_terminal_escapes",
  "restore_byte_a0",
  "replace_lossy_sequences",
  "decode_inconsistent_utf8",
  "fix_c1_controls",
  "fix_latin_ligatures",
  "fix_character_width",
  "uncurl_quotes",
  "fix_line_breaks",
  "remove_control_chars"
)

# The normalisation forms a `normalize` step may name: the values of the
# `normalization` option other than "none".
plan_normalizations <- c("NFC", "NFD", "NFKC", "NFKD")
