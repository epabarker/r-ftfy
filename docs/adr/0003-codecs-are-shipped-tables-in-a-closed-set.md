# Codecs are shipped tables in a closed set, with no ICU at runtime

Every single-byte codec the package uses is a 256-entry table generated from Python ftfy 6.3.1 and shipped as package data; no stringi or ICU converter is called for any of them. `ftfy_plan()` and `apply_plan()` accept exactly 13 codecs, the ones ftfy itself can emit, and any other codec name is an error: `latin-1`, `sloppy-windows-1252`, `sloppy-windows-1251`, `sloppy-windows-1250`, `sloppy-windows-1253`, `sloppy-windows-1254`, `sloppy-windows-1257`, `iso-8859-2`, `macroman`, `cp437`, `windows-1252`, `utf-8` and `utf-8-variants`.

The package depends on stringi, so using its converters looks like the obvious choice. It was measured and does not work: ICU matches CPython's tables for only three of the ten encodings ftfy tries (`latin-1`, `iso-8859-2`, `macroman`), cannot reproduce strict `windows-1252` or `utf-8-variants` at all, warns where Python fails, and silently drops about 4,170 characters when encoding, a list that changes with the ICU version. The ICU a user gets varies by platform (71.1 in the CRAN macOS binary, 74.1 in stringi's bundle, anything from 61 up on Linux). CPython's tables have not changed since 2007 and are the same everywhere.

Decided in https://github.com/epabarker/r-ftfy/issues/10. Measurements: `research/codecs-vs-icu.md` on branch `research/codecs-vs-icu`.

## Considered options

- **ICU for the three matching encodings, tables for the rest.** Rejected: it saves three small tables and keeps ICU's encode-side behaviour (warnings instead of failures, dropped characters) on those three.
- **An ICU fallback for codec names outside the set**, so that `apply_plan()` accepts any codec as Python's does. Rejected: results there could not be promised to match Python or to be the same on every platform. A plan naming another codec fails loudly instead.
- **Shipping upstream's nine other sloppy codecs** (`sloppy-windows-1255`, `-1256`, `-1258`, `cp874` and five ISO-8859 variants). Rejected for now: ftfy never uses them for fixing. Adding a codec later breaks nothing; removing one would.

## Consequences

- Codec names are accepted only in their canonical spelling, case-sensitive. `latin1`, `cp1252` and `cesu-8` are errors, although Python accepts them. A plan's identity is its text form, so each codec has one name.
- All 13 codecs work in both `encode` and `decode` steps. Encoding to `utf-8-variants` produces plain UTF-8, as upstream does.
- The set of characters an encoding can produce, which decides whether it is a candidate for a repair, is derived from the same shipped table as the encode step. Do not hand-copy those sets: one source is what guarantees the encode step cannot fail once the check has passed.
- Strict `utf-8` decoding is a validity check with `stri_enc_isutf8()` followed by marking the bytes as UTF-8; this is a validity test, not an ICU converter. `utf-8-variants` is a rewrite of the bytes in front of the same check.
- Tables are regenerated only by a maintainer running a Python script by hand. Python is never needed to build, install or test the package.
