# Python `re` / `unicodedata` / `wcwidth` versus ICU (stringi): where ftfy 6.3.1 output can diverge

Research for issue #5. Upstream is `rspeer/python-ftfy` at tag `v6.3.1`
(commit `5340af6746ff655a9cd7cb2b50c2fd0b35bb91d3`); every `file:Lnn` reference below is to that
commit, e.g. <https://github.com/rspeer/python-ftfy/blob/5340af6746ff655a9cd7cb2b50c2fd0b35bb91d3/ftfy/badness.py#L274-L387>.
Upstream patterns and tables are described, not reproduced.

## 1. Answer in brief

1. **Every upstream regex can be run by ICU with identical results, but none can be pasted in as is.**
   Three semantic differences bite, all measured here:
   - **Free-spacing mode.** ICU's `comments=TRUE` / `(?x)` discards whitespace *inside* `[...]`;
     Python's `re.VERBOSE` keeps it. `BADNESS_RE` then fails to compile and `UTF8_DETECTOR_RE`
     compiles but silently matches the wrong thing.
   - **`\s` and `\w`.** They are defined differently in the two engines, not merely versioned
     differently. `\d` has the same definition (`Nd`) and differs only by Unicode version.
   - **Line terminators.** ICU's `.` and `$` recognise seven line terminators; Python recognises
     only `\n`. `unix_lines=TRUE` removes the difference.
2. **With three mechanical changes, parity was exact on the test corpus.** Flatten the verbose
   patterns, replace `\s` / `\w` / `\d` with explicit code-point sets taken from Python, and set
   `unix_lines=TRUE`. All 19 text regexes then gave identical match spans on 120,390 strings, and
   the 5 bytes regexes (ported as Latin-1 code points) on 60,011 byte strings. This is strong
   evidence, not proof.
3. **After that, the default `fix_text` path has one remaining runtime dependency on ICU's Unicode
   data: the final NFC normalisation.** By Unicode's stability policy it can differ only for
   strings containing code points that one side's Unicode version does not yet assign. The
   measurements agree: every single code point, and 200,000 random sequences of older code points,
   normalised identically. `WIDTH_MAP` (NFKC over U+FF01..U+FFEF) was identical everywhere and can be a frozen table.
4. **"Python ftfy 6.3.1 behaviour" is not single-valued.** `\w`, `\d`, normalisation,
   `unicodedata.category` / `name` and `str.isprintable` follow the running Python's Unicode version
   (13.0 on Python 3.9/3.10 up to 16.0 on 3.14). The display-width helpers follow whichever
   `wcwidth` is installed; the dependency is unpinned, and upstream's own soft-hyphen doctest only
   holds for wcwidth 0.2.9 to 0.2.13. A reference Python and a reference wcwidth must be chosen.
5. **`stri_width()` is not a substitute for `wcwidth`.** It returned 0, not -1, for every control
   character tried, and width 2 for all 6,605 general-category-`So` characters on the build
   measured, so upstream's kaomoji doctest line measures 21 instead of 13.
6. **Other ICU/stringi hazards that affect a faithful port** (all measured):
   - ICU's default 8 MB backtracking limit raises `U_REGEX_STACK_OVERFLOW` on two upstream patterns
     for inputs inside ftfy's 1,000,000-character segment limit (from 200,000 and 400,000
     characters); Python's `re` handles the same inputs.
   - stringi silently strips a leading U+FEFF in several functions.
   - R strings cannot hold U+0000 or lone surrogates.

Suggested strategy is in section 9.

## 2. What was measured, and what comes from documentation

Measurements were made on one machine. They are single data points, not a survey.

| Component | Version measured |
|---|---|
| Python | 3.9.6 and 3.10.20 (`unidata_version` 13.0.0), 3.13.5 (15.1.0), 3.14.5 (16.0.0); standard library only, run with `-I` |
| R / stringi | R 4.6.2, stringi 1.8.7 (macOS arm64, `Repository: CRAN`), reporting ICU 71.1, Unicode 14.0, `ICU.system = TRUE` |
| ICU directly | Homebrew ICU 78.3 (Unicode 17.0) and 79.1 (Unicode 18.0), through a small C++ probe, for regex semantics only |

