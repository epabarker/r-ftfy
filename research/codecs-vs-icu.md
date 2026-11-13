# Upstream custom codecs versus stringi and ICU

Research for issue #4. Question: which codecs does Python ftfy v6.3.1 rely on, and where would
stringi/ICU differ, so that the codec-table decision (generate from Python and ship as data, rely
on ICU at runtime, or a mix) can be made.

## Answer in brief

ICU through stringi cannot be the runtime source of truth for any codec ftfy uses for fixing.
Ship the single-byte tables as data generated from CPython, and write the `utf-8-variants`
decoder by hand in R.

- Of the ten single-byte encodings ftfy tries, ICU matches CPython exactly on only three:
  `latin-1`, `iso-8859-2` and `macroman`. Even for those, stringi reports an unencodable
  character only as a warning, and it drops some characters from the output instead of
  substituting them.
- ICU's `cp437` table differs from CPython's at four bytes (1A, 1C, 7F, E6).
- ICU's Windows-125x tables already fill most holes the way ftfy's sloppy codecs do, but not
  all of them (1253: D2, FF; 1257: A1, A5), and none of them map byte 1A to U+FFFD.
- Neither ICU's `UTF-8` nor its `CESU-8` converter behaves like `utf-8-variants`.
- stringi has no strict mode: it substitutes and warns where Python raises. A port could turn
  those warnings into errors, but for the Windows-125x hole bytes stringi gives no warning at
  all, so strict `windows-1252` decoding cannot be recovered that way.
- The tables are tiny and frozen: the CPython charmap files involved have not changed since
  2007.

## How to read this document

Every claim is tagged with where it comes from.

- **[source]**: read from the ftfy v6.3.1 source (commit `5340af6`), cited as `path:line`. No
  ftfy code was executed or installed.
- **[derived]**: worked out by hand from that source. Nobody ran it. Treat as a prediction to
  confirm against real ftfy in a parity test.
- **[measured]**: an experiment on one machine, described in "Measurement setup" below.
- **[docs]**: from documentation or third-party source code, with a link.

### Measurement setup and its limits

