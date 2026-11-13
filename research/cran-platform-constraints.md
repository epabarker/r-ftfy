# CRAN and platform constraints for non-ASCII data and encoding marks

Research ticket: [#6](https://github.com/epabarker/r-ftfy/issues/6). Date of research: 2026-11-13.

This file answers: what do CRAN policy and R's platform behaviour require of a package whose data and tests are full of non-ASCII, mojibake and exotic strings? It feeds three decisions: (1) how the R functions treat `NA`, encoding marks and invalid input, (2) the minimum supported R version, (3) how upstream-derived tables and JSON fixtures are shipped.

## How to read this file

Every claim is tagged with where it comes from.

- **[DOC]** — quoted or paraphrased from a primary document. The document and section are named.
- **[MEASURED]** — observed on this machine. Nothing measured here was run on Windows or on an R older than 4.6.2.
- **[INFERENCE]** — my reasoning from the two above. Treat as advice, not fact.

Measurement environment for every **[MEASURED]** claim:

| Item | Value |
|---|---|
| R | 4.6.2 (2026-10-29), `aarch64-apple-darwin23` (macOS, Apple silicon) |
| Default locale | `C.UTF-8` (`l10n_info()$"UTF-8"` is `TRUE`) |
| Other locales tried | `LC_ALL=en_US.ISO8859-1` (R reports Latin-1, not UTF-8) and `LC_ALL=C` |
| stringi | 1.8.7, ICU 71.1, Unicode 14.0 (CRAN current is 1.8.9) |
| jsonlite | 2.0.0 |
| Upstream | `rspeer/python-ftfy` tag `v6.3.1` (Apache-2.0), downloaded as a tarball |

Documents used:

| Short name | Document | Version read |
|---|---|---|
| WRE | *Writing R Extensions* | R 4.6.2 copy shipped with R (`R.home("doc")/manual/R-exts.html`) |
| R-ints | *R Internals* | R 4.6.2 copy shipped with R |
| R-admin | *R Installation and Administration* | R 4.6.2 copy shipped with R |
| NEWS | R `NEWS` and `NEWS.3` | shipped with R 4.6.2 |
| Policy | [CRAN Repository Policy](https://cran.r-project.org/web/packages/policies.html) | `$Revision: 6985 $`, fetched 2026-11-13 |
| Flavors | [CRAN Package Check Flavors](https://cran.r-project.org/web/checks/check_flavors.html) | "Last updated on 2026-11-13" |
| Help pages | `?Encoding`, `?enc2utf8`, `?iconv`, `?validUTF8`, `?utf8ToInt`, `?Quotes`, `?rawToChar` | R 4.6.2 |
| stringi help | `?about_encoding`, `?about_arguments`, `?stri_enc_toutf8`, `?stri_enc_mark`, `?stri_encode`, `?stri_enc_isutf8`, `?stri_enc_fromutf32`, `?stri_enc_toutf32`, `?stri_unescape_unicode` | stringi 1.8.7 |
| R blog | [Upcoming Changes in R 4.2 on Windows](https://blog.r-project.org/2021/12/07/upcoming-changes-in-r-4.2-on-windows/) (Tomas Kalibera, 2021-12-07) | fetched 2026-11-13 |
| Python | [The Python Language Reference, Data model](https://docs.python.org/3/reference/datamodel.html) | fetched 2026-11-13 |

The source of the GPL-3 R package `lupa` was not opened, fetched or read at any point.

---

## 1. Short answer

1. **Package R code must be ASCII.** Non-ASCII string literals go in as `\uxxxx` escapes. A raw non-ASCII literal in `R/` is a `R CMD check` **WARNING**, and declaring `Encoding: UTF-8` in `DESCRIPTION` does not remove it. [DOC + MEASURED]
2. **Non-ASCII tables can live in `R/sysdata.rda` with no check output at all**, provided every non-ASCII string is marked UTF-8. `R CMD check` does not inspect `sysdata.rda` strings. [MEASURED]
3. **Raw UTF-8 JSON under `inst/extdata/` or `tests/` produces no check output.** `R CMD check` does not look inside those files for non-ASCII bytes. [MEASURED]
4. **The upstream JSON fixture file is safe for R.** `tests/test_cases.json` in ftfy v6.3.1 holds 161 cases and 737 strings; none contains a surrogate, a NUL or a non-character. `jsonlite::fromJSON` reproduced all 737 strings code point for code point in three locales. [MEASURED]
5. **An R string cannot hold U+0000.** There is no workaround. Upstream's Python tests that expect a NUL in the output (three of them) cannot be ported as written. [DOC + MEASURED]
6. **An R string can physically hold lone-surrogate bytes, but the result is invalid UTF-8** and most functions reject it. Upstream `fix_surrogates` works on a Python `str` containing surrogate code points; R has no equivalent well-formed value. [DOC + MEASURED]
7. **Requiring R >= 4.2 does not guarantee a UTF-8 native encoding.** Windows older than Windows 10 version 1903 still runs R 4.2+ in a non-UTF-8 code page, and any Unix user can start R in a `C` or Latin-1 locale. The package has to be correct with respect to encoding marks regardless of the minimum R version. [DOC]
8. **stringi is not uniform on invalid UTF-8.** Depending on the function it raises an error, silently substitutes U+FFFD, or silently passes the invalid bytes through with a UTF-8 mark. It also silently deletes a leading U+FEFF in many functions. Inputs must be validated once at the boundary. [MEASURED]

---

## 2. The ASCII-only rule for package sources

### 2.1 What the documents say

WRE §1.1.5 "Package subdirectories", on files in `R/`:

> Only ASCII characters (and the control characters tab, form feed, LF and CR) should be used in code files. Other characters are accepted in comments, but then the comments may not be readable in e.g. a UTF-8 locale. Non-ASCII characters in object names will normally fail when the package is installed. Any byte will be allowed in a quoted character string but '\uxxxx' escapes should be used for non-ASCII characters. However, non-ASCII character strings may not be usable in some locales and may display incorrectly in others.

WRE §1.6.3 "Encoding issues" gives the portable method:

> There is a portable way to have arbitrary text in character strings (only) in your R code, which is to supply them in Unicode as '\uxxxx' escapes (or, rarely needed except for emojis, '\Uxxxxxxxx' escapes). If there are any characters not in the current encoding the parser will encode the character string as UTF-8 and mark it as such. This applies also to character strings in datasets: they can be prepared using '\uxxxx' escapes or encoded in UTF-8 in a UTF-8 locale, or even converted to UTF-8 via `iconv()`. If you do this, make sure you have 'R (>= 2.10)' (or later) in the 'Depends' field of the DESCRIPTION file.

The same section says non-ASCII should be avoided in comments too:

> Non-ASCII characters are particularly prevalent in comments (in the R code of the package, in examples, tests, vignettes and even in the NAMESPACE file) but should be avoided there.

WRE §1.3.1 "Checking packages" describes the check:

> The R files are checked for syntax errors. Bytes which are non-ASCII are reported as warnings, but these should be regarded as errors unless it is known that the package will always be used in the same locale.

WRE §1.1.1 "The DESCRIPTION file", on the `Encoding` field:

> If the DESCRIPTION file is not entirely in ASCII it should contain an 'Encoding' field specifying an encoding. This is used as the encoding of the DESCRIPTION file itself and of the R and NAMESPACE files, and as the default encoding of .Rd files. [...] Only encoding names latin1 and and UTF-8 are known to be portable. (Do not specify an encoding unless one is actually needed: doing so makes the package less portable. [...])

The CRAN Repository Policy has no clause of its own about ASCII in source files. It reaches the rule through two general clauses:

> Package authors should make all reasonable efforts to provide cross-platform portable code.

> Maintainers will be asked to update packages which show any warnings or significant notes, especially at around the time of a new x.y.0 release. Packages which are not updated are liable to be archived.

and it points to WRE for the detail ("There is a lot of helpful advice on writing portable packages in 'Writing R Extensions'").

File names: WRE §1.1 "Package structure" says "For maximal portability filenames should only contain only ASCII characters not excluded already", and §1.6 says "Non-ASCII filenames can also cause problems (particularly in non-UTF-8 locales)."

### 2.2 What `R CMD check --as-cran` actually reports [MEASURED]

I built eleven throwaway packages, each differing in one respect, and ran `R CMD build` then `R CMD check --as-cran --no-manual` on each tarball (R 4.6.2, macOS, `C.UTF-8`). CRAN incoming checks were switched off, so this does not show the new-submission NOTE.

| Arrangement | Check result | Exact text |
|---|---|---|
| ASCII code with `"é中"`, plus `R/sysdata.rda` holding UTF-8-marked strings (including U+FFFF and a non-ASCII `names` attribute), plus raw-UTF-8 JSON in `inst/extdata/` and in `tests/`, plus an ASCII test file | **OK** | no output |
| Raw UTF-8 literal in `R/probe.R`, no `Encoding` field | **WARNING** | `checking code files for non-ASCII characters ... WARNING` / `Found the following file with non-ASCII characters: R/probe.R` / `Portable packages must use only ASCII characters in their R code and NAMESPACE directives, except perhaps in comments. Use \uxxxx escapes for other characters.` |
| Same, with `Encoding: UTF-8` in `DESCRIPTION` | **WARNING** | identical text. Also a WARNING without `--as-cran`. |
| Raw UTF-8 only inside a comment in `R/probe.R`, no `Encoding` field | **OK** | no output |
| Raw UTF-8 literal in `tests/run.R`, no `Encoding` field | **OK** | no output |
| `R/sysdata.rda` holding one Latin-1-marked, one bytes-marked and one unmarked non-ASCII string | **OK** | no output |
| `data/tbl.rda` (LazyData) holding UTF-8-marked strings | **OK** | no output under `--as-cran` (see below) |
| `data/tbl.rda` holding one Latin-1-marked, one bytes-marked and one unmarked non-ASCII string | **WARNING** | `checking data for non-ASCII characters ... WARNING` / `Warning: found non-ASCII string` / `'<c3><a9>' in object 'tbl'` |
| Raw UTF-8 in a `.Rd` file, no `Encoding` field | **WARNING** | `checking Rd files ... WARNING` / `./man/probe.Rd: non-ASCII input and no declared encoding` |
| A file named `inst/extdata/café.txt` | **WARNING** | `checking for portable file names ... WARNING` / `Found the following file with a non-portable file name` |

The first arrangement and the packages with a non-ASCII test file, UTF-8 `data/` and mixed-mark `sysdata.rda` were also checked under `LC_ALL=C`. All four results were the same as in the UTF-8 locale.

Details that matter:

- **`sysdata.rda` is not scanned.** The "data for non-ASCII characters" check only loads the `data/` directory. I confirmed this from the function R runs for that check (`tools:::.check_package_datasets`, which calls `list_files_with_type(file.path(pkgDir, "data"), "data")`), and from the mixed-mark `sysdata.rda` package passing clean. [MEASURED]
- **The "marked UTF-8 strings" NOTE is gone by default since R 4.5.0.** R NEWS for 4.5.0: "Since almost all supported R versions now use UTF-8, R CMD check no longer by default reports on marked UTF-8 or Latin-1 strings in character data. Set environment variable `_R_CHECK_PACKAGE_DATASETS_SUPPRESS_NOTES_` to a false value for the previous behaviour." R-ints §8 "Tools" documents the variable: "Default: true, but false prior on R 4.5.0", and adds "Non-ASCII strings of unknown encoding are always reported." [DOC]
- On R 4.6.2, `--as-cran` sets that variable to `TRUE` itself, so the NOTE cannot appear under `--as-cran` even if you set the variable to false. Without `--as-cran` and with the variable false, the `data/` package shows `checking data for non-ASCII characters ... INFO` / `Note: found 2 marked UTF-8 strings`, and the status line stays `OK`. [MEASURED]
- **On R older than 4.5.0** the same `data/` content gives `Note: found N marked UTF-8 strings`. [DOC, from the NEWS entry; not measured.] This affects anyone checking on R 4.4 or older. Which R version CRAN's `r-oldrel` currently is was not looked up.
- The statement that non-ASCII "should be avoided" in tests and comments is advice in WRE only. No check enforces it for `tests/`. [MEASURED]

### 2.3 Consequences for holding the upstream tables [INFERENCE]

Three ways to hold a non-ASCII table, ranked by check noise:

| Method | Check output | Notes |
|---|---|---|
| `\uxxxx` escapes in `R/*.R` | none | The parser marks these strings UTF-8 (`?Encoding`: "The parser marks strings containing `\u` or `\U` escapes"). Diffable in git. `\u` and `\x`/octal escapes cannot be mixed in one literal (see §5.4). |
| `R/sysdata.rda` built from a script in `data-raw/` | none | Not inspected by check. Binary in git. Every non-ASCII string should be UTF-8-marked, because an unmarked string is reinterpreted in the reader's native encoding (see §4.4). |
| Files in `inst/extdata/` read at run time | none | Costs a file read and a parse at load or first use. Must be read with an explicit UTF-8 declaration. |

`data/` is the wrong place: WRE §1.1.6 says it "should not be used for other data files needed by the package, and the convention has grown up to use directory inst/extdata for such files", and it is the only location the non-ASCII data check inspects.

---

## 3. Shipping JSON fixtures and upstream-derived material

### 3.1 Is raw-Unicode JSON allowed in a CRAN package?

Nothing in WRE or the Policy forbids non-ASCII bytes in data files under `inst/` or `tests/`. The ASCII rule in WRE §1.1.5 is about "code files". `R CMD check --as-cran` reported nothing for raw-UTF-8 JSON in either `inst/extdata/` or `tests/`, in a UTF-8 locale and in the `C` locale. [MEASURED]

File names must stay ASCII (§2.1).

### 3.2 What is in the upstream fixture file [MEASURED]

`tests/test_cases.json` in ftfy v6.3.1:

| Property | Value |
|---|---|
| Size | 48,962 bytes, valid UTF-8, 4,763 non-ASCII bytes |
| Cases | 161, with keys `label`, `comment`, `original`, `fixed`, `fixed-encoding`, `expect` |
| String values | 737 |
| `\uXXXX` escapes in the file | 132, none of them a surrogate escape, none `\u0000` |
| Cases with a lone surrogate | 0 |
| Cases with U+0000 | 0 |
| Cases with a non-character (U+FDD0..U+FDEF, U+xxFFFE, U+xxFFFF) | 0 |
| Cases with U+FEFF | 0 |
| Cases with a C0 control other than tab, LF, CR | 2 (both are U+001A) |
| Cases with a C1 control U+0080..U+009F | 24 |
| Cases with U+FFFD | 14 |
| Cases with an astral character (above U+FFFF) | 4 |

Round trip: `jsonlite::fromJSON(file, simplifyVector = FALSE)` returned 737 strings whose code points equal Python's `json.loads` result for all 737, checked with both `utf8ToInt()` and `stringi::stri_enc_toutf32()`. The result was the same under `C.UTF-8`, `en_US.ISO8859-1` and `C`. All 391 non-ASCII strings came back marked `UTF-8`; the 346 ASCII strings are unmarked, as R requires. `save()`/`load()` preserved bytes and marks.

So the JSON fixtures can ship unmodified. That is not true of the Python-file tests; see §6.4.

### 3.3 How to read it safely [MEASURED]

| Reader | Mark on non-ASCII strings |
|---|---|
| `jsonlite::fromJSON(path)` | `UTF-8`, in all three locales |
| `readLines(path)` | unmarked ("unknown") — wrong in any non-UTF-8 session |
| `readLines(path, encoding = "UTF-8")` | `UTF-8` |

jsonlite hazards to know about, none of which the upstream file triggers:

| JSON input | `jsonlite::fromJSON` result |
|---|---|
| `"a\u0000b"` | `"a"` — silently truncated at the NUL, no warning |
| `"a\ud800b"` (lone high surrogate) | `"a?b"` — silently replaced by `?` |
| `"a\udc80b"` (lone low surrogate) | bytes `61 ed b2 80 62` marked UTF-8 — invalid UTF-8, no warning |
| `"😀"` (valid pair) | U+1F600, valid |
| `"￿"`, `"﷐"`, `"﻿a"`, `"\u0080"` | preserved exactly |

If R-specific fixtures ever need a NUL or a lone surrogate, JSON string escapes will not carry them through jsonlite. They would have to be stored as byte arrays or hex and rebuilt with `rawToChar()` (surrogates only; NUL cannot be rebuilt at all).

### 3.4 Copyright, attribution and size rules

Policy, "Source packages":

> The ownership of copyright and intellectual property rights of all components of the package must be clear and unambiguous (including from the authors specification in the DESCRIPTION file). Where code is copied (or derived) from the work of others (including from R itself), care must be taken that any copyright/license statements are preserved and authorship is not misrepresented.
>
> Preferably, an 'Authors@R' field would be used with 'ctb' roles for the authors of such code. Alternatively, the 'Author' field should list these authors as contributors.
>
> Where copyrights are held by an entity other than the package authors, this should preferably be indicated via 'cph' roles in the 'Authors@R' field, or using a 'Copyright' field (if necessary referring to an inst/COPYRIGHTS file).

and

> The maintainer warrants that (s)he is acting on behalf of all credited authors and has their agreement to use their material in the way it is included in the package (or if this is not possible, warrants that it is used in accordance with the license granted by the original author).

Upstream's `LICENSE.txt` reads "Copyright 2023 Robyn Speer", licensed under Apache-2.0, and `pyproject.toml` gives `authors = [{ name = "Robyn Speer", ... }]` and `license = { text = "Apache-2.0" }`. [MEASURED from the v6.3.1 tarball]

So a port that carries derived tables, regexes and test fixtures needs Robyn Speer in `Authors@R` (the Policy prefers `ctb`, plus `cph`), with the upstream copyright statement preserved. [INFERENCE from the Policy text; what Apache-2.0 itself requires for a derivative work is a separate legal question this ticket did not research.]

Size, Policy:

> Packages should be of the minimum necessary size. Reasonable compression should be used for data (not just .rda files) [...] As a general rule, neither data nor documentation should exceed 5MB [...] Source package tarballs should if possible not exceed 10MB.

The whole upstream fixture file is 49 KB and `ftfy/chardata.py` is 35 KB, so size is not a constraint. [MEASURED]

Check time, Policy: "Checking the package should take as little CPU time as possible". Not a concern for 161 cases.

---

## 4. How R marks string encodings

### 4.1 The model [DOC]

R-ints §1.1.2 "Rest of header":

> Bits 1, 2, 3, 5 and 6 are used for a CHARSXP to denote its encoding. Bit 1 indicates that the CHARSXP should be treated as a set of bytes, not necessarily representing a character in any known encoding. Bits 2, 3 and 6 are used to indicate that it is known to be in Latin-1, UTF-8 or ASCII respectively.

R-ints §1.9 "Encodings for CHARSXPs":

> A limited means to indicate the encoding of a CHARSXP is via two of the 'general purpose' bits which are used to declare the encoding to be either Latin-1 or UTF-8. (Note that it is possible for a character vector to contain elements in different encodings.)

> It is not necessary to declare the encoding of ASCII strings as they will work in any locale. ASCII strings should never have a marked encoding, as any encoding will be ignored when entering such strings into the CHARSXP cache.

`?Encoding`:

> Character strings in R can be declared to be encoded in "latin1" or "UTF-8" or as "bytes". [...] ASCII strings will never be marked with a declared encoding, since their representation is the same in all supported encodings. Strings marked as "bytes" are intended to be non-ASCII strings which should be manipulated as bytes, and never converted to a character encoding

So each element of a character vector is in one of five states:

| State | `Encoding()` returns | Meaning |
|---|---|---|
| ASCII | `"unknown"` | All bytes below 128. Cannot be marked. |
| native | `"unknown"` | Non-ASCII bytes, to be interpreted in the session's native encoding. |
| latin1 | `"latin1"` | Declared Latin-1. |
| UTF-8 | `"UTF-8"` | Declared UTF-8. The mark is a declaration, not a guarantee (see §5). |
| bytes | `"bytes"` | Not text. |

`NA_character_` is a sixth case: a distinct value, not the string `"NA"`. `Encoding(NA_character_)` is `"unknown"`. [MEASURED]

The mark is per element, so one vector can mix all of them.

The "Latin-1" mark is ambiguous on purpose. `?Encoding`:

> There is some ambiguity as to what is meant by a 'Latin-1' locale, since some OSes (notably Windows) make use of character positions undefined (or used for control characters) in the ISO 8859-1 character set. How such characters are interpreted is system-dependent but as from R 3.5.0 they are if possible interpreted as per Windows codepage 1252 [...] when converting to e.g. UTF-8.

### 4.2 How strings acquire marks [DOC + MEASURED]

`?Encoding` lists the routes: the parser marks strings containing `\u` or `\U` escapes; `scan`, `read.table`, `readLines` and `parse` have an `encoding` argument; `iconv` marks from its `to` argument; `intToUtf8` marks its output UTF-8.

Measured on this machine:

| Expression | Bytes | `Encoding()` |
|---|---|---|
| `"é"` | `c3 a9` | `UTF-8` in all three locales |
| `"A"` | `41` | `unknown` (ASCII is never marked) |
| `"\xe9"` | `e9` | `unknown` in UTF-8 and `C` locales; `latin1` in the Latin-1 locale |
| `x <- "abc"; Encoding(x) <- "UTF-8"` | `61 62 63` | `unknown` (silently ignored) |
| `readLines(utf8_file)` | as in file | `unknown` |

### 4.3 What base R does with each state [MEASURED, UTF-8 locale]

Input notation: `é/utf8` is bytes `61 c3 a9` (an `a` then é); `é/latin1` is bytes `61 e9`.

| Input | `enc2utf8` | `validUTF8` | `validEnc` | `nchar` | `toupper` | `paste0(x, "!")` mark |
|---|---|---|---|---|---|---|
| `NA_character_` | `NA` | `TRUE` | `TRUE` | `NA` (with `type = "chars"`) | `NA` | gives the string `"NA!"` |
| ASCII | unchanged | `TRUE` | `TRUE` | ok | ok | unknown |
| é/utf8 unmarked | same bytes, marked UTF-8 | `TRUE` | `TRUE` | 2 | ok, unmarked | unknown |
| é/utf8 marked UTF-8 | unchanged | `TRUE` | `TRUE` | 2 | ok, UTF-8 | UTF-8 |
| é/latin1 marked latin1 | `61 c3 a9`, UTF-8 | `FALSE` | `TRUE` | 2 | ok, UTF-8 | UTF-8 (re-encoded) |
| é/latin1 unmarked | `61 e9` **marked UTF-8, still invalid** | `FALSE` | `FALSE` | **error** `invalid multibyte string, element 1` | **error** | unknown |
| é/utf8 marked bytes | unchanged, still bytes | `TRUE` | `TRUE` | **error** `number of characters is not computable in "bytes" encoding` | **error** `translating strings with "bytes" encoding is not allowed` | bytes |

Three points to carry forward:

- `validUTF8()` "ignores any marked encoding [...] and so looks directly if the bytes in each string are valid UTF-8" (`?validUTF8`). It returns `FALSE` for a perfectly good Latin-1-marked string. It answers "are these bytes UTF-8", not "is this string well formed". `validEnc()` is the mark-aware one. Both return `TRUE` for `NA`. Both exist since R 3.3.0 (NEWS).
- `enc2utf8()` does not validate. In a UTF-8 session it takes an unmarked string containing byte `e9` or `ff` and returns the same invalid bytes with a UTF-8 mark. It also returns invalid UTF-8-marked input unchanged. `enc2utf8()` on a bytes-marked string returns it unchanged, still bytes-marked.
- `paste0(NA, "!")` is `"NA!"`. Base string functions do not all propagate `NA`.

`identical()` and `==` compare by character content across marks: a Latin-1-marked é and a UTF-8-marked é are `identical()` and `==`. A bytes-marked copy of the same UTF-8 bytes is not `identical()` to the UTF-8-marked one. [MEASURED]

Latin-1 versus Windows-1252, measured on bytes `80 99 81` marked `latin1`:

| Function | Result |
|---|---|
| `enc2utf8(x)` | `e2 82 ac e2 84 a2 3c 38 31 3e` — that is `€`, `™`, then the literal text `<81>` |
| `iconv(x, "", "UTF-8")` | `c2 80 c2 99 c2 81` — U+0080, U+0099, U+0081 (true ISO 8859-1) |
| `stringi::stri_enc_toutf8(x)` | `c2 80 c2 99 c2 81` — true ISO 8859-1 |
| `stringi::stri_encode(x, "windows-1252", "UTF-8")` | `e2 82 ac e2 84 a2 c2 81` — `€`, `™`, U+0081 |

Base R's internal conversion treats the `latin1` mark as CP-1252 (as `?Encoding` says) and turns the undefined byte `81` into four ASCII characters. `iconv` and stringi treat it as ISO 8859-1. ftfy's whole method depends on the difference between Latin-1 and Windows-1252 and on "sloppy" codecs that map undefined bytes to C1 controls, so **the package cannot rely on R's `latin1` mark or on `enc2utf8()` to decode Latin-1-marked input in a defined way**. It needs its own explicit byte-to-code-point tables or explicit `stri_encode(from = ...)` calls. [INFERENCE from the measurements]

### 4.4 What changes in a non-UTF-8 session [MEASURED]

Same machine, `LC_ALL=en_US.ISO8859-1`:

| Expression | UTF-8 locale | Latin-1 locale |
|---|---|---|
| `enc2utf8(<61 e9 unmarked>)` | `61 e9`, marked UTF-8, invalid | `61 c3 a9`, valid |
| `enc2utf8(<61 c3 a9 unmarked>)` | `61 c3 a9` | `61 c3 83 c2 a9` — **mojibake created** |
| `nchar(<61 c3 a9 unmarked>)` | 2 | 3 |
| `toupper`, `gsub`, `paste0` on é marked UTF-8 | UTF-8-marked result | UTF-8-marked result |
| `toupper`, `gsub`, `paste0`, `chartr` on é marked latin1 | re-encoded, **UTF-8**-marked result | result stays **latin1**-marked |
| `enc2native(<é marked UTF-8>)` | unchanged, UTF-8 | `e9`, latin1 |
| `enc2native("中")` | unchanged | the seven ASCII characters `<U+4E2D>` |
| `format("中")` | `e4 b8 ad` | `<U+4E2D>` |
| `toupper("中")`, `substr("a中b", 2, 2)`, `sprintf("%s!", "中")` | UTF-8, correct | UTF-8, correct |

Under `LC_ALL=C`, `enc2utf8()` of an unmarked non-ASCII string returns escaped text such as `a<e9>`.

So in a non-UTF-8 session: unmarked non-ASCII input is reinterpreted (correctly, from the user's point of view); base functions given Latin-1-marked input hand back Latin-1-marked results, where a UTF-8 session hands back UTF-8-marked ones; and anything that goes through `format()`, `enc2native()` or printing is lossy for characters outside the native charset. A UTF-8-marked string stayed correct and UTF-8-marked through `substr`, `gsub`, `paste0`, `sprintf` and `toupper` in the cases tried. The output mark of a base function therefore depends on both the input mark and the session, so code that needs UTF-8 has to convert explicitly.

---

## 5. Invalid UTF-8, embedded NUL, surrogates, non-characters

### 5.1 What a Python `str` can hold that an R string cannot

Python Language Reference, Data model: "A string (`str`) is a sequence of values that represent characters, or more formally, Unicode code points. All the code points in the range 0 to 0x10FFFF can be represented in a string." That includes U+0000 and the surrogates U+D800..U+DFFF as individual elements.

An R string is a NUL-terminated byte array with an encoding mark. Comparison:

| Content | Python `str` | R string |
|---|---|---|
| U+0000 | yes | **no** |
| Lone surrogate U+D800..U+DFFF | yes, a well-defined value | only as invalid UTF-8 bytes; not a well-formed string |
| Non-characters (U+FFFE, U+FFFF, U+FDD0..) | yes | yes, valid |
| Astral characters | yes | yes |
| Arbitrary invalid byte sequences | no (`str` is code points; bytes are a separate type) | yes — R strings can carry invalid bytes under any mark |

### 5.2 Embedded NUL [DOC + MEASURED]

`?Quotes`: "Embedded NULs are not allowed in character strings, so using escapes (such as `\0`) for a NUL will result in the string being truncated at that point (usually with a warning)."

`?rawToChar`: "only trailing nulls are allowed and will be removed".

`?utf8ToInt`, on `intToUtf8`: "For output to a single character string 0 is silently omitted: otherwise 0 is mapped to `""`."

`?stri_enc_fromutf32`: "Note that 0s are not allowed in vec, as they are used internally to mark the end of a string (in the C API)."

Every route tried:

| Attempt | Result |
|---|---|
| `"a\0b"`, `"a\x00b"`, `"a\u0000b"` in source | parse **error** `nul character not allowed` |
| `rawToChar(as.raw(c(0x61, 0, 0x62)))` | **error** `embedded nul in string: 'a\0b'` |
| `rawToChar(as.raw(c(0x61, 0x62, 0, 0)))` | `"ab"` (trailing NULs dropped) |
| `intToUtf8(c(97, 0, 98))` | `"ab"` — NUL **silently dropped** |
| `intToUtf8(c(97, 0, 98), multiple = TRUE)` | `"a"`, `""`, `"b"` |
| `stri_enc_fromutf32(c(97L, 0L, 98L))` | `NA` with warning `invalid Unicode code point \U00000000` |
| `stri_unescape_unicode("a\\u0000b")` | **error** `embedded nul in string` |
| `stri_encode(as.raw(c(0x61, 0, 0x62)), "UTF-8", "UTF-8")` | **error** `embedded nul in string` |
| `readLines()` on a file containing `a NUL b` | `"a"` with warning `line 1 appears to contain an embedded nul` |
| `readLines(skipNul = TRUE)` | `"ab"` |
| `readChar()` | `"a"` with warning `truncating string with embedded nuls` |
| `jsonlite::fromJSON('"a\\u0000b"')` | `"a"` — **silently truncated** |

A NUL can exist only in a `raw` vector. Failure modes differ by route: error, warning plus truncation, silent truncation, silent deletion, or `NA`.

### 5.3 Lone surrogates [DOC + MEASURED]

`?utf8ToInt`, "Validity": "The code points in the surrogate-pair range 0xD800 to 0xDFFF are prohibited in UTF-8 and so are regarded as invalid by `utf8ToInt` and by default by `intToUtf8`." Also: "`intToUtf8` does not by default handle surrogate pairs: inputs in the surrogate ranges are mapped to `NA`."

`?Quotes`, Note: "UTF-16 surrogate pairs in `\unnnn\uoooo` form will be converted to a single Unicode point, so for example `𝄞` gives the single character `\U1D11E`. However, unpaired values in the surrogate range such as in the string `"abc\uD834de"` will be converted to a non-standard-conformant UTF-8 string (as is done by most other software): this may change in future."

NEWS, R 4.1.0: "There are warnings (including from the parser) on the use of unpaired surrogate Unicode points such as `\uD834`. (These cannot be converted to valid UTF-8.)" NEWS, R 3.4.3: "`intToUtf8()` converts integers corresponding to surrogate code points to `NA` rather than invalid UTF-8".

Every route tried:

| Attempt | Result |
|---|---|
| `"a\ud800b"` in source | bytes `61 ed a0 80 62`, marked UTF-8, `validUTF8` `FALSE`; **warning** `unpaired surrogate Unicode point d800` |
| `"😀"` in source (valid pair) | `f0 9f 98 80` = U+1F600, valid, no warning |
| `intToUtf8(0xD800)`, `intToUtf8(c(97, 0xD800, 98))` | `NA` |
| `intToUtf8(c(0xD83D, 0xDE00))` | `NA` |
| `intToUtf8(c(0xD83D, 0xDE00), allow_surrogate_pairs = TRUE)` | U+1F600 |
| `intToUtf8(c(97, 0xD83D, 98), allow_surrogate_pairs = TRUE)` | `NA` |
| `stri_enc_fromutf32(0xD800L)` | `NA` with warning `invalid Unicode code point \U0000d800` |
| `stri_unescape_unicode("a\\ud800b")` | **error** `U_INVALID_CHAR_FOUND` |
| `stri_unescape_unicode("\\ud83d\\ude00")` | U+1F600 |
| `rawToChar(as.raw(c(0xed, 0xa0, 0x80)))` then `Encoding(x) <- "UTF-8"` | bytes kept, marked UTF-8, invalid |

So the only way to have a "lone surrogate" in R is the three-byte sequence `ED A0..BF xx` under a UTF-8 mark (this is also how CESU-8 text looks). R and stringi both classify it as invalid UTF-8: `validUTF8()` and `stri_enc_isutf8()` return `FALSE`. What functions then do with it:

| Function on `61 ed a0 80 62` marked UTF-8 | Result |
|---|---|
| `nchar`, `substr`, `toupper` | **error** (`invalid multibyte string`) |
| `utf8ToInt` | `NA` |
| `enc2utf8`, `iconv(x, "UTF-8", "UTF-8")`, `iconv(..., sub = "byte")` | bytes returned unchanged (this `iconv` does not detect it) |
| `gsub("a", "z", x)` | works, with warning `unpaired surrogate Unicode point d800` |
| `gsub(..., useBytes = TRUE)`, `grepl("\xed[\xa0-\xbf]", x, useBytes = TRUE)` | work on the bytes |
| `paste0` | bytes kept, UTF-8 mark |
| `saveRDS`/`readRDS`, `writeLines(useBytes = TRUE)`/`readLines(encoding = "UTF-8")` | bytes preserved |
| `stri_enc_toutf8(x)` | bytes returned unchanged |
| `stri_enc_toutf8(x, validate = TRUE)` | each of the three bytes becomes U+FFFD (three U+FFFD), with a warning |
| `stri_enc_toutf8(x, validate = NA)` | `NA`, with a warning |
| `stri_length`, `stri_enc_toutf32`, `stri_escape_unicode` | **error** `invalid UTF-8 byte sequence detected; try calling stri_enc_toutf8()` |
| `stri_trans_nfc`, `stri_replace_all_regex`, `stri_encode(x, "", "UTF-8")` | three U+FFFD, silently |
| `stri_replace_all_fixed`, `stri_trans_toupper`, `stri_join` | bytes passed through, marked UTF-8, silently |
| `stri_sub(x, 1, 2)` | `61 ed` — a multi-byte sequence cut in half, marked UTF-8 |

Note the count: stringi replaces one lone surrogate with **three** U+FFFD. Upstream `fix_surrogates` replaces one lone surrogate with **one** U+FFFD (`SURROGATE_RE.sub("�", text)`).

A CESU-8 pair (`ed a0 bd ed b8 80`, the six-byte encoding of U+1F600) behaves the same way: invalid for R and stringi, six U+FFFD from the validating functions. Decoding it needs byte-level code; nothing in base R or stringi decodes CESU-8. [MEASURED for the listed functions; I did not search ICU's converter list for a CESU-8 converter, so `stri_encode(from = "CESU-8")` is untested.]

### 5.4 Non-characters, the code point ceiling, and escape mixing [DOC + MEASURED]

`?utf8ToInt`: "The position of 'noncharacters' (notably 0xFFFE and 0xFFFF) was clarified by 'Corrigendum 9' in 2013. These are valid but will never be given an official interpretation. (In some earlier versions of R `utf8ToInt` treated them as invalid.)" NEWS dates the change to R 3.4.3.

| Attempt | Result |
|---|---|
| `"￿"`, `"﷐"`, `intToUtf8(0xFFFF)`, `intToUtf8(0xFFFE)`, `stri_enc_fromutf32(0xFFFFL)` | valid, UTF-8-marked |
| `validUTF8`, `stri_enc_isutf8`, `nchar`, `stri_length`, `stri_trans_nfc` on U+FFFF and U+FDD0 | all accept; length 1 |
| `toupper("￿")` | **error** `invalid input ... in 'utf8towcs'` on this platform (U+FDD0 is fine) |
| `"\U10FFFF"` | valid |
| `"\U110000"` | parse error `invalid \Uxxxxxxxx value 110000` |
| `intToUtf8(0x110000)`, `stri_enc_fromutf32(0x110000L)` | `NA` |

`?Quotes`: "As from R 4.1.0 the largest allowed `\U` value is `\U10FFFF`" and "The parser does not allow the use of both octal/hex and Unicode escapes in a single string." Measured: `"\xe9é"` is a parse error, `mixing Unicode and octal/hex escapes in a string is not allowed`. A mojibake literal therefore has to be written entirely with `\u` escapes (for example `"Ã©"`), never as a mix of `\x` bytes and `\u` code points.

### 5.5 Invalid UTF-8 in general [MEASURED]

Inputs: `61 c3 28` marked UTF-8 (truncated sequence), `61 ff 62` unmarked, `61 c0 80` marked UTF-8 (overlong NUL, the Java "modified UTF-8" form that upstream's `utf-8-variants` codec decodes).

Base R: `validUTF8` and `validEnc` `FALSE`; `nchar`, `substr`, `toupper`, `chartr`, `gsub` (both engines) error; `gsub(useBytes = TRUE)` and `paste0` work on bytes; `utf8ToInt` gives `NA`; `iconv(x, "UTF-8", "UTF-8")` gives `NA`; `iconv(..., sub = "byte")` gives text like `a<c3>(`; `nchar(allowNA = TRUE)` gives `NA`. One oddity: `toupper` of the overlong `61 c0 80` returned `"A"` (the string was cut at the decoded NUL) with no error.

`?iconv` warns that this is platform-dependent: "Note that implementations of `iconv` typically do not do much validity checking and will often mis-convert inputs which are invalid in encoding `from`", and "you cannot rely on invalid inputs being detected". `iconv` behaviour on invalid input must not be assumed to match across Linux (glibc), macOS and Windows.

stringi falls into three groups on all of these inputs:

| Behaviour | Functions observed |
|---|---|
| **Error** `invalid UTF-8 byte sequence detected; try calling stri_enc_toutf8()` | `stri_length`, `stri_enc_toutf32`, `stri_escape_unicode` |
| **Silent U+FFFD substitution** (one per bad byte) | `stri_trans_nfc`, `stri_trans_nfkc`, `stri_replace_all_regex`, `stri_encode(x, "", "UTF-8")` |
| **Silent pass-through**, invalid bytes returned with a UTF-8 mark | `stri_enc_toutf8(x)` (default arguments), `stri_replace_all_fixed`, `stri_trans_toupper`, `stri_join`, `stri_sub` (which can also split a sequence) |
| Reports correctly | `stri_enc_isutf8` (`FALSE`), `stri_enc_toutf8(validate = TRUE)` (U+FFFD plus warning), `stri_enc_toutf8(validate = NA)` (`NA` plus warning), `stri_encode(x, "UTF-8", "UTF-8")` (U+FFFD plus warning) |

`stri_detect_regex(x, ".")` returned `TRUE` on invalid input without complaint.

The stringi documentation describes the validating options (`?stri_enc_toutf8`: "If `validate=TRUE`, then in case of any incorrect byte sequences, they will be replaced with the REPLACEMENT CHARACTER [...] For `NA`, a bogus string will be replaced with a missing value") but does not promise any behaviour for invalid input to other functions. The three-way split above is observation, not contract.

---

## 6. What stringi does with each encoding mark

### 6.1 Documented behaviour

`?about_encoding`:

> Functions in stringi process each string internally in Unicode [...] Even if a string is given in the native encoding, i.e., your platform's default one, it will be converted to Unicode (precisely: UTF-8 or UTF-16).

> Most stringi functions always return UTF-8 encoded strings, regardless of the input encoding.

> Each time when a stringi function encounters a string declared in native encoding, it assumes that the input data should be translated from the default encoding, i.e., the one returned by `stri_enc_get`

> Functions which allow 'bytes' encoding markings are very rare in stringi, and were carefully selected. These are: `stri_enc_toutf8` (with argument `is_unknown_8bit=TRUE`), `stri_enc_toascii`, and `stri_encode`.

> Additionally, do note that stringi silently removes byte order marks (BOMs - they may incidentally appear in a string read from a text file) from UTF8-encoded strings, see `stri_enc_toutf8`.

`?stri_enc_mark`: stringi distinguishes five marks — "`ASCII`, `latin1`, `bytes`, `native`, and `UTF-8`. Additionally, missing values are handled properly."

`?about_arguments`:

> stringi handles missing values consistently. For any vectorized operation, if at least one vector element is missing, then the corresponding resulting value is also set to `NA`.

> Generally, all our functions drop input objects' attributes (e.g., `names`, `dim`, etc.). [...] Alternatively, the notation `x[] <- stri_...(x, ...)` can sometimes be used too.

> When a character vector argument is expected, factors and other vectors coercible to characters vectors are silently converted with `as.character`, otherwise an error is generated.

### 6.2 Measured behaviour by mark [MEASURED, UTF-8 locale]

| Input | `stri_enc_mark` | Typical stringi function (`stri_trans_nfc`, `stri_sub`, `stri_join`, regex) | Output mark |
|---|---|---|---|
| `NA_character_` | `NA` | `NA` (including `stri_join(NA, "!")`, unlike `paste0`) | — |
| ASCII | `ASCII` | works | unmarked |
| é/utf8 unmarked | `native` | works (native is UTF-8 here) | UTF-8 |
| é/utf8 marked UTF-8 | `UTF-8` | works | UTF-8 |
| é/latin1 marked latin1 | `latin1` | works; converted as ISO 8859-1 | UTF-8 |
| é/latin1 unmarked | `native` | treated as invalid UTF-8 (see §5.5) | UTF-8 |
| any bytes-marked string | `bytes` | **error** `bytes encoding is not supported by this function` | — |

Bytes-marked input: only `stri_enc_toutf8(x, is_unknown_8bit = TRUE)` (which turns every byte above 127 into U+FFFD) and `stri_encode(x, from = "<explicit encoding>", ...)` accepted it. `stri_enc_isutf8` also works on it, since it ignores marks.

Other measured facts:

- `stri_trans_nfc(c(<latin1 é>, <UTF-8 é>, NA))` returns `c("é", "é", NA)` with both strings UTF-8-marked: mixed-mark vectors are handled per element.
- `stri_trans_nfc(character(0))` and `stri_trans_nfc(NULL)` both return `character(0)`.
- `stri_trans_nfc(1:2)` returns `c("1", "2")`; a factor is converted through `as.character`; a list of length-1 strings is accepted.
- `names` are dropped. `x[] <- stri_trans_nfc(x)` keeps names and keeps `NA`.
- `stri_enc_toutf8()` on an unmarked string in a UTF-8 session returns it unmarked and unvalidated (documented: "returned as-is, i.e., with unchanged markings").
- `stri_encode(x, NULL, "windows-1252")` returns a **bytes-marked** string. Any design that round-trips text through an 8-bit encoding inside R gets bytes-marked intermediates, which most stringi functions then refuse. The alternative is `to_raw = TRUE` and working on raw vectors.
- Unconvertible characters in `stri_encode` become U+001A (SUBSTITUTE) in an 8-bit target and U+FFFD in a Unicode target, with a warning (documented in `?stri_encode`). U+001A is the same byte upstream ftfy uses internally to encode U+FFFD in its sloppy codecs (`ftfy/bad_codecs/sloppy.py`: "we're going to allow byte 1A, the 'Substitute' control code, to encode the Unicode replacement character U+FFFD"; two JSON test cases are about not leaking it). stringi's substitution character is the same code point, so a stringi conversion failure and an ftfy placeholder would be indistinguishable.

### 6.3 Leading U+FEFF is silently removed by many stringi functions [MEASURED]

Input `"﻿ab"` (bytes `ef bb bf 61 62`, marked UTF-8):

| Function | Result |
|---|---|
| `nchar` | 3 |
| `utf8ToInt` | `65279 97 98` |
| `stri_length` | 3 |
| `stri_detect_regex(x, "^\\ufeff")` | `TRUE` |
| `stri_trans_nfc`, `stri_trans_general(x, "Any-NFC")`, `stri_replace_all_regex` (no match), `stri_encode(x, "", "UTF-8")` | U+FEFF **kept** |
| `stri_enc_toutf8`, `stri_enc_toutf32`, `stri_sub(x, 1, 1)`, `stri_join`, `stri_c(collapse=)`, `stri_replace_all_fixed` (no match), `stri_split_fixed`, `stri_extract_all_regex(x, ".")`, `stri_trans_char`, `stri_trans_toupper`, `stri_escape_unicode` | U+FEFF **removed** |

`stri_sub(x, 1, 1)` returned `"a"`, not U+FEFF, although `stri_length` says the string has three characters. A U+FEFF in the middle of a string (`"a﻿b"`) is kept by `stri_sub` and `stri_enc_toutf8`.

This matters because upstream treats U+FEFF as data: `tests/test_characters.py` asserts `fix_encoding("ï»¿") == "﻿"`, and `remove_control_chars` is documented and tested as the step that deletes U+FEFF. A port that passes strings through `stri_sub`, `stri_join` or `stri_enc_toutf32` would lose a leading U+FEFF as a side effect, before or regardless of the fixer that is supposed to decide. The JSON fixtures contain no U+FEFF, so they will not catch it.

### 6.4 Upstream tests that depend on values R cannot hold [MEASURED from the v6.3.1 sources]

| Upstream test | What it needs | Status in R |
|---|---|---|
| `test_characters.py::test_surrogates` — `fix_surrogates("􏿿") == "\U0010ffff"`, `fix_surrogates("𐀀") == "\U00010000"` | a `str` holding two surrogate code points | No well-formed R input exists. The nearest R input is the CESU-8 byte form, which is invalid UTF-8. `"􏿿"` typed in R source is already combined to U+10FFFF by the parser. |
| `fixes.py::fix_surrogates` doctest — low surrogate then high surrogate becomes two U+FFFD | lone surrogates | Same. |
| `test_bytes.py::test_guess_bytes_null` — `guess_bytes(b"null\xc0\x80separated")` returns `"null\x00separated"` | NUL in the output string | **Impossible** in R. |
| `test_bytes.py::test_incomplete_sequences` — expects `"surrogates: \U00010000 / null: \x00"` | NUL in the output string | **Impossible** as written. The surrogate half (decoding CESU-8 bytes to U+10000) is possible from a raw vector. |
| `test_encodings.py::test_cesu8` — expects `"\U00077777 is an unassigned character, and \x00 is null"` | NUL in the output string | **Impossible** as written. |
| `test_characters.py::test_byte_order_mark`, `test_control_chars` | leading U+FEFF preserved until the fixer removes it | Possible, but see §6.3. |
| `test_characters.py::test_control_chars` | U+007F, U+FFFA..U+FFFC, U+206A | Fine. |
| `tests/test_examples_in_json.py` | runs the encoding-only pass with `fix_surrogates=False` (and the other non-encoding fixers off) | The JSON data itself has no surrogates (§3.2). |

Upstream's `utf-8-variants` codec exists to decode CESU-8 and Java's `C0 80` NUL from **bytes**. In R that input can only arrive as a `raw` vector or as an invalid-UTF-8 string, and its NUL output cannot be represented.

### 6.5 stringi's "native" encoding is not always R's native encoding [MEASURED]

Under `LC_ALL=en_US.ISO8859-1` on this Mac, R reported `l10n_info()` as Latin-1 and not UTF-8, but `stri_enc_get()` still returned `"UTF-8"`. `stri_enc_set("windows-1252")` gave the warning "system ICU assumes that the default character set is always UTF-8, and hence this function has no effect". So here stringi treated the unmarked bytes `61 e9` as invalid UTF-8, while base R in the same session treated them as é.

Two consequences:

- This machine cannot stand in for Windows with a non-UTF-8 code page as far as stringi is concerned. The stringi rows in §4.4-style comparisons could not be measured. What stringi does there is known only from its documentation (§6.1: native strings are "translated from the default encoding").
- On at least this platform, base R and stringi can disagree about what an unmarked non-ASCII string means. Converting with `enc2utf8()` first removes the disagreement in a valid session, because the result is UTF-8-marked and stringi honours the mark.

---

## 7. Windows before and after R 4.2, and the minimum R version

Nothing in this section was measured. No Windows machine and no R older than 4.6.2 was available.

### 7.1 What changed in R 4.2.0 [DOC]

NEWS, R 4.2.0, "Significant User-Visible Changes": "Support for 32-bit builds has been dropped" and "UTF-8 locales are used where available."

NEWS, R 4.2.0, "Windows":

> R uses UTF-8 as the native encoding on recent Windows systems (at least Windows 10 version 1903, Windows Server 2022 or Windows Server 1903). As a part of this change, R uses UCRT as the C runtime. UCRT should be installed manually on systems older than Windows 10 or Windows Server 2016 before installing R.

R-ints §1.9:

> Windows with MSVCRT as the C runtime has no UTF-8 locales [...]

> Windows since Windows 10 (version 1903), Windows Server 2022 (LTSC), and Windows Server 1903 (semi-annual channel) allow setting the active code page to UTF-8 in the application manifest. [...] R 4.2 for Windows uses this feature to get UTF-8 as the native encoding on Windows.

> Older versions of Windows still rely on the previous encoding support where the native encoding cannot be UTF-8. R 4.2 requires UCRT to work, but UCRT can be installed on Windows since Vista SP2 and Windows Server 2008 SP2.

R blog, 2021-12-07: "Older Windows systems will be able to run R, but with the same limitations in the encoding support as in R 4.1 and earlier."

R-admin (4.6.2), Windows chapter: "R is most tested on current versions of Windows 10 and Windows Server 2022 with UTF-8 as the charset encoding. It works also on Windows 11. It runs on older versions of Windows, but normally with other charset encoding and may require manual installation of the Universal C Runtime (UCRT)."

WRE §1.6.3: "The issues in this subsection have been much alleviated by the change in R 4.2.0 to running the Windows port of R in a UTF-8 locale where available. However, Windows users might be running an earlier version of R on an earlier version of Windows which does not support UTF-8 locales."

Summary:

| Platform | Native encoding |
|---|---|
| Windows, R < 4.2 | Never UTF-8. A single- or double-byte code page (CP-1252, CP-932, ...). |
| Windows 10 1903+ / Server 2022+, R >= 4.2 | UTF-8 |
| Older Windows, R >= 4.2 | Still a non-UTF-8 code page |
| macOS, Linux | Whatever the locale says. Usually UTF-8, but `C`, POSIX and ISO 8859 locales exist. WRE §1.3.1: "although a C locale is rarely used at a console, it may be the default if logging in remotely or for batch jobs". |

### 7.2 What CRAN actually tests [DOC, Flavors page of 2026-11-13]

All thirteen check flavours run in a UTF-8 `LC_CTYPE`:

| Flavours | `LC_CTYPE` |
|---|---|
| Debian (r-devel clang and gcc, r-patched, r-release) | `C.UTF-8` |
| Fedora (r-devel clang and gcc) | `en_GB.UTF-8` |
| Windows (r-devel, r-release, r-oldrel), all Windows Server 2022 | `German_Germany.utf8` |
| macOS (r-release and r-oldrel, arm64 and x86_64) | `en_US.UTF-8` |

CRAN checks r-devel, r-patched, r-release and r-oldrel only. Policy, "Binary packages": "Binary packages are built for the current version of R: they may also be built for the last version in the previous series (e.g. R 3.5.3 when R 3.6.x is current) or for R-devel." Policy, "Submission": "Please ensure that `R CMD check --as-cran` has been run on the tarball to be uploaded before submission. This should be done with the current version of R-devel (or if that is not possible and explained in the submission, current R-patched or the current release of R.)"

So CRAN's machines will never exercise a non-UTF-8 native encoding or an R older than oldrel. A bug that only appears on pre-4.2 Windows or in a Latin-1 locale will not be found by CRAN. It also will not block acceptance.

### 7.3 Version floors implied by dependencies and features [DOC]

| Item | Floor | Source |
|---|---|---|
| stringi 1.8.9 (CRAN current) | `Depends: R (>= 3.4)` | stringi `DESCRIPTION` on CRAN |
| jsonlite 2.0.0 | no R version in `Depends` | jsonlite `DESCRIPTION` on CRAN |
| `\uxxxx` strings in code or data | `R (>= 2.10)` must be declared | WRE §1.6.3 |
| `validUTF8()`, `validEnc()` | R 3.3.0 | NEWS.3 |
| `utf8ToInt()` accepts U+FFFE/U+FFFF; `intToUtf8()` maps surrogates to `NA` | R 3.4.3 | NEWS.3 |
| `.rda`/`.rds` in serialization format 3 (the default writer format since R 3.6.0) | readable only by R >= 3.5.0 | NEWS.3, R 3.5.0 and 3.6.0 |
| `substr()` errors on invalid UTF-8 | R 3.6.0 | NEWS.3 |
| Surrogate-pair fixes in `tolower`/`toupper`; raw string literals `r"(...)"` | R 4.0.0 | NEWS |
| Parser warns on unpaired surrogate escapes; `\U` capped at `10FFFF`; more Latin-1-marked support in `nchar`, `tolower`, `toupper`, `chartr`, regex | R 4.1.0 | NEWS |
| UTF-8 native on recent Windows | R 4.2.0 | NEWS |
| "marked UTF-8 strings" check NOTE off by default | R 4.5.0 | NEWS |

Serialization format 3 has one feature relevant here. R-ints §1.8: it "stores the current native encoding at serialization time, so that unflagged strings can be converted if unserialized in R running under different native encoding." That only helps unmarked strings; marking everything UTF-8 before saving avoids depending on it.

### 7.4 What this means for the minimum-version decision [INFERENCE]

- **No minimum R version makes the native encoding UTF-8.** R >= 4.2 leaves old Windows and non-UTF-8 Unix locales. The code has to treat "native" as unknown in every case. The minimum R version therefore cannot be used to simplify encoding handling; it only decides how many old-Windows users are in scope and which base functions are available.
- **The lowest floor that the stack allows is R 3.5** (stringi needs 3.4; format-3 `sysdata.rda` needs 3.5). Between 3.5 and 4.1 there are documented behaviour changes in exactly the functions an encoding package would use (`substr` on invalid input, surrogate handling, Latin-1-marked support, parser warnings). None of that can be tested on CRAN or was tested here.
- **R >= 4.2** is the floor at which the majority Windows configuration is UTF-8 native and matches what CRAN tests, and it removes 32-bit Windows.
- A choice between these is a support-policy decision, not something the documents force. The Policy sets no minimum R version. What it does require is that the declared `Depends: R (>= x)` is true, and nothing checks that below oldrel except the maintainer.
- If the core algorithm does its string work through stringi and its own tables rather than base R string functions, most of the base-R version differences in §7.3 stop mattering, and behaviour depends on the stringi/ICU version instead. That is a design observation, not a measured guarantee.

---

## 8. Facts bearing on the three decisions

These restate findings above against each decision. The decisions themselves belong to the planning effort.

### 8.1 `NA`, encoding marks and invalid input in the R functions

Facts:

- `NA_character_` is distinct from any string. stringi propagates it in every function measured; base `paste0` does not. (§4.3, §6.2)
- stringi functions return UTF-8-marked output (ASCII output is unmarked because R cannot mark it), drop attributes, and coerce non-character input. (§6.1, §6.2)
- Latin-1-marked input is decoded differently by `enc2utf8()` (CP-1252, with `<81>`-style text for undefined bytes) and by stringi and `iconv` (ISO 8859-1). (§4.3)
- Unmarked non-ASCII input means "native encoding", which differs by session, and base R and stringi can disagree about it on at least one platform. (§4.4, §6.5)
- Bytes-marked input is rejected by nearly every stringi function with an error. (§6.2)
- Invalid UTF-8 under a UTF-8 mark is possible and common in practice (it is what a wrongly declared file produces). `enc2utf8()` and default `stri_enc_toutf8()` do not detect it. stringi then errors, substitutes or passes it through depending on the function. (§5.5)
- `validUTF8()` ignores marks; it is the right test only after conversion to UTF-8. (§4.3)

What that implies [INFERENCE]: the public functions need one explicit normalisation step at entry, and every internal function can then assume valid, UTF-8-marked (or ASCII) strings. The step has to decide four things that R does not decide for you: what `NA` returns (stringi's convention is `NA` in, `NA` out); how a Latin-1 mark is decoded; whether bytes-marked input is an error; and whether invalid UTF-8 is an error, becomes `NA`, or becomes U+FFFD (`stri_enc_toutf8(validate = ...)` offers the last two, at three U+FFFD per lone surrogate rather than upstream's one). Restoring `names`/`dim` on output is also the package's job. Leading U+FEFF needs a deliberate choice of stringi functions (§6.3).

### 8.2 Minimum R version

See §7.4. The documents permit anything from R 3.5 upward. No choice removes the need to handle non-UTF-8 native encodings. Only r-devel, r-release and r-oldrel in UTF-8 locales are tested by CRAN.

### 8.3 Shipping upstream-derived tables and JSON fixtures

- Tables in code: ASCII source with `\uxxxx` escapes, or `R/sysdata.rda` generated by a script. Both give a clean `R CMD check --as-cran`. Not `data/`. (§2.2, §2.3)
- JSON fixtures: ship the upstream file as raw UTF-8 under `inst/extdata/` or `tests/`, ASCII file name, read with `jsonlite::fromJSON()` or `readLines(encoding = "UTF-8")`. Clean check; exact round trip verified for all 737 strings. (§3)
- Test code files: keep ASCII and put the exotic strings in the JSON. A raw-UTF-8 test file produced no check output, but WRE says non-ASCII "should be avoided" in tests, and a test file is parsed in the session's encoding unless declared. (§2.1, §2.2)
- Lone-surrogate literals must not appear in package or test source as `"\ud800"`: the parser warns on R >= 4.1.0, and the result is an invalid string. Build such inputs from raw bytes. (§5.3)
- Attribution: the Policy requires upstream authorship and copyright statements to be preserved and reflected in `Authors@R`. (§3.4)
- Size is far below every limit. (§3.4)

---

## 9. Not established

- Any behaviour on Windows, on a Windows non-UTF-8 code page, or on R older than 4.6.2. All such statements are from documents.
- stringi's handling of native (unmarked) strings when the native encoding is not UTF-8. This machine's ICU build always reports UTF-8 (§6.5).
- Whether stringi's three behaviours on invalid UTF-8 (§5.5) and its leading-U+FEFF removal (§6.3) are the same in other stringi/ICU versions, including CRAN-current 1.8.9. Measured on 1.8.7 with ICU 71.1 only.
- Whether ICU offers a CESU-8 converter usable through `stri_encode`.
- Whether a parse-time "unpaired surrogate" warning in package source turns into an install-time or check-time WARNING.
- What CRAN's human reviewers say about large blocks of `\u` escapes or binary `sysdata.rda`. Only the automated check was observed.
- What Apache-2.0 requires of the port beyond what the CRAN Policy asks (NOTICE handling, statement of changes).
- The new-submission and incoming-feasibility parts of `--as-cran` were switched off in the probe runs.