- **Upstream code was never imported or executed.** Regex and table literals were pulled out of the
  upstream files with Python's `ast` module (literals only) and compiled with the standard-library
  `re`. Where upstream builds something in code (the entity table, the codec character lists), the
  documented construction was re-implemented in a scratch script.
- **Corpus.** 120,000 random strings of 1 to 10 code points (60% drawn from the characters named in
  upstream's mojibake classes, 30% ASCII, 10% awkward characters: line terminators, controls,
  combining marks, superscripts, fractions, non-BMP), plus hand-written probes, plus the strings in
  upstream's `tests/test_cases.json` read as data. Total 120,390. The bytes corpus is 60,011 strings.
  Strings containing U+0000 or lone surrogates were excluded because R cannot hold them.
- **Not measured:** `wcwidth` (not installed, and installing was out of scope), stringi's bundled
  ICU 74.1, Windows and Linux builds. Statements about those are from documentation and are marked.
- Scripts and raw output are in the session scratch directory and are not committed, because they
  embed upstream literals.

## 3. Versions: which Unicode data each side carries

### Python `unicodedata`

| Python | Unicode | Source |
|---|---|---|
| 3.9, 3.10 | 13.0.0 | measured |
| 3.11 | 14.0.0 | [docs](https://docs.python.org/3.11/library/unicodedata.html) |
| 3.12 | 15.0.0 | [docs](https://docs.python.org/3.12/library/unicodedata.html) |
| 3.13 | 15.1.0 | measured |
| 3.14 | 16.0.0 | measured |

ftfy 6.3.1 declares `requires-python = ">=3.9"` (`pyproject.toml:L9`), so all of these are
legitimate hosts for the reference behaviour.

### ICU

| ICU | Unicode | Source |
|---|---|---|
| 61 | 10.0 | stringi NEWS 1.2.2 |
| 62, 63 | 11.0 | [ICU downloads](https://unicode-org.github.io/icu/download/) (62); 63 inferred, no new Unicode version announced |
| 64, 65 | 12.x | ICU downloads (64); 65 inferred |
| 66 to 69 | 13.0 | ICU downloads (66, 67); stringi NEWS 1.6.1 (69); 68 inferred |
| 70, 71 | 14.0 | ICU downloads (70); 71 measured |
| 72, 73 | 15.0 | ICU downloads (72); 73 inferred |
| 74, 75 | 15.1 | ICU downloads and stringi NEWS 1.8.1 (74); 75 inferred |
| 76, 77 | 16.0 | ICU downloads (76); 77 inferred |
| 78 | 17.0 | ICU downloads; measured |
| 79 | 18.0 | ICU downloads; measured |

### stringi

- Minimum system ICU is 61; the bundled copy is ICU 74.1 (Unicode 15.1) since stringi 1.8.1
  ([NEWS](https://github.com/gagolews/stringi/blob/master/NEWS),
  [install guide](https://stringi.gagolewski.com/install.html)). Latest release seen is 1.8.9
  (2026-07-30), with no ICU change since 1.8.1.
- A source install uses the system ICU when `pkg-config` finds one that is at least 61, otherwise
  the bundle (install guide). So Linux users get whatever their distribution ships, and the possible
  range is Unicode 10.0 to 18.0.
- **Documentation and measurement disagree for macOS.** The install guide says Windows and macOS
  CRAN binaries are built with the bundle. The stringi 1.8.7 installed here (`Repository: CRAN`,
  macOS arm64, R 4.6) reports ICU 71.1, Unicode 14.0 and `ICU.system = TRUE`. `otool -L` shows no
  ICU dynamic library and no ICU 71 exists on this machine, so ICU 71.1 was statically linked
  wherever the binary was built. How it was installed was not traced. Do not assume a binary
  install means Unicode 15.1; read `stringi::stri_info()` at run time.

### Version pairs that happen to line up

Python 3.13 and stringi's bundled ICU 74.1 are both Unicode 15.1. Python 3.11 and ICU 70/71 are
both 14.0. Python 3.14 and ICU 76/77 are both 16.0.

## 4. Regex inventory

"Flat" means the pattern with Python-verbose whitespace and comments removed outside character
classes. "Frozen" means flat with `\s`, `\w`, `\d` replaced by explicit code-point sets dumped from
Python. Mismatch counts are against Python match spans on the corpus, with stringi on ICU 71.1.

### 4.1 Text (str) regexes

| Regex (upstream location) | Constructs | Result in ICU |
|---|---|---|
| `BADNESS_RE` (`badness.py:L274-L387`), used by `findall` (L409) and `search` (L420) | `re.VERBOSE`; 37 top-level alternatives built from literal classes and ranges; `\s` (L290, L363); `\w` (L308); one `.` (L357); one `^` (L365); literal space inside a class at L357, L363, L365, L370 | Verbatim with `comments=TRUE`: **compile error**. Flat: 39 mismatches. Flat + `unix_lines`: 36. **Frozen + `unix_lines`: 0** (with sets from Python 3.9 and from 3.14) |
| `UTF8_DETECTOR_RE` (`chardata.py:L679-L691`) | `re.VERBOSE`; fixed-width negative lookbehind; a repeated (`+`) capture group of three alternatives; fixed counts `{2}`, `{3}`; literal space inside three classes | Verbatim with `comments=TRUE`: compiles, **451 mismatches** (space silently dropped). **Flat: 0** |
| `ENCODING_REGEXES`, 11 patterns (`chardata.py:L32-L56`), used with `.match` (L94) | one starred class anchored with `^` and `$`; the class holds a literal U+0000 and, for Latin-1 and ISO-8859-2, a literal U+0085 | Flat: 118 to 232 mismatches each (strings ending in a non-`\n` line terminator). **`unix_lines`, or `$` replaced by `\z`: 0** |
| `ESCAPE_SEQUENCE_RE` (`fixes.py:L342-L352`) | `re.VERBOSE`; 14 `.`; a bounded `{1,3}` repeat; a negated class holding `}`; an escaped backslash before `N` and a brace | Flat or verbatim: 2 mismatches (`.` against CR and U+2028). **With `unix_lines`: 0** |
| `ANSI_RE` (`fixes.py:L142`) | a starred non-capturing group alternating `\d` and a literal, two capture groups | 0 mismatches on the corpus, but see `\d` (5.2) and stack overflow (5.5) |
| `HTML_ENTITY_RE` (`chardata.py:L82`) | optional literal, ASCII alphanumeric class, bounded `{1,24}` repeat | 0 |
| `SINGLE_QUOTE_RE`, `DOUBLE_QUOTE_RE` (`chardata.py:L28-L29`), `C1_CONTROL_RE` (L193) | literal ranges | 0 |
| `SURROGATE_RE`, `SURROGATE_PAIR_RE` (`fixes.py:L258-L259`) | ranges over U+D800..U+DFFF | Not testable: R cannot hold the input (5.7) |

A lint of the expanded classes found none of the characters that ICU treats specially inside a set
(`[`, `&&`, `--`, `[:`, `{`, `$`, `#`). The only hazards are the literal spaces above and the
literal U+0085, which is `Pattern_White_Space` and would be dropped under `comments=TRUE`.

The pattern text is identical under all four Pythons: the `\N{…}` names in upstream's literals
resolve to the same characters.

### 4.2 Bytes regexes

ICU has no bytes mode. Each was ported by decoding the pattern and the subject as Latin-1, so that
one byte is one code point.

| Regex (upstream location) | Constructs | Result |
|---|---|---|
| `ALTERED_UTF8_RE` (`chardata.py:L159-L166`) | byte classes, literal space | 0 mismatches |
| `LOSSY_UTF8_RE` (`chardata.py:L177-L188`) | byte classes | 0 |
| `A_GRAVE_WORD_RE` (`fixes.py:L416`) | negative lookahead with alternation | 0 |
| `CESU8_RE`, `SPECIAL_BYTES_RE` (`bad_codecs/utf8_variants.py:L58-L81`) | `$` inside groups | Default: 368 and 517 mismatches. `$` replaced by `\z`: 241 and 319, **wrong**, because Python's `$` also matches before a final `\n`. **`unix_lines`: 0** |

### 4.3 Engine features used, and ICU support

| Feature | ICU | Evidence |
|---|---|---|
| Literal non-ASCII characters and ranges in classes | Same | measured |
| `{m}`, `{m,n}`, `*`, `+`, `?`, alternation, capture and `(?:…)` groups | Same | measured |
| Fixed-width negative lookbehind, negative lookahead | Same; ICU only requires bounded lookbehind ([ICU regex guide](https://unicode-org.github.io/icu/userguide/strings/regexp.html)) | measured |
| `\xhh`, `\uhhhh`, `\Uhhhhhhhh`, `\N{NAME}` | Supported, plus `\x{h…}` | measured |
| `findall` count, `search`, `match`, `finditer` spans | `stri_count_regex`, `stri_detect_regex`, `stri_locate_all_regex`; stringi indexes by code point, as Python does | measured |
| `sub` with a function (`fixes.py:L139`, L292, L390, L439, L498, L510) | **Not available.** `stri_replace_*_regex` takes replacement strings only; these sites need locate, compute, splice | stringi API |
| Case-insensitive, multiline, dotall, backreferences, named groups, possessive or atomic groups | Not used upstream | inventory |

## 5. Where regex behaviour diverges

### 5.1 Free-spacing mode drops whitespace inside classes

- Python: whitespace is ignored "except when in a character class"
  ([`re.VERBOSE`](https://docs.python.org/3/library/re.html#re.VERBOSE)).
- ICU, measured on 71.1, 78.3 and 79.1 with `UREGEX_COMMENTS`:
  - `[ ]` fails with `U_REGEX_MISSING_CLOSE_BRACKET`.
  - `a[ b]` does not match `"a "`.
  - `[\ b]` and `[\x20b]` do match a space.
- The ICU guide's flag description does not mention this. stringi's regex page says whitespace is
  not ignored in regex sets, which is true only in the default mode.
- ICU also ignores more characters than Python outside classes. Python skips only
  space, `\t`, `\n`, `\r`, `\v`, `\f`. ICU skips all of `Pattern_White_Space`, which adds U+0085,
  U+200E, U+200F, U+2028 and U+2029; a literal U+0085 in a pattern was dropped under
  `comments=TRUE`.

Consequence: never use `comments=TRUE` for these patterns. Flatten them at build time.

### 5.2 `\s`, `\w`, `\d`

| Class | Python (str patterns) | ICU | Difference measured |
|---|---|---|---|
| `\s` | `str.isspace()`: 29 code points, identical in Python 3.9 to 3.14 | `White_Space`: 25 code points, identical in ICU 71.1, 78.3, 79.1 | Python also matches **U+001C..U+001F**. Nothing is ICU-only |
| `\w` | `str.isalnum()` or `_`: 133,023 (Unicode 13) to 142,940 (16) | `[\p{Alphabetic}\p{Mark}\p{Nd}\p{Pc}‌‍]`: 135,202 (Unicode 14) | Python-only by definition: 895 code points (Python 3.9 against the newer ICU 71.1), namely non-decimal numerics such as `²³¹`, `¼½¾`, circled and superscript digits. ICU-only by definition: 2,549 (ICU 71.1 against the newer Python 3.13), namely combining marks, connector punctuation other than `_`, ZWNJ, ZWJ. Version differences come on top |
| `\d` | category `Nd`: 650 (13), 680 (15.1), 760 (16) | category `Nd`: 660 (14), 770 (17 and 18) | Version only |

- The ICU guide documents `\s` as `[\t\n\f\r\p{Z}]`. All three ICU versions measured also match
  U+000B and U+0085, which is `White_Space`. The documentation is not exact here.
- These differences reach the badness heuristic directly. Three of the corpus failures, as code
  points: `E9 BB B2` is bad in Python and not in ICU (`²` is `\w` only in Python); `E9 BB 301` is
  bad in ICU and not in Python (a combining mark is `\w` only in ICU); `165 203A BD` is bad only in
  Python.
- `\w` grows with every Unicode version (9,917 code points added from 13.0 to 16.0, none removed).
  So Python ftfy on 3.9 and on 3.14 already disagree about `é»` followed by a letter first assigned
  in Unicode 14 to 16.
- `\s` is in practice version-independent: the same 29 code points on all four Pythons.

Consequence: replace all three with explicit sets generated from the chosen reference Python. Then
no regex depends on ICU's Unicode version at all.

### 5.3 `.`, `^`, `$`

| | Python (no flags) | ICU default | ICU with `unix_lines` |
|---|---|---|---|
| `.` does not match | U+000A | U+000A..U+000D, U+0085, U+2028, U+2029 | U+000A |
| `$` matches before a final | `\n` | any of the above, or CR LF | `\n` |
| `^` | start of text | start of text | start of text |

All measured (stringi on ICU 71.1; `.` and `$` also on ICU 78.3 and 79.1).

- `ENCODING_REGEXES` are the important case. With ICU defaults, `possible_encoding()` returns true
  for text that ends in U+2028 or U+0085 even when that character is not in the encoding. That
  would send such text down the wrong decode path.
- `\z` is a correct replacement for `$` in `ENCODING_REGEXES` only because `\n` is inside the class
  there. It is wrong for the CESU-8 patterns. `unix_lines=TRUE` is right for all of them.

Consequence: pass `stri_opts_regex(unix_lines = TRUE)` on every regex call.

### 5.4 Sets and escapes

No other difference was found. The classes contain no nested-set or set-operator syntax, and
the negated class, the class of single-character escapes and the escaped backslash-`N`-brace
sequence in `ESCAPE_SEQUENCE_RE` behave the same.

### 5.5 Backtracking limit

ICU keeps backtracking state on a heap stack limited to 8 MB by default (ICU regex guide;
`getStackLimit()` returned 8,000,000 on ICU 78.3 and 79.1). Python's `re` matched the same inputs
at 4,000,000 code points without error (measured on 3.9.6 and 3.14.5, both patterns below).

| Pattern | Input | Default limit |
|---|---|---|
| `ANSI_RE` | `ESC [` + n digits + `m` | fine at n = 100,000; **overflow at 200,000** (ICU 71.1, 78.3, 79.1) |
| `UTF8_DETECTOR_RE` (flat) | one unbroken run of two-character mojibake | fine at 300,000 code points; **overflow at 400,000** and above (ICU 71.1) |
| `BADNESS_RE`, `ENCODING_REGEXES` | 1,000,000 to 2,000,000 code points | fine |

- ftfy processes segments of up to `max_decode_length = 1_000_000` characters when there is no line
  break (`__init__.py:L226`, L348-L353), so a single long line of mojibake can reach the limit.
- **`stri_opts_regex(stack_limit = 0L)` did not lift the limit**, although its documentation says
  0 means no limit. `stack_limit = 1e9` did (tested to 4,000,000 code points for `ANSI_RE` and
  2,000,000 for `UTF8_DETECTOR_RE`). In ICU's own API, `setStackLimit(0)` does lift it.
- Rewriting the starred group in `ANSI_RE` as a single starred class also avoided the overflow.
  Possessive quantifiers did not help.

### 5.6 U+FEFF is silently stripped by parts of stringi

stringi documents that it "silently removes byte order marks" from UTF-8 strings
([about_encoding](https://stringi.gagolewski.com/rapi/about_encoding.html)). Measured on a string
starting with U+FEFF:

- **Dropped by:** `stri_replace_all_fixed`, `stri_sub`, `stri_trans_toupper`, `stri_enc_toutf32`,
  `stri_detect_charclass`.
- **Kept by:** `stri_replace_all_regex`, `stri_locate_all_regex`, `stri_trans_nfc`.
- A U+FEFF later in the string was kept in every case tried.
- For the same reason, the per-code-point comparisons in this research show U+FEFF as a spurious
  difference wherever a single-character string went through one of the first group.

Upstream removes U+FEFF deliberately and optionally (`remove_bom`, `fixes.py:L338`; `CONTROL_CHARS`,
`chardata.py:L105-L112`). A port must not let stringi remove it as a side effect when those fixers
are turned off, and position arithmetic must not mix functions from the two groups.

### 5.7 R string limits

- **U+0000** cannot occur in an R string (measured). Upstream's `ENCODING_REGEXES`, `CONTROL_CHARS`
  and `NULL_EXPR` all mention it; in R it can only appear in raw vectors.
- **Lone surrogates** cannot be held: `intToUtf8(0xD800)` is `NA`, and stringi raises an error on
  the UTF-8-style encoding of a surrogate. `fix_surrogates` (`fixes.py:L274-L294`) has no possible
  character-vector input, and the CESU-8 logic has to run on raw vectors.
- **`"\x80"` in R source is a raw byte**, not U+0080 (measured: encoding `unknown`, invalid UTF-8).
  Write C1 and Latin-1 code points as `"\u0080"`.

## 6. `unicodedata`, normalisation and string-method uses

| Use (upstream location) | Version-sensitive in Python? | ICU / stringi (measured against ICU 71.1) |
|---|---|---|
| `unicodedata.normalize(config.normalization, text)`, default NFC (`__init__.py:L225`, L414-L415) | Only for code points newer than the Python's Unicode version | `stri_trans_nfc/nfd/nfkc/nfkd`. Per-code-point NFC identical to Python 3.9, 3.13 and 3.14 for every code point. NFD, NFKC, NFKD differ only on code points unassigned on one side |
| `WIDTH_MAP`: NFKC of U+FF01..U+FFEF, plus U+3000 (`chardata.py:L233-L250`) | No: 225 mapped code points on all four Pythons | Identical: 225, 0 differences. Freeze as a table |
| `normalize("NFC", …)` before measuring width (`formatting.py:L76`) | As for NFC | As for NFC |
| `unicodedata.category` (`__init__.py:L799`, `explain_unicode` only) | Yes | No direct stringi accessor; derivable with `\p{..}` classes. Differences are code points unassigned on one side, plus two reclassifications (below) |
| `unicodedata.name(char, "<unknown>")` (`__init__.py:L800`, `explain_unicode` only) | Yes | `stri_trans_general(x, "Any-Name")`. Identical for every code point both sides name (137,714 against Python 3.9; 138,552 against 3.13 and 3.14). See below for the exceptions |
| `str.isprintable()` (`__init__.py:L791`, `explain_unicode` only) | Yes | No stringi equivalent. Deriving it from general category reproduced Python exactly, apart from unassigned code points |
| `char.upper()` when building upper-case entity names (`chardata.py:L78`) | Not for this table | `stri_trans_toupper` is locale-sensitive (`tr_TR` differs at `i`). In the root locale it differed from Python only where one side's Unicode version is newer (new letters, and new upper-case partners for U+019B and U+0264 in Unicode 16) |
| `html.entities.html5`, `html.unescape` (`chardata.py:L62-L79`, `fixes.py:L73-L91`) | No (section 7) | No ICU equivalent; ship a table |
| `codecs.decode(…, "unicode-escape")` (`fixes.py:L388`), including `\N{NAME}` | `\N{}` lookup is version-sensitive | Needs a name-to-character lookup; ICU regex and transliterators understand `\N{NAME}`. Opt-in function, not on the `fix_text` path |
| Python codec tables behind `ENCODING_REGEXES` and the sloppy codecs | No: identical on all four Pythons | Covered by another ticket; the character lists should be shipped as data, not taken from ICU converters |
| `text.find("\n")` segmentation (`__init__.py:L348-L361`), `fix_line_breaks` (`fixes.py:L249-L255`), `str.translate` tables | No | Literal operations. Split on `\n` only; ICU line-break helpers recognise more terminators |

### Normalisation: what can actually differ

- Unicode's stability policy guarantees that normalising a string of characters assigned in both
  versions gives the same result in both, since Unicode 4.1
  ([policy](https://www.unicode.org/policies/stability_policy.html)).
- Measured from Unicode 13.0 to 16.0 (Python 3.9 against 3.14): no existing row changed; 177 new
  code points have a non-trivial normal form; 62 new code points have a non-zero combining class;
  none of the new code points changes under NFC on its own.
- Sequences were checked as well: 200,000 random sequences of 2 to 6 code points (combining marks,
  decomposable characters, conjoining jamo and others, all assigned in Unicode 13.0) gave identical
  NFC, NFD, NFKC and NFKD on ICU 71.1 and on Python 3.9, 3.13 and 3.14. NFC changed 57,556 of them,
  so the comparison was not trivial. Combining classes agreed too: the only differences were code
  points assigned on one side only (40 ICU-only against Python 3.9, 22 Python-only against 3.14).
- So NFC output differs between a Python and an ICU only when the text contains a code point
  assigned after the older of the two Unicode versions. A new combining mark is then reordered by
  one side and not the other, and a new composing pair (for example Kirat Rai vowels, Unicode 16)
  is composed by one side and not the other.

### General category and names

- General category is not frozen by the stability policy (only `Cc`, `Co`, `Cs` membership is).
  Two already-assigned code points changed in the range measured: U+1734 went from `Mn` to `Mc` in
  Unicode 14, and U+1171E from `Mn` to `Mc` in Unicode 16. Both affect only `explain_unicode`
  output.
- Python (through 3.14) returns no name for Tangut ideographs (`unicodedata.name(chr(0x17000))`
  fails), while ICU names them; the 6,145 code points ICU names and Python 3.13/3.14 do not match
  the size of the Tangut ideograph ranges.
- For controls, unassigned and private-use code points Python gives upstream's default
  `<unknown>`; ICU's `Any-Name` gives `<control-0009>`, `<unassigned-0378>`,
  `<private use area-E000>`. A port must map those to `<unknown>`.

## 7. HTML entity table

- Upstream builds `HTML_ENTITIES` from Python's `html.entities.html5`, keeping names that end in
  `;`, and adds an upper-cased variant of each all-lower-case name when `html.unescape` does not
  already decode that upper-cased name (`chardata.py:L62-L79`).
- Re-creating that construction gives 2,125 names plus 1,376 upper-case variants, **3,501 entries,
  byte-identical on Python 3.9, 3.10, 3.13 and 3.14**. The table is a static list from the HTML5
  standard, not Unicode data ([`html.unescape`](https://docs.python.org/3/library/html.html#html.unescape)).
- 63 upper-case variants map to more than one code point, because `str.upper()` is a full case
  mapping (for example `ß` gives `SS`, `ﬁ` gives `FI`, `ŉ` gives `ʼN`) or because the entity value
  already has two code points.
- One entry can never match: `&CounterClockwiseContourIntegral;` is longer than the 24 name
  characters `HTML_ENTITY_RE` allows. A port should keep that quirk.
- Numeric references go through `html.unescape`, which applies HTML5 rules, not a plain
  `chr()`. Measured, identical on all four Pythons: `&#x80;` gives U+20AC; `&#x9F;` gives U+0178;
  `&#x81;` gives U+0081; `&#0;`, `&#xD800;` and `&#x110000;` give U+FFFD; `&#1;`, `&#x0B;`,
  `&#x7F;`, `&#xFDD0;`, `&#xFFFE;` and `&#x1FFFF;` give the empty string. Upstream then keeps the
  original text if a `;` survives (`fixes.py:L86-L89`).

Consequence: ship the 3,501-entry table and the HTML5 numeric-reference tables as generated data.
Do not compute the upper-case variants with `stri_trans_toupper` at run time.

## 8. `wcwidth` and the display-width helpers

This section is from documentation, except the `stri_width` values, which were measured.

### What upstream relies on

- `character_width` returns `wcwidth(char)`; `monospaced_width` returns `wcswidth` of the
  NFC-normalised text with ANSI escapes removed (`formatting.py:L34`, L76).
- The justification helpers require a fill character of width exactly 1 and return the text
  unpadded when the width is -1 (`formatting.py:L101-L110`).
- Upstream doctests expect: `\n` gives -1; U+0080 in a string gives -1; ZWJ gives 0;
  `owl<SOFT HYPHEN>flavored` gives 11; seven conjoining jamo give 6; the kaomoji line pads to 20
  with 7 fill characters, so it measures 13.

### `wcwidth` is a moving target

`pyproject.toml:L8` declares `dependencies = ["wcwidth"]` with no version bound; `uv.lock` records
0.2.13 for upstream's development. From the
[wcwidth history](https://wcwidth.readthedocs.io/en/latest/history.html):

| wcwidth | Change that alters ftfy output |
|---|---|
| 0.2.9 to 0.2.13 | Soft hyphen measures 0 (this is what upstream's doctest expects); tables to Unicode 15.1; Hangul jamo zero-width fix in 0.2.13 |
| 0.2.14 (2025-09) | Soft hyphen measures 1; tables to Unicode 16 and 17 |
| 0.3.0 (2026-01) | `Default_Ignorable_Code_Point` width 0; `Prepended_Concatenation_Mark` width 1 |
| 0.5.x (2026-01) | Only Unicode 17 tables shipped; spacing marks (`Mc`), standalone modifiers and regional indicators re-measured |
| 0.8.x (2026) | VS-15 narrows; cluster width capped at 2; tables to Unicode 18 |

`wcwidth` carries its own tables, so these results do not depend on the Python version, only on the
installed `wcwidth`.

### `stri_width` does not match

| Input | wcwidth (doctest or [spec](https://wcwidth.readthedocs.io/en/latest/specs.html)) | `stri_width` (measured) |
|---|---|---|
| `\n`, U+0001, U+001B, U+007F, U+0080 | -1 | 0 |
| String containing U+0080 | -1 | 7 for `example` + U+0080 |
| Soft hyphen | 0 in 0.2.9 to 0.2.13; 1 from 0.2.14 | 1 |
| Kaomoji doctest line | 13 | **21** |
| `°`, box-drawing characters, `□` (category `So`) | 1 (implied by the doctest total) | 2 |
| U+2028 | 0 (current spec) | 1 |
| ZWJ, combining marks, variation selector | 0 | 0 |
| CJK ideograph, kana, Hangul syllable, seven conjoining jamo | 2, 2, 2, 6 | same |

stringi's [documented rules](https://stringi.gagolewski.com/rapi/stri_width.html) explain this:
`Cc` controls are width 0 "for compatibility with the nchar function", and "most emojis and
characters with general category So" are width 2. On ICU 71.1 that was all 6,605 `So` code points.

Consequence: the display-width helpers need their own implementation: a width table generated from
one chosen `wcwidth` version, plus the -1 rule for C0, C1 and DEL. They cannot be a thin wrapper
around `stri_width`. These helpers are outside the `fix_text` path, apart from `explain_unicode`,
which pads with `display_ljust` (`__init__.py:L797`).

## 9. Strategy implied by the findings

Offered as input to the decision this ticket feeds, not as a decision.

1. **Choose a reference.** For example Python 3.13 (Unicode 15.1, the same Unicode version as
   stringi's bundled ICU 74.1) and the `wcwidth` in upstream's lock file (0.2.13). Record both.
2. **Generate, do not hand-port, the regexes.** A build-time script reads upstream's literals and
   emits flat patterns with frozen `\s`, `\w`, `\d` sets. At run time every call uses
   `unix_lines = TRUE` and a large explicit `stack_limit`, and never `comments = TRUE`. After this
   no regex depends on the ICU or Unicode version.
3. **Ship tables as data** generated from the reference Python: `WIDTH_MAP`, the HTML entity table
   and numeric-reference rules, the ligature and control-character maps, the codec character lists,
   and the width table.
4. **Accept one documented dependency on ICU's Unicode version: normalisation.** Output can differ
   from the reference only for text containing code points assigned after the older of the two
   Unicode versions. Avoiding even that would mean shipping normalisation data, which the size of
   the difference does not appear to justify.
5. **Treat `explain_unicode` as best effort**, or pin its category and name data too. It is the
   only user of `category`, `name` and `isprintable`.
6. **Test for parity with generated fixtures.** Fixtures produced by the reference Python should use
   only code points assigned in the oldest Unicode version supported (Unicode 10.0 if ICU 61 stays
   the floor), with a separate, clearly labelled set for newer code points. Run them against more
   than one ICU, since CRAN binaries and Linux system ICUs differ.

## 10. Open points

- stringi's bundled ICU 74.1, and Windows and Linux builds, were not measured.
- `wcwidth` itself was not run; its 0.2.13 behaviour is taken from its history page and upstream's
  doctests. The specification page describes the current release, not 0.2.13.
- Corpus parity is evidence over 120,390 random and curated strings. A proof would need the
  generated patterns to be compared structurally, which the generate-do-not-port approach gives
  for free.
- The Unicode version of ICU releases marked "inferred" in section 3 was not confirmed on a
  per-release page.
- Whether stringi's `stack_limit = 0L` behaviour is a stringi bug or intended was not investigated.