- One machine: macOS arm64.
- CPython 3.9.6 (Apple's system `python3`, run as `python3 -I`, standard library only).
- R 4.6.2 with stringi 1.8.7 (CRAN binary), which reports ICU 71.1.
- Homebrew `uconv` from ICU 78.3 and ICU 79.1, used only to repeat the decode comparison.

Not measured: Windows, Linux, stringi's bundled ICU 74.1, any ICU older than 71. Encode behaviour
was measured on ICU 71.1 only. Byte 00 was not measured through stringi at all, because an R
string cannot hold U+0000 (see "The NUL problem").

## 1. Which codecs ftfy v6.3.1 uses

### 1.1 Encodings tried when fixing mojibake

`CHARMAP_ENCODINGS` (`ftfy/chardata.py:15`), in this order **[source]**:

| # | ftfy name | CPython codec behind it | Holes in the CPython codec |
|---|-----------|-------------------------|----------------------------|
| 1 | `latin-1` | `iso8859-1` | none |
| 2 | `sloppy-windows-1252` | `cp1252` + sloppy rule | 81 8D 8F 90 9D |
| 3 | `sloppy-windows-1251` | `cp1251` + sloppy rule | 98 |
| 4 | `sloppy-windows-1250` | `cp1250` + sloppy rule | 81 83 88 90 98 |
| 5 | `sloppy-windows-1253` | `cp1253` + sloppy rule | 81 88 8A 8C 8D 8E 8F 90 98 9A 9C 9D 9E 9F AA D2 FF |
| 6 | `sloppy-windows-1254` | `cp1254` + sloppy rule | 81 8D 8E 8F 90 9D 9E |
| 7 | `sloppy-windows-1257` | `cp1257` + sloppy rule | 81 83 88 8A 8C 90 98 9A 9C 9F A1 A5 |
| 8 | `iso-8859-2` | `iso8859-2` | none |
| 9 | `macroman` | `mac-roman` | none |
| 10 | `cp437` | `cp437` | none |

Hole lists are **[measured]** on CPython 3.9.6.

These names are used in two ways **[source]**:

- To build one regex per encoding of "characters this encoding can produce"
  (`ftfy/chardata.py:42-55`). The character class is ASCII 00-19 and 1B-7F, plus whatever bytes
  80-FF and byte 1A decode to in that encoding.
- To encode text back to bytes (`ftfy/__init__.py:496`), only after that regex has matched. So
  inside `fix_encoding` the encode step never meets an unencodable character.

### 1.2 Every other codec call

| Call site | Codec | Mode | Note |
|-----------|-------|------|------|
| `ftfy/__init__.py:535` | `utf-8` or `utf-8-variants` | strict decode | `utf-8-variants` is chosen when the bytes contain ED or C0 (`:530`). A `UnicodeDecodeError` means "try the next encoding". |
| `ftfy/__init__.py:561` | `latin-1` encode, then `windows-1252` decode | strict | The non-sloppy cp1252. Raises on 81 8D 8F 90 9D, and ftfy catches that. |
| `ftfy/fixes.py:502` | `latin-1` encode, then `sloppy-windows-1252` decode | strict | `fix_c1_controls`, applied to U+0080-U+009F only. |
| `ftfy/fixes.py:478` | `"�".encode()` | UTF-8 | Constant bytes EF BF BD. |
| `ftfy/__init__.py:688` | `utf-16` | strict decode | `guess_bytes`, only when the input starts with a BOM. Not inside the `try`, so errors propagate. |
| `ftfy/__init__.py:714,716` | `utf-8-variants`, `utf-8` | strict decode | `guess_bytes`. |
| `ftfy/__init__.py:722` | `macroman` | strict decode | `guess_bytes`, when the bytes have CR but no LF. Never fails (no holes). |
| `ftfy/__init__.py:724` | `sloppy-windows-1252` | strict decode | `guess_bytes` last resort. Never fails. |
| `ftfy/__init__.py:754,756` | any name in the plan | strict | `apply_plan`. A caller-supplied plan can name any codec and can hit encode or decode errors. |
| `ftfy/__init__.py:648`, `ftfy/cli.py` | any name given by the caller (`-e`) | strict decode | `fix_file`. Open-ended: whatever Python supports. |
| `ftfy/fixes.py:388` | `unicode-escape` | decode | `decode_escapes`. Not an ICU matter; needs its own port. |
| `ftfy/__init__.py:794`, `ftfy/fixes.py:238` | `unicode-escape`, `ascii` | | `explain_unicode` display and a docstring. |

ftfy never passes an `errors=` argument in its own decode or encode calls. The only use of
`errors="replace"` is inside the sloppy table builder (`ftfy/bad_codecs/sloppy.py:101`).
**[source]** So the port needs strict behaviour only.

One observation that affects which code paths are live: `ftfy/__init__.py:552` tests whether
`"windows-1252"` is in a list that can only ever contain names from `CHARMAP_ENCODINGS`, where
the entry is spelled `"sloppy-windows-1252"`. On a plain reading that test is never true, so the
`else` branch at `:561` always runs when `latin-1` is possible. **[derived]** Worth confirming in
a parity test, because it decides whether the strict cp1252 decode is reachable.

### 1.3 The sloppy codecs exactly

Rule (`ftfy/bad_codecs/sloppy.py:83-117`) **[source]**:

1. Start with the Latin-1 table: byte N maps to U+00NN for all 256 bytes.
2. Decode all 256 bytes with the real CPython codec using `errors="replace"`. Wherever the
   result is not U+FFFD, overwrite the entry with the real character.
3. Set byte 1A to U+FFFD.
4. Build the encode table as the inverse of that decode table (`codecs.charmap_build`).

Consequences:

- A hole byte N decodes to U+00NN, and U+00NN encodes back to N. This applies to every hole,
  including those outside the C1 range, for example D2 and FF in 1253 and A1 and A5 in 1257.
- Byte 1A decodes to U+FFFD and U+FFFD encodes to 1A. U+001A is not encodable in any sloppy
  codec. **[measured]** with a standard-library re-derivation of the rule.
- Decoding never fails. Encoding fails for any character not in the table.
- No best-fit mappings exist. CPython charmap codecs are strict inverses: for all 19 codecs
  checked, the set of encodable characters equals the set of decodable ones. **[measured]**

Sloppy codecs are defined for `windows-1250` to `windows-1258`, `cp1250` to `cp1258`, `cp874`
and `iso-8859-3`, `-6`, `-7`, `-8`, `-11` (`sloppy.py:157`). ftfy itself uses only the five in
the table above plus `sloppy-windows-1252`; the rest exist for callers. Hole counts for the
unused ones: 1255 has 23, 1256 has 0, 1258 has 9, cp874 has 31, iso-8859-3 has 7, iso-8859-6 has
45, iso-8859-7 has 3, iso-8859-8 has 36, iso-8859-11 has 8. **[measured]**

`sloppy-iso-8859-8` has one collision: hole byte D7 fills with U+00D7, which the real codec
already assigns to byte AA. All other sloppy tables are one-to-one. **[measured]**

### 1.4 The `utf-8-variants` decoder exactly

Aliases: `utf-8-variants`, `utf-8-variant`, `utf-8-var`, `cesu-8`, `cesu8`, `java-utf-8`,
`java-utf8`, with or without the hyphen after `utf` (`ftfy/bad_codecs/__init__.py:41`).
**[source]**

Encoding is plain UTF-8 (`utf8_variants.py:233`). It never produces CESU-8. **[source]**

Strict decoding accepts everything strict UTF-8 accepts, plus two things **[source]**:

- `C0 80` decodes to U+0000 (`:168`).
- A six-byte CESU-8 surrogate pair `ED [A0-AF] [80-BF] ED [B0-BF] [80-BF]` decodes to the one
  astral character it stands for (`:58`, `:214-224`).

Standard four-byte UTF-8 and CESU-8 pairs may be mixed freely in one input.

Everything else is handed to CPython's own UTF-8 decoder, so it fails the same way strict UTF-8
does. That covers lone surrogates (`ED A0..BF xx` not forming a pair), other overlong forms such
as `C0 81` and `C1 xx`, and truncated sequences. CPython strict UTF-8 itself rejects the CESU-8
pair and `C0 80`. **[measured]**

#### Incremental behaviour

The class is an incremental decoder with a `final` flag. With `final=False` it holds back a
trailing `C0`, or a trailing `ED` sequence shorter than six bytes, and waits for more input
(`:174-176`, `:201-212`). **[source]**

No ftfy call path reaches `final=False`. Every ftfy decode is a whole-buffer `bytes.decode(...)`,
which goes through `CODEC_INFO.decode`, which calls `IncrementalDecoder(errors).decode(input,
final=True)` (`:244-245`). `fix_file` decodes line by line, but each line is again a
whole-buffer call. The waiting behaviour is reachable only if a caller opens a stream with this
codec themselves. **[derived]** The R port needs a whole-string decoder only.

#### Two quirks at a trailing newline

The patterns use `$` without the multiline flag. In Python, `$` also matches just before a
final `\n`. That regex behaviour is **[measured]**; the consequences below are **[derived]** and
have not been run.

- Input ending in `C0 0A`: the pattern matches `C0` at the "end", the input is longer than one
  byte, so the code returns U+0000 and consumes two bytes. The newline is swallowed.
- Input ending in `ED A0 BD ED B8 0A` (five bytes of a pair, then newline): the pair pattern
  matches, six bytes are available, and the arithmetic is applied to the newline byte. The
  result would be U+1F60A, with the newline swallowed.

Both need the newline to be the very last byte of the buffer. Text lines often end that way, so
this is reachable. A port that matches Python byte for byte has to reproduce it; a parity test
against real ftfy should settle whether it does.

#### The NUL problem

`C0 80` decodes to U+0000, and an R character string cannot contain U+0000. stringi raised
"embedded nul in string" when asked to produce one. **[measured]** Python's decoder can therefore
return a string R cannot represent, and the port has to do something at the moment of decoding,
on every path that uses `utf-8-variants`.

Upstream lists U+0000 among the control characters that `remove_control_chars` strips
(`ftfy/chardata.py:97-114`), and that option defaults to on (`ftfy/__init__.py:224`). So in a
default `fix_text` call Python's final output probably has no U+0000 either, which would make
"drop it at decode time" match Python there but not for `fix_encoding` called alone.
**[derived]**: the order of the steps in `fix_text` was not traced. How the port handles this is
a separate decision; it is not something a codec table can solve.

## 2. Where stringi and ICU differ

### 2.1 Single-byte decode tables

Comparison of CPython's table with stringi's (`stri_encode(raw, from, "UTF-8")`) for every byte
01-FF. **[measured]**, ICU 71.1.

| CPython codec | ICU converter stringi resolves to | Bytes CPython assigns where ICU disagrees | What ICU does with CPython's holes |
|---|---|---|---|
| latin-1 | `ISO-8859-1` | none | no holes |
| cp1250 | `ibm-5346_P100-1998` | none | all 5 map to U+00NN, no warning |
| cp1251 | `ibm-5347_P100-1998` | none | 98 maps to U+0098, no warning |
| cp1252 | `ibm-5348_P100-1997` | none | all 5 map to U+00NN, no warning |
| cp1253 | `ibm-5349_P100-1998` | none | 15 map to U+00NN; **D2 and FF give U+FFFD** with a warning |
| cp1254 | `ibm-5350_P100-1998` | none | all 7 map to U+00NN, no warning |
| cp1257 | `ibm-9449_P100-2002` | none | 10 map to U+00NN; **A1 and A5 give U+FFFD** with a warning |
| iso-8859-2 | `ibm-912_P100-1995` | none | no holes |
| mac_roman | `macos-0_2-10.2` | none | no holes |
| cp437 | `ibm-437_P100-1995` | **1A, 1C, 7F, E6** | no holes |

The cp437 differences:

| Byte | CPython | ICU |
|------|---------|-----|
| 1A | U+001A | U+001C |
| 1C | U+001C | U+007F |
| 7F | U+007F | U+001A |
| E6 | U+00B5 MICRO SIGN | U+03BC GREEK SMALL LETTER MU |

What this means for each ftfy encoding:

- **Strict `windows-1252`** (`__init__.py:561`): ICU cannot reproduce it. Python raises on
  81 8D 8F 90 9D; stringi returns U+0081 and so on with no warning, so there is nothing to
  detect.
- **Sloppy 1250, 1251, 1252, 1254**: ICU's decode equals the sloppy table at every byte except
  1A (ICU gives U+001A, sloppy gives U+FFFD).
- **Sloppy 1253 and 1257**: ICU differs at byte 1A and at two more bytes each (D2, FF and
  A1, A5), where ICU gives U+FFFD and sloppy gives U+00NN.
- **latin-1, iso-8859-2, macroman**: decode is identical.
- **cp437**: four bytes differ. Three are control characters; the fourth changes which of µ and
  μ counts as "possibly cp437".

Other sloppy codecs ftfy defines but does not use (same measurement): for 1255 ICU fills 12
holes with U+00NN and gives U+FFFD for the other 11; for 1258 ICU fills all 9; for cp874 ICU
fills 23 and maps the other 8 (DB-DE, FC-FF) to private-use U+F8C1-U+F8C8; for iso-8859-3, -6,
-7, -8, -11 ICU gives U+FFFD for every hole.

### 2.2 Single-byte encode behaviour

Every code point U+0001-U+10FFFF (surrogates excluded) was encoded through
`stri_encode(x, "UTF-8", enc, to_raw = TRUE)`. **[measured]**, ICU 71.1 only.

- For every character CPython can encode, ICU produces the same byte, except the four cp437
  entries above (U+001A, U+001C, U+007F, U+00B5).
- **stringi warns instead of raising.** For a character with no mapping, stringi writes a
  substitute byte and issues a warning ("the Unicode code point ... cannot be converted to
  destination encoding"). A port can catch that warning and treat it as an error. The stringi
  manual describes the same behaviour: an incorrect code point "is replaced
  with the default (for that target encoding) 'missing/erroneous' character (with a warning)"
  **[docs]**
  ([stri_encode.Rd](https://github.com/gagolews/stringi/blob/master/man/stri_encode.Rd)).
  stringi's converter wrapper installs its own substitute-and-warn callbacks and does not change
  ICU's fallback setting **[docs]**
  ([stri_ucnv.cpp](https://github.com/gagolews/stringi/blob/master/src/stri_ucnv.cpp)).
- **The substitute byte varies by converter**: 1A for most, 3F for `macintosh` and
  `windows-874`, 7F for `cp437`.
- **About 4,170 characters are dropped rather than substituted.** Unmappable "default
  ignorable" code points (U+00AD, U+200B-U+200F, U+2060-U+206F, U+FE00-U+FE0F, U+FEFF,
  U+E0000-U+E0FFF and others) produce zero bytes. stringi still warns for them (checked for
  U+200B, U+FEFF and U+180F into `windows-1252`), but no substitute byte marks where they
  were. Python raises `UnicodeEncodeError` for them. The list is hard-coded in
  ICU **[docs]**
  ([ucnv_err.cpp](https://github.com/unicode-org/icu/blob/main/icu4c/source/common/ucnv_err.cpp),
  macro `IS_DEFAULT_IGNORABLE_CODE_POINT`).
- **That list depends on the ICU version.** The commit for Unicode 14 (June 2021) widened one
  range from U+180B-U+180E to U+180B-U+180F **[docs]**
  ([d4c92ebcf](https://github.com/unicode-org/icu/commit/d4c92ebcf)). stringi accepts any system
  ICU from version 61 up, so U+180F is substituted on some installs and dropped on others.
- ICU encodes the hole characters U+00NN to byte NN for the Windows tables, mirroring its
  decode. So it accepts U+0081 in "windows-1252" where strict Python does not.
- No classic best-fit mappings were seen (nothing like fullwidth letters mapping to ASCII). The
  only extra mappings beyond the above were cp437 U+03BC to E6 and cp874's private-use
  characters.

Inside `fix_encoding` the regex guard means unencodable characters never reach the encoder, so
these differences matter mainly for `apply_plan` and for any port that uses "did ICU encode it?"
as its test of whether an encoding is possible. That test would be wrong.

### 2.3 UTF-8, CESU-8 and UTF-16

Each case was decoded with ICU's `UTF-8` and `CESU-8` converters through stringi. **[measured]**
The `utf-8-variants` column is **[derived]** from the source.

| Input bytes | `utf-8-variants` (strict) | ICU `UTF-8` | ICU `CESU-8` |
|---|---|---|---|
| `F0 9F 98 8D` | U+1F60D | U+1F60D | U+FFFD, warning |
| `ED A0 BD ED B8 8D` | U+1F60D | six U+FFFD, warnings | U+1F60D |
| four-byte form followed by CESU-8 pair | U+1F60D U+1F60D | U+1F60D then six U+FFFD | U+FFFD then U+1F60D |
| `C0 80` | U+0000 | two U+FFFD, warnings | two U+FFFD, warnings |
| `ED A0 BD` alone | error | three U+FFFD | one U+FFFD |
| `C0 81` | error | two U+FFFD | two U+FFFD |
| `ED 95 9C` | U+D55C | U+D55C | U+D55C |

- ICU's `CESU-8` converter rejects ordinary four-byte UTF-8, so it cannot decode mixed input.
  ICU's `UTF-8` converter rejects the surrogate pairs. Neither accepts `C0 80`.
- stringi lists no Java modified UTF-8 converter: the only name matching "java", "cesu" or
  "modified" in `stri_enc_list()` is `CESU-8`.
- Where Python raises, stringi substitutes U+FFFD and warns. The number of U+FFFD per bad
  sequence also differs between the two ICU converters.
- `stri_enc_isutf8()` returned FALSE for the CESU-8 pair, `C0 80`, lone surrogates, overlong
  forms, truncated sequences and FF, and TRUE for the valid cases. It is a candidate for the
  strict UTF-8 validity check, on this evidence only; it was not tested exhaustively against
  CPython's decoder.
- **UTF-16** (`guess_bytes` only): for well-formed input with either BOM, CPython's `utf-16` and
  ICU's `UTF-16` agree and both drop the BOM. For an odd byte count or an unpaired surrogate,
  CPython raises `UnicodeDecodeError`; stringi returns U+FFFD with a warning.

### 2.4 Does ICU vary by version or platform?

**Decode tables: no variation seen.** The decode of bytes 01-FF for all 19 converters was
identical between stringi's ICU 71.1 and `uconv` from ICU 78.3 and 79.1. **[measured]** The ICU
converter names carry their own version stamps (for example `ibm-5348_P100-1997`), which fits
tables that do not change. Not measured: ICU 61-70, ICU 74.1, Windows, Linux, and whether a
distribution's reduced ICU data package still contains every converter.

**Encode behaviour: varies** through the default-ignorable list (2.2).

**Which ICU a user gets: varies, and not as documented.**

- stringi's INSTALL file says it needs ICU4C 61 or newer, ships a customised ICU4C 74.1 bundle,
  builds that bundle when no suitable system ICU is found through `pkg-config`, and that
  "Windows and macOS users fetch the pre-compiled binaries from CRAN built precisely this way"
  **[docs]** ([INSTALL](https://github.com/gagolews/stringi/blob/master/INSTALL)).
- On this machine the CRAN macOS arm64 binary of stringi 1.8.7 reports ICU 71.1 with
  `ICU.system = TRUE`. The shared library links no ICU dylib and contains the symbol
  `_icudt71_dat`, so ICU 71.1 is linked in statically. **[measured]**
- The likely explanation is CRAN's macOS build recipes, which pin ICU 71.1 **[docs]**
  ([R-macos/recipes, `recipes/icu`](https://github.com/R-macos/recipes/blob/master/recipes/icu)).
  That the stringi binary was built against that recipe is an inference, not something checked.
- So at least three ICU generations are in play for one stringi release: 71.1 (CRAN macOS),
  74.1 (the bundle), and whatever a Linux distribution ships, from 61 upward.

**CPython's side is frozen.** The files `Lib/encodings/cp1250.py`, `cp1251.py`, `cp1252.py`,
`cp1253.py`, `cp1254.py`, `cp1257.py`, `iso8859_2.py`, `mac_roman.py` and `cp437.py` were last
changed in May 2007, and that change was a syntax clean-up **[docs]**
([history of cp1252.py](https://github.com/python/cpython/commits/main/Lib/encodings/cp1252.py)).
These codecs are pure-Python charmap tables and do not call into the operating system, so they
are the same on every platform. Python's default error handler is `strict`, which raises
`UnicodeError` **[docs]**
([codecs: error handlers](https://docs.python.org/3/library/codecs.html#error-handlers),
[standard encodings](https://docs.python.org/3/library/codecs.html#standard-encodings)).

## 3. What this means for the codec-table decision

| Need | ICU at runtime | Generated table |
|------|----------------|-----------------|
| latin-1, iso-8859-2, macroman decode | matches | matches |
| cp437 decode and encode | wrong at 4 bytes | matches |
| sloppy 1250/1251/1252/1254 | wrong at byte 1A | matches |
| sloppy 1253/1257 | wrong at 3 bytes each | matches |
| strict windows-1252 decode failing on holes | impossible | matches |
| "is this text encodable in X" | wrong (extra hole characters accepted, cp437 differences) | exact set membership |
| raising on unencodable or undecodable input | only by trapping warnings; none for Windows-125x holes | port decides |
| same result on every platform and ICU version | not guaranteed | guaranteed |

A mixed approach (ICU for the three matching encodings, tables for the rest) saves three
256-entry tables and keeps the encode-side problems, so it buys nothing.

The data needed is small: one 256-entry decode table for each of the ten `CHARMAP_ENCODINGS`
entries, plus strict `cp1252` (eleven tables, or ten plus a five-byte hole list). Encode tables
are the exact inverses. The sloppy tables can be generated either from CPython directly or from
the rule in 1.3; both give the same result. Add the nine unused sloppy codecs only if the port
exposes them.

`utf-8-variants` needs a hand-written decoder in R whatever is decided about tables. It also
needs answers to two questions this ticket cannot settle: what to do about U+0000, and whether
to reproduce the trailing-newline quirks.

`fix_file`'s caller-supplied encoding and `apply_plan`'s arbitrary codec names are the one place
where ICU at runtime is the only practical option. Results there cannot be promised to match
Python.

## 4. Open items

- Run the **[derived]** claims against real ftfy 6.3.1 in a parity test: the trailing-newline
  quirks, the always-false `"windows-1252"` membership test, and the `utf-8-variants` column in
  2.3.
- Byte 00 through stringi, and decode tables on ICU 61-70 and 74.1, on Windows and on Linux.
  These stop mattering if tables are shipped.
- Whether `stri_enc_isutf8()` agrees with CPython's strict UTF-8 decoder on all inputs, if the
  port uses it for validation.
