# Upstream public surface inventory: Python ftfy v6.3.1

Research for issue #2. Answers: what is the complete public surface of Python ftfy v6.3.1, what does each config option do, in what order do fixers run, and what can the explain feature emit.

## Source and method

- Source: `https://github.com/rspeer/python-ftfy` at tag `v6.3.1`, commit `5340af6746ff655a9cd7cb2b50c2fd0b35bb91d3`. Apache-2.0 (`pyproject.toml:6`).
- Every citation below is `path:lines` in that commit. Permalink pattern: `https://github.com/rspeer/python-ftfy/blob/5340af6746ff655a9cd7cb2b50c2fd0b35bb91d3/<path>#L<start>-L<end>`.
- Read in full: `ftfy/__init__.py`, `ftfy/fixes.py`, `ftfy/formatting.py`, `ftfy/cli.py`, `ftfy/bad_codecs/__init__.py`, all of `docs/*.rst`, `CHANGELOG.md`, `pyproject.toml`, and the tests that exercise config and explain. Read in part: `ftfy/chardata.py` (lines 1-260, 670-691), `ftfy/badness.py` (1-21, 384-420), `ftfy/bad_codecs/sloppy.py`, `ftfy/bad_codecs/utf8_variants.py` (1-56 plus definitions).
- **Nothing was executed.** Upstream code was read, not run or installed. Statements about runtime behaviour are therefore derived by reading the code. Where a statement is a consequence I traced rather than something the source states outright, it is marked **(traced)**.
- There is no `__all__` anywhere in the package (grep over `ftfy/`), so "public" below means: not underscore-prefixed, and/or documented in `docs/`. Each item says whether the docs mention it.

## 1. Headline findings that affect the decisions

1. **Explain emits five action kinds, not the four documented.** `encode`, `decode`, `transcode`, `apply` are documented (`ftfy/__init__.py:39-44`, `733-738`); `fix_and_explain` also emits `("normalize", <form>)` (`ftfy/__init__.py:414-418`). `apply_plan` has no branch for `normalize` and raises `ValueError("Unknown plan step: ...")` (`ftfy/__init__.py:752-763`). So a plan from `fix_and_explain` is not always replayable **(traced)**.
2. **The four encoding sub-options are silently ignored whenever `explain` is false.** In `fix_and_explain`, when `steps is None` the code calls `fix_encoding(text)` with no config (`ftfy/__init__.py:394-396`), and `fix_encoding` then builds a default config (`598-599`). `fix_text` and `fix_text_segment` default to `explain=False` when no config object is passed (`340-341`, `616-617`). Consequence **(traced)**: `fix_text(t, restore_byte_a0=False)` ignores the option, while `fix_text(t, TextFixerConfig(restore_byte_a0=False))` honours it (that config has `explain=True`, so line 398 passes it through). Affected options: `restore_byte_a0`, `replace_lossy_sequences`, `decode_inconsistent_utf8`, and the encoding-stage use of `fix_c1_controls`. A port must choose between reproducing this and honouring the options.
3. **Config is one flat object of 16 fields, and keyword arguments are just overrides of it.** Every top-level fixing function takes `(text, config=None, **kwargs)`; kwargs are applied with `config._replace(**kwargs)` (`ftfy/__init__.py:230-247`). There is no per-function option subset.
4. **Fixer order differs between the config field order, the `FIXERS` dict order, and execution order.** Only execution order matters; see section 4.
5. **`fix_text` and `fix_and_explain` are not the same function with different return types.** `fix_text` splits into line segments, caps segment length, and makes `unescape_html="auto"` sticky across segments; `fix_and_explain` treats the whole input as one segment (`ftfy/__init__.py:346-361` vs `364-421`).
6. **`ftfy.formatting` (display-width helpers) has no page in the docs** (`docs/index.rst:21-33` toctree has no entry; no `docs/formatting.rst`) and is the only reason for the package's sole dependency, `wcwidth` (`pyproject.toml:8`, `ftfy/formatting.py:11`).

## 2. Top-level module `ftfy` (`ftfy/__init__.py`)

### 2.1 Functions

| Name | Signature | Returns | Default config when `config=None` | In docs |
|---|---|---|---|---|
| `fix_text` | `(text: str, config: TextFixerConfig \| None = None, **kwargs)` (`:290`) | `str` | `TextFixerConfig(explain=False)` (`:341`) | `docs/explain.rst:44` |
| `ftfy` | alias: `ftfy = fix_text` (`:606`) | `str` | same | no |
| `fix_and_explain` | `(text: str, config=None, **kwargs)` (`:364-366`) | `ExplainedText` | `TextFixerConfig()` so `explain=True` (`:375`) | `docs/explain.rst:48` |
| `fix_encoding_and_explain` | `(text: str, config=None, **kwargs)` (`:424-426`) | `ExplainedText` | `TextFixerConfig()` (`:448`) | `docs/explain.rst:54` |
| `fix_encoding` | `(text: str, config=None, **kwargs)` (`:586-588`) | `str` | `TextFixerConfig(explain=False)` (`:599`) | `docs/explain.rst:58` |
| `fix_text_segment` | `(text: str, config=None, **kwargs)` (`:609-611`) | `str` | `TextFixerConfig(explain=False)` (`:617`) | no |
| `fix_file` | `(input_file: TextIO \| BinaryIO, encoding: str \| None = None, config=None, **kwargs)` (`:623-628`) | `Iterator[str]` (generator of fixed lines) | `TextFixerConfig()` (`:640`) | no |
| `guess_bytes` | `(bstring: bytes)` (`:656`) | `tuple[str, str]` = (decoded text, encoding name) | n/a | `docs/detect.rst:22` |
| `apply_plan` | `(text: str, plan: list[tuple[str, str]])` (`:727`) | `str` | n/a | `docs/explain.rst:66` |
| `explain_unicode` | `(text: str)` (`:768`) | `None`; prints a table | n/a | `docs/explain.rst:73` |

Other module-level names: `__version__ = "6.3.1"` (`:27`), `FIXERS` (`:75-88`), `BYTES_ERROR_TEXT` (`:250-267`), classes `TextFixerConfig`, `ExplainedText`, `ExplanationStep`. Private helpers: `_config_from_kwargs`, `_try_fix`, `_fix_encoding_one_step_and_explain`.

### 2.2 Behaviour per function

**`fix_text`** (`:340-361`)
- Raises `UnicodeError(BYTES_ERROR_TEXT)` on `bytes` input (`:343-344`).
- Splits on `"\n"` only, keeping the newline at the end of each segment (`:349-351`). Other line-break characters do not split.
- A segment longer than `config.max_decode_length` is cut at exactly that many codepoints (`:352-353`). This is the only place `max_decode_length` is read (grep over `ftfy/`).
- `unescape_html="auto"`: once any segment contains `<`, the config is replaced with `unescape_html=False` and stays that way for all later segments (`:356-357`). Earlier segments are already unescaped.
- Each segment goes through `fix_and_explain`; explanations are discarded (`:358`). Docstring gives the reason: different segments may get different fixes (`:331-334`).
- Empty input returns `""` (loop at `:348` does not run) **(traced)**.

**`fix_and_explain`** (`:374-421`)
- Whole input is one segment; no line splitting, no length cap. Confirmed in `docs/explain.rst:50`.
- `unescape_html="auto"` is resolved once: `<` anywhere in the text disables it (`:380-381`).
- Runs the pipeline in section 4 repeatedly until a full pass leaves the text unchanged (`:389-421`). `docs/config.rst:6` states the purpose: output is unchanged by a second run of ftfy.
- Returns `ExplainedText(text, steps)`; `steps` is `None` when `config.explain` is false, otherwise a list accumulated across all passes (`:383-387`, `:421`).

**`fix_encoding_and_explain`** (`:447-465`)
- Only the mojibake stage. Loops `_fix_encoding_one_step_and_explain` until the text stops changing (`:458-465`), which is how multiple layers of mojibake get fixed.
- Always returns a list for the explanation, never `None`; it does not consult `config.explain` (`:456`, `:465`).
- If `config.fix_encoding` is false, returns the text unchanged with `[]` (`:453-456`).

**`fix_encoding`** (`:598-602`): calls `fix_encoding_and_explain(text, config)` and drops the explanation. Because it passes its config through, the four sub-options are honoured here, including via kwargs **(traced)**. It has no explicit bytes check of its own, but the callee has one (`:449-450`).

**`fix_text_segment`** (`:616-620`): `fix_and_explain` with the explanation dropped. Same `explain=False` default as `fix_text`, so finding 2 applies.

**`fix_file`** (`:639-653`)
- Iterates the file object's lines. A `bytes` line is decoded with `encoding`, or, if `encoding is None`, with `guess_bytes`; the guessed encoding is assigned back to `encoding`, so the guess from the first line is used for the rest of the file (`:644-648`).
- `unescape_html="auto"` is sticky across lines, like `fix_text` (`:649-650`).
- Each line is one `fix_and_explain` segment; no `max_decode_length` cap (`:652`).
- Default config has `explain=True`, so explanations are built and discarded, and sub-options are honoured **(traced)**. This contradicts the docstring claim that functions which do not return an explanation "will automatically set `explain` to False" (`:208-209`); that is true only for `fix_text`, `fix_encoding`, `fix_text_segment`, and only when no config object is passed.

**`guess_bytes`** (`:681-724`)
- Raises `UnicodeError` if given `str` (`:681-685`).
- Order: BOM `FE FF` or `FF FE` gives `"utf-16"` (`:687-688`); else try `"utf-8-variants"` if byte `0xED` or `0xC0` is present, otherwise `"utf-8"` (`:691-716`); on decode failure, `"macroman"` if the bytes contain `0x0D` and no `0x0A` (`:720-722`); else `"sloppy-windows-1252"` (`:724`).
- Documented as not recommended and possibly inaccurate (`:657-666`, `docs/detect.rst:18-20`). Cannot guess CJK legacy encodings (`docs/detect.rst:20`).

**`apply_plan`** (`:751-765`): replays a plan. `encode` calls `.encode(arg)`, `decode` calls `.decode(arg)`, `transcode` and `apply` are handled identically by looking `arg` up in `FIXERS` (`:757-759`). Unknown function name or unknown action raises `ValueError` (`:761`, `:763`). `docs/explain.rst:33-37` shows a plan being applied to a different string with the same problem.

**`explain_unicode`** (`:790-802`): for each codepoint prints `U+{code:04X}  {display} [{category}] {name}`, where `display` is the character (or its `unicode-escape` form if not printable) left-justified to display width 7 with `display_ljust`, `category` is the Unicode general category and `name` is the Unicode name or `<unknown>`. Prints to stdout; returns `None`.

### 2.3 Keyword arguments

- `_config_from_kwargs` (`:230-247`) applies kwargs with `config._replace(**kwargs)`. Kwargs override fields of a passed config too, since replacement happens after the config is chosen (`:342`, `:378`, `:600`).
- `fix_entities` is accepted as a deprecated alias of `unescape_html`, with a `DeprecationWarning` (`:237-245`; `CHANGELOG.md:67-68`).
- An unknown keyword is passed to `NamedTuple._replace`, which raises. The exception type comes from the Python standard library, not from ftfy, and was not verified here.
- `docs/config.rst:29-31` documents kwargs as an alternative to `config`. `CHANGELOG.md:112-114` says the config object replaced "a pile of named keyword arguments" in 6.0 and that kwargs "still work".
- `CHANGELOG.md:298-299` (v5.0) says top-level functions require options as keyword arguments. At 6.3.1 `config` is a normal positional-or-keyword parameter; only the individual options are keyword-only in effect.

### 2.4 Classes

**`ExplainedText`** (`:61-71`): `NamedTuple` with `text: str` and `explanation: list[ExplanationStep] | None`. Unpacks as a 2-tuple (`fixed, explanation = fix_and_explain(...)`, `docs/explain.rst:20`). Documented at `docs/explain.rst:62`.

**`ExplanationStep`** (`:35-58`): `NamedTuple` with `action: str` and `parameter: str`. Its `repr` is the repr of the plain tuple, e.g. `('encode', 'latin-1')` (`:53-58`). Not given its own entry in the docs. Tests compare steps to plain tuples (`tests/test_characters.py:53-56`).

**`TextFixerConfig`**: section 3.

**`FIXERS`** (`:75-88`): dict of name to function for the 12 names that may appear as the parameter of `apply` or `transcode`. In dict order: `unescape_html`, `remove_terminal_escapes`, `restore_byte_a0`, `replace_lossy_sequences`, `decode_inconsistent_utf8`, `fix_c1_controls`, `fix_latin_ligatures`, `fix_character_width`, `uncurl_quotes`, `fix_line_breaks`, `fix_surrogates`, `remove_control_chars`. Not in `FIXERS`: `decode_escapes`, `remove_bom`.

## 3. `TextFixerConfig` (`ftfy/__init__.py:91-227`)

A `NamedTuple` with defaults; immutable; constructed with keyword overrides (`:95-99`). Fields in declaration order (`:212-227`):

| # | Field | Type | Default | Effect (docstring lines) |
|---|---|---|---|---|
| 1 | `unescape_html` | `str \| bool` | `"auto"` | Replace HTML entities with their characters. `"auto"` means on, unless a literal `<` appears, in which case the input is assumed to be real HTML and entities are kept. `True` always, `False` never (`:103-109`). |
| 2 | `remove_terminal_escapes` | `bool` | `True` | Remove ANSI terminal escapes such as colour codes (`:111-114`). |
| 3 | `fix_encoding` | `bool` | `True` | Detect mojibake and fix it by re-decoding (`:116-119`). |
| 4 | `restore_byte_a0` | `bool` | `True` | Sub-option of `fix_encoding`. Let a plain space stand for byte A0 (non-breaking space) when that makes a mojibake sequence decodable. Off is safer against false positives but misses fixes (`:124-132`). |
| 5 | `replace_lossy_sequences` | `bool` | `True` | Sub-option. Where mojibake has been partly replaced by `�` or `?`, replace the damaged sequence with `�` so the rest can decode (`:134-138`). |
| 6 | `decode_inconsistent_utf8` | `bool` | `True` | Sub-option. Decode sequences that clearly look like UTF-8 mojibake even when the string as a whole cannot be consistently re-decoded; handles strings concatenated from different encodings (`:140-147`). `docs/config.rst:16` recommends turning this off to be cautious. |
| 7 | `fix_c1_controls` | `bool` | `True` | Replace C1 control characters with their Windows-1252 equivalents, as HTML5 does (`:149-153`). Listed as a sub-option of `fix_encoding`, but see the notes below. |
| 8 | `fix_latin_ligatures` | `bool` | `True` | Replace Latin ligatures such as `ﬁ` with their letters (`:155-158`). |
| 9 | `fix_character_width` | `bool` | `True` | Replace fullwidth Latin and halfwidth katakana with standard-width forms (`:160-163`). `docs/config.rst:12` recommends off to preserve CJK spacing. |
| 10 | `uncurl_quotes` | `bool` | `True` | Replace curly quotes with straight quotes (`:165-167`). |
| 11 | `fix_line_breaks` | `bool` | `True` | Convert line breaks to `\n` (`:169-172`). |
| 12 | `fix_surrogates` | `bool` | `True` | Replace UTF-16 surrogate pairs with the character they encode (`:174-179`). |
| 13 | `remove_control_chars` | `bool` | `True` | Remove control characters with no displayed effect (`:181-183`). |
| 14 | `normalization` | `"NFC" \| "NFD" \| "NFKC" \| "NFKD" \| None` | `"NFC"` | Unicode normalization form applied last; `None` for none. NFKC is noted as meaning-changing, e.g. `10³` to `103` (`:185-196`). |
| 15 | `max_decode_length` | `int` | `1000000` | Maximum segment size `fix_text` fixes at once (`:198-200`). |
| 16 | `explain` | `bool` | `True` | Whether to build explanations. When false the explanation is `None` and the explain code is skipped (`:202-209`). |

Notes the signatures do not show:

- **Sub-options versus `explain`**: finding 2 in section 1.
- **`fix_c1_controls` is used in two places.** Inside the encoding stage it is one of the fallbacks (`:572-575`), and it is also the first fixer in the main loop (`:403`), where it runs whether or not `fix_encoding` is on. So the docstring statement that the four sub-options "do nothing if `fix_encoding` is False" (`:121-122`) does not hold for this one **(traced)**.
- **The other three sub-options are never applied from the main loop.** `restore_byte_a0`, `replace_lossy_sequences`, `decode_inconsistent_utf8` are read only inside `_fix_encoding_one_step_and_explain` (`:510`, `:522`, `:542`).
- **`fixes.decode_inconsistent_utf8` recurses into `ftfy.fix_encoding(substr)` with no config** (`ftfy/fixes.py:494`), so embedded fixes always use default sub-options **(traced)**.
- **`max_decode_length`** applies only to `fix_text` (`:352-353`). `fix_and_explain`, `fix_text_segment`, `fix_encoding`, `fix_file` have no cap.
- **Docstring range typo**: the docstring gives C1 controls as U+80 to U+9B (`:151`); the regex is `[\x80-\x9f]` (`ftfy/chardata.py:193`).
- The default-on set is deliberate: `docs/config.rst:8` says all fixes are on by default and tells users to check they suit their case; `docs/config.rst:10` says to set `unescape_html=False` if output will be interpreted as HTML.

## 4. Order of execution

Three orderings exist and they disagree. Config field order is section 3. `FIXERS` order is section 2.4. **Execution order is this** (`ftfy/__init__.py:389-421`), repeated until a pass changes nothing:

1. `unescape_html` (`:392`)
2. the encoding stage, if `config.fix_encoding` (`:394-400`)
3. `fix_c1_controls`
4. `fix_latin_ligatures`
5. `fix_character_width`
6. `uncurl_quotes`
7. `fix_line_breaks`
8. `fix_surrogates`
9. `remove_terminal_escapes`
10. `remove_control_chars` (items 3-10: list at `:402-411`)
11. Unicode normalization, if `config.normalization is not None` (`:414-418`)

Each named fixer runs only if its config field is truthy (`_try_fix`, `:280`).

Why the loop matters: later fixers unlock earlier ones on the next pass. `docs/index.rst:54-57` gives mojibake that "cannot be consistently decoded until the quotes are uncurled", and `docs/explain.rst:24-29` shows three `unescape_html` steps before the encoding steps for a triply escaped string.

Changelog discrepancy: `CHANGELOG.md:310-311` (v4.4.0) says the entities fixer "is now applied after `fix_encoding`". At 6.3.1 `unescape_html` runs first. No changelog entry records the change back. For the port, the source order at 6.3.1 is the one to follow, since it determines the order of steps in an explanation.

### 4.1 Inside the encoding stage

`fix_encoding_and_explain` repeats one step until no change (`:459-465`). One step (`_fix_encoding_one_step_and_explain`, `:468-583`) is, in order:

1. Empty text: unchanged (`:477-478`).
2. Text that is pure ASCII, or for which `badness.is_bad(text)` is false: unchanged (`:482-483`). The badness heuristic gates the whole stage.
3. For each encoding in `chardata.CHARMAP_ENCODINGS`, in this order (`ftfy/chardata.py:15-26`): `latin-1`, `sloppy-windows-1252`, `sloppy-windows-1251`, `sloppy-windows-1250`, `sloppy-windows-1253`, `sloppy-windows-1254`, `sloppy-windows-1257`, `iso-8859-2`, `macroman`, `cp437`:
   - skip unless every character is representable in that encoding (`possible_encoding`, `:494`);
   - encode to bytes (`:496`);
   - if `config.restore_byte_a0`, the encoding is not `macroman`, and `ALTERED_UTF8_RE` matches the bytes: apply `fixes.restore_byte_a0` (`:509-519`);
   - if `config.replace_lossy_sequences` and the encoding name starts with `sloppy`: apply `fixes.replace_lossy_sequences` (`:522-528`);
   - decode as `utf-8-variants` if byte `0xED` or `0xC0` is present, else `utf-8` (`:530-535`);
   - the first encoding whose bytes decode successfully wins and the step returns (`:536`); a `UnicodeDecodeError` moves to the next encoding (`:538-539`). There is no scoring between candidates.
4. If `config.decode_inconsistent_utf8` and `UTF8_DETECTOR_RE` matches: apply `fixes.decode_inconsistent_utf8`; return if it changed anything (`:542-546`).
5. If the text is representable in `latin-1`: try `text.encode("latin-1").decode("windows-1252")` (strict Windows-1252) and return if it changed anything (`:551-569`). The guard at `:552` tests for the name `"windows-1252"` in a list that can only contain `"sloppy-windows-1252"`, so the "probably legit" early return at `:553-555` is unreachable **(traced)**.
6. If `config.fix_c1_controls` and `C1_CONTROL_RE` matches: apply `fixes.fix_c1_controls` and return (`:572-575`).
7. Otherwise unchanged (`:583`). Mix-ups between two single-byte encodings other than Latin-1 versus Windows-1252 are deliberately not attempted (`:577-582`, `docs/encodings.rst:26`).

Supported mix-ups as documented: text decoded as Latin-1, Windows-1250/1251/1252/1253/1254/1257, ISO-8859-2, MacRoman or cp437 that was really UTF-8 or CESU-8, plus Windows-1252 decoded as Latin-1 (`docs/encodings.rst:6-24`). Not supported: CJK legacy encodings (`docs/encodings.rst:28`).

## 5. Explain output

### 5.1 Shape

`ExplainedText(text, explanation)` where `explanation` is `None` or a flat ordered list of `(action, parameter)` string pairs (section 2.4). No nesting, no per-step before/after text, no positions, no record of which pass produced a step.

### 5.2 Every step that can be emitted

Enumerated from the emit sites in `ftfy/__init__.py`, not from the docstring.

| Action | Parameter values | Emitted at | Emitted by |
|---|---|---|---|
| `apply` | `unescape_html`, `fix_c1_controls`, `fix_latin_ligatures`, `fix_character_width`, `uncurl_quotes`, `fix_line_breaks`, `fix_surrogates`, `remove_terminal_escapes`, `remove_control_chars` | `:284` via `_try_fix` | `fix_and_explain` only |
| `apply` | `decode_inconsistent_utf8` | `:543` | encoding stage |
| `encode` | any of the 10 `CHARMAP_ENCODINGS` names | `:497` | encoding stage |
| `encode` | `latin-1` (Latin-1 to Windows-1252 fallback) | `:564` | encoding stage |
| `transcode` | `restore_byte_a0` | `:517` | encoding stage, between an `encode` and a `decode` |
| `transcode` | `replace_lossy_sequences` | `:526` | encoding stage, between an `encode` and a `decode` |
| `transcode` | `fix_c1_controls` | `:573` | encoding stage, standalone |
| `decode` | `utf-8`, `utf-8-variants` | `:533` | encoding stage |
| `decode` | `windows-1252` | `:565` | encoding stage |
| `normalize` | `NFC`, `NFD`, `NFKC`, `NFKD` (the configured form) | `:417` | `fix_and_explain` only |

So `fix_encoding_and_explain` can emit `encode`, `transcode`, `decode` and `apply decode_inconsistent_utf8`; `fix_and_explain` can emit all of the above.

### 5.3 Rules and irregularities

- **Recorded only on change.** `_try_fix` records a step only if the fixer changed the text (`:283-284`); `normalize` likewise (`:416-417`).
- **Accumulates across passes**, so the same step can repeat (`docs/explain.rst:24-29`).
- **Encode/decode come in groups**: `encode`, zero to two `transcode`, `decode` (`:534`). Documented example: `[('encode', 'latin-1'), ('transcode', 'restore_byte_a0'), ('decode', 'utf-8')]` (`:443-444`).
- **`transcode` does not always mean bytes to bytes.** The documented meaning is bytes to bytes (`:43`), and that holds for `restore_byte_a0` and `replace_lossy_sequences` (`ftfy/fixes.py:419`, `:442`). `("transcode", "fix_c1_controls")` operates on a string (`ftfy/fixes.py:505`), outside any encode/decode group. The same function appears as `("apply", "fix_c1_controls")` when run from the main loop. `apply_plan` treats the two actions identically, which is why this works upstream.
- **`decode_inconsistent_utf8` is labelled `apply`** in the plan (`:543`) though its docstring calls it a "transcoder" (`ftfy/fixes.py:486`).
- **`normalize` is not replayable** by `apply_plan` (finding 1). The test suite replays every passing test case through `apply_plan` (`tests/test_examples_in_json.py:58-59`), which implies none of those cases produces a `normalize` step; I did not run it.
- **A no-op step looks possible**: the C1 fallback returns its step without checking that the text changed (`:572-575`), and the C1 fixer maps bytes that Windows-1252 leaves unassigned to the same codepoint (`ftfy/fixes.py:501-502`, `ftfy/bad_codecs/sloppy.py:103-108`) **(traced, not run)**.
- **Encoding names in steps are Python codec names**, including ftfy's own `sloppy-windows-125x` and `utf-8-variants` (section 8). They are part of the visible output.
- **Explanations are per call, never per segment.** `fix_text` cannot return one (`:331-337`).

## 6. `ftfy.fixes` (`ftfy/fixes.py`)

Documented members are exactly the 13 listed in `docs/fixes.rst:5-9`. The module docstring singles out `decode_escapes` and `unescape_html` as useful on their own (`:6-10`).

| Function | Signature | In `FIXERS` | Config field | Documented | Effect |
|---|---|---|---|---|---|
| `unescape_html` | `(text: str) -> str` (`:94`) | yes | `unescape_html` | yes | Decode HTML entities matching `&#?[0-9A-Za-z]{1,24};` (`ftfy/chardata.py:82`). Named entities must end in a semicolon and be in the HTML5 table, or be the all-caps form of an all-lowercase name, which decodes to the uppercased character (`ftfy/chardata.py:62-79`). Numeric references use `html.unescape` and are left alone if the result still contains `;` (`:81-89`). Unknown names are left alone (`:90-91`). |
| `remove_terminal_escapes` | `(text: str) -> str` (`:145`) | yes | same name | yes | Delete matches of `ESC [ (digits or ;)* letter` (`ANSI_RE`, `:142`). |
| `uncurl_quotes` | `(text: str) -> str` (`:158`) | yes | same name | yes | U+02BC and U+2018 to U+201B become `'`; U+201C to U+201F become `"` (`ftfy/chardata.py:28-29`). |
| `fix_latin_ligatures` | `(text: str) -> str` (`:168`) | yes | same name | yes | Translate 22 codepoints (Dutch IJ, Afrikaans `ŉ`, Serbian/Croatian digraphs, `ﬀ` to `ﬆ`) to their letters (`ftfy/chardata.py:207-230`). Other scripts' ligatures are untouched (`:176-178`). |
| `fix_character_width` | `(text: str) -> str` (`:186`) | yes | same name | yes | U+3000 becomes a space; each of U+FF01 to U+FFEF becomes its NFKC form where that differs (`ftfy/chardata.py:233-247`). |
| `fix_line_breaks` | `(text: str) -> str` (`:206`) | yes | same name | yes | CRLF, CR, U+2028, U+2029, U+0085 become `\n`, in that order (`:249-255`). |
| `fix_surrogates` | `(text: str) -> str` (`:274`) | yes | same name | yes | Valid surrogate pairs become the astral character; remaining lone surrogates become U+FFFD (`:291-294`). |
| `remove_control_chars` | `(text: str) -> str` (`:297`) | yes | same name | yes | Delete U+0000 to U+0008, U+000B, U+000E to U+001F, U+007F, U+206A to U+206F, U+FEFF, U+FFF9 to U+FFFC (`ftfy/chardata.py:105-113`). Leaves tab, LF, FF, CR, C1 controls, bidi and joiner controls, tag characters (`:313-325`). |
| `restore_byte_a0` | `(byts: bytes) -> bytes` (`:419`) | yes | same name | yes | First insert A0 after byte C3 followed by a single space, keeping the space, except before the listed Portuguese forms (`A_GRAVE_WORD_RE`, `:416`, `:433`); then replace the space with A0 inside each `ALTERED_UTF8_RE` match (`:435-439`). |
| `replace_lossy_sequences` | `(byts: bytes) -> bytes` (`:442`) | yes | same name | yes | Replace each `LOSSY_UTF8_RE` match with the UTF-8 bytes of U+FFFD (`:478`). Relies on the sloppy codecs encoding U+FFFD as byte 1A (`ftfy/bad_codecs/sloppy.py:110-112`). |
| `decode_inconsistent_utf8` | `(text: str) -> str` (`:481`) | yes | same name | yes | For each `UTF8_DETECTOR_RE` match that is shorter than the whole text and `is_bad`, replace it with `ftfy.fix_encoding(match)` (`:489-498`). |
| `fix_c1_controls` | `(text: str) -> str` (`:505`) | yes | same name | yes | Each U+0080 to U+009F character is re-read as `sloppy-windows-1252` (`:501-510`). |
| `decode_escapes` | `(text: str) -> str` (`:355`) | no | none | yes | Decode Python-style backslash escapes (`\U`, `\u`, `\x`, octal, `\N{...}`, single-character) and leave other text alone (`:342-352`, `:386-390`). Never run automatically (`:360-362`). |
| `remove_bom` | `(text: str) -> str` (`:330`) | no | none | no | Strip leading U+FEFF (`:338`). Superseded by `remove_control_chars` (`CHANGELOG.md:364-365`). |
| `convert_surrogate_pair` | `(match: Match[str]) -> str` (`:262`) | no | none | no | Regex callback used by `fix_surrogates`. |
| `fix_encoding_and_explain` | `(text: str) -> Any` (`:37`) | no | none | no | Deprecated shim to `ftfy.fix_encoding_and_explain`; `DeprecationWarning`; no config or kwargs. |
| `fix_encoding` | `(text: str) -> str` (`:49`) | no | none | no | Deprecated shim, as above. |
| `apply_plan` | `(text: str, plan) -> str` (`:61`) | no | none | no | Deprecated shim, as above. |

Module-level regexes also exposed: `ANSI_RE` (`:142`), `SURROGATE_RE`, `SURROGATE_PAIR_RE` (`:258-259`), `ESCAPE_SEQUENCE_RE` (`:342-352`), `A_GRAVE_WORD_RE` (`:416`).

Changelog behaviour for these fixers:
- `unescape_html` decodes `&#128;` to `&#159;` as their Windows-1252 characters (`CHANGELOG.md:283-285`).
- The all-caps entity extension, and the reason `html.unescape` is not applied wholesale ("This&NotThat") (`CHANGELOG.md:158-172`).
- `uncurl_quotes` also replaces MODIFIER LETTER APOSTROPHE (`CHANGELOG.md:239-240`).
- Latin digraphs are split even under NFC (`CHANGELOG.md:242-246`).
- `remove_control_chars` must not remove CR; that is `fix_line_breaks`'s job (`CHANGELOG.md:329-330`).
- `remove_terminal_escapes` was accidentally unused in 6.0 and restored in 6.0.1 (`CHANGELOG.md:82-83`).
- Default normalization changed from NFKC to NFC in 4.0, with `fix_character_width` and the ligature fixer added as targeted replacements (`CHANGELOG.md:456-467`).

## 7. `ftfy.formatting` (`ftfy/formatting.py`)

Not in the docs toctree (finding 6). Added in 4.1.0 (`CHANGELOG.md:445-447`). All width logic delegates to `wcwidth`.

| Function | Signature | Behaviour |
|---|---|---|
| `character_width` | `(char: str) -> int` (`:16`) | `wcwidth(char)`: 0, 1 or 2, or -1 for a control or non-printable character (`:18-23`, `:34`). |
| `monospaced_width` | `(text: str) -> int` (`:37`) | NFC-normalize, strip terminal escapes, then `wcswidth` (`:71-76`). -1 if any control or non-printable character is present (`:46`). Ignoring ANSI escapes dates from 6.0.3 (`CHANGELOG.md:70-71`). |
| `display_ljust` | `(text: str, width: int, fillchar: str = " ") -> str` (`:79`) | Pad on the end to display width `width`. |
| `display_rjust` | `(text: str, width: int, fillchar: str = " ") -> str` (`:113`) | Pad at the start. |
| `display_center` | `(text: str, width: int, fillchar: str = " ") -> str` (`:142`) | Pad both sides; the extra cell goes on the end (`:164-166`). |

All three `display_*` functions raise `ValueError` if `fillchar` does not have display width 1, return the text unchanged if its width is -1, and never truncate (`:101-110`). `explain_unicode` depends on `display_ljust` (`ftfy/__init__.py:25`, `:797`).

## 8. Supporting modules

**`ftfy.badness`** (`docs/heuristic.rst:9-10` documents `badness` and `is_bad`)
- `badness(text: str) -> int`: number of matches of `BADNESS_RE` (`ftfy/badness.py:403-409`).
- `is_bad(text: str) -> bool`: whether `BADNESS_RE` matches at all (`:412-420`). The docstring warns that longer strings are more likely to be flagged. Promoted as a public heuristic in 6.0 (`CHANGELOG.md:107-110`).
- `sequence_weirdness(text: str) -> int`: old name; warns and calls `badness` (`:390-400`).
- Data: `MOJIBAKE_CATEGORIES` (`:22`), `BADNESS_RE` (`:274`).

**`ftfy.chardata`** (not documented as API; `docs/heuristic.rst:15`, `:24` name two of its regexes)
- `possible_encoding(text: str, encoding: str) -> bool` (`ftfy/chardata.py:86-94`).
- Data: `CHARMAP_ENCODINGS`, `SINGLE_QUOTE_RE`, `DOUBLE_QUOTE_RE`, `ENCODING_REGEXES`, `HTML_ENTITY_RE`, `HTML_ENTITIES`, `CONTROL_CHARS`, `ALTERED_UTF8_RE`, `LOSSY_UTF8_RE`, `C1_CONTROL_RE`, `LIGATURES`, `WIDTH_MAP`, `UTF8_CLUES`, `UTF8_DETECTOR_RE` (line numbers in the grep of top-level definitions: 15, 28, 29, 59, 82, 83, 119, 159, 177, 193, 207, 250, 260, 679).

**`ftfy.bad_codecs`** (`docs/bad_encodings.rst`)
- Importing any part of `ftfy` registers a codec search function with Python's codec registry (`ftfy/bad_codecs/__init__.py:19-21`, `:101`). This is a process-wide side effect and is how the names in explain steps resolve.
- `search_function(encoding: str) -> Optional[codecs.CodecInfo]` (`:55`), `ok() -> None` (`:89`), `UTF8_VAR_NAMES` (`:41-52`): aliases `utf-8-variants`, `utf8-variants`, `utf-8-variant`, `utf8-variant`, `utf-8-var`, `utf8-var`, `cesu-8`, `cesu8`, `java-utf-8`, `java-utf8` after normalization.
- `ftfy.bad_codecs.sloppy`: `make_sloppy_codec(encoding: str) -> codecs.CodecInfo` (`ftfy/bad_codecs/sloppy.py:83`), `CODECS`, `INCOMPLETE_ENCODINGS` (`:156-162`). Defines `sloppy-windows-1250` to `-1258`, `sloppy-cp1250` to `-cp1258`, `sloppy-cp874`, `sloppy-iso-8859-3/6/7/8/11`. Unassigned bytes map to the same-numbered codepoint, and byte 1A encodes U+FFFD (`:103-112`). The docstring says five of these are used inside ftfy (`:51-52`); `CHARMAP_ENCODINGS` uses six, 1257 having been added in 6.3.0 (`CHANGELOG.md:10`).
- `ftfy.bad_codecs.utf8_variants`: codec `utf-8-variants` (`NAME`, `:52`), `IncrementalDecoder`, `IncrementalEncoder`, `StreamWriter`, `StreamReader`, `CODEC_INFO` (`:84`, `:233`, `:236`, `:242`, `:248`). Decodes UTF-8, CESU-8 and Java's `C0 80` null; encoding produces standard UTF-8 (module docstring, `:1-40`).

## 9. Command line (`ftfy/cli.py`)

Entry point `ftfy = "ftfy.cli:main"` (`pyproject.toml:11-12`); also runnable as a module through the `__main__` guard (`ftfy/cli.py:141-142`). There is no `ftfy/__main__.py`.

`usage: ftfy [-h] [-o OUTPUT] [-g] [-e ENCODING] [-n NORMALIZATION] [--preserve-entities] [filename]` (`docs/cli.rst:10-12`)

| Argument | Default | Meaning | Lines |
|---|---|---|---|
| `filename` | `-` (stdin) | File to fix; always read as bytes | `:53-58`, `:99-104` |
| `-o`, `--output` | `-` (stdout) | Output file, written as UTF-8 | `:59-65`, `:106-112` |
| `-g`, `--guess` | off | Guess the input encoding with `guess_bytes`; overrides `-e` | `:66-71`, `:95-97` |
| `-e`, `--encoding` | `utf-8` | Input encoding | `:72-78` |
| `-n`, `--normalization` | `NFC` | Normalization form; `none` (any case) disables | `:79-85`, `:114-116` |
| `--preserve-entities` | off | Sets `unescape_html=False`; otherwise `"auto"` | `:86-91`, `:118-122` |

- Only `normalization` and `unescape_html` are configurable from the CLI; all other options keep their defaults (`:124`).
- Processing is `fix_file(file, encoding=encoding, config=config)`, written line by line (`:127-129`).
- Errors, each to stderr with exit status 1: same input and output path (`:109-111`, since 5.2 per `CHANGELOG.md:236-237`); input not decodable in the stated encoding (`:136-138`); output stream cannot encode the text, with separate Windows and Unix messages (`:130-135`).
- `docs/cli.rst:14` still shows "version 6.0" in the sample help text; the real string uses `__version__` (`ftfy/cli.py:51`).

## 10. Other documented behaviour worth carrying

- Input must be text, not bytes; ftfy is a mojibake fixer, not an encoding detector (`docs/detect.rst:4-8`, `docs/index.rst:13-15`).
- Strong stated goal of no false positives: correctly decoded text should never be changed (`docs/index.rst:72`), with `'IL Y MARQUÉ…'` as the canonical unchanged example (`docs/index.rst:74-77`).
- `fix_encoding` alone may leave some mojibake unfixable because it is entangled with other problems such as curly quotes (`docs/config.rst:20`).
- Since 6.0 the heuristic does not depend on the Unicode version (`CHANGELOG.md:99-105`).
- Test data: `tests/test_cases.json` holds 161 cases (151 `"expect": "pass"`, 10 `"fail"`) with keys `label`, `original`, `fixed`, `expect`, and optional `fixed-encoding` (33 cases) and `comment` (`tests/test_examples_in_json.py:14-25`). It was moved to JSON to "ease porting to other languages" (`CHANGELOG.md:267-268`). The test asserts, per passing case: `fix_text(original) == fixed`; both explain functions produce plans that `apply_plan` replays to the same result; `fix_text` with every non-encoding fixer off equals `fix_encoding`; and the result survives one extra layer of UTF-8-as-Latin-1 mojibake (`tests/test_examples_in_json.py:47-89`).
- Requires Python 3.9 or later; one runtime dependency, `wcwidth` (`pyproject.toml:8-9`).

## 11. Not verified

- Nothing was run, so every **(traced)** item is a reading of the control flow, not an observed result. The two with the most consequence for the port are finding 1 (`normalize` not replayable) and finding 2 (sub-options ignored when `explain` is false). Both are worth confirming against an installed ftfy 6.3.1 before the port either copies or departs from them.
- The exception raised for an unknown keyword argument comes from Python's `NamedTuple._replace` and was not checked.
- `ftfy/badness.py` lines 22-383 and `ftfy/chardata.py` lines 260-669 (the heuristic's character tables and regex body) were not read; they are data for the heuristic, not surface.
- `README.md`, `notes/`, `notebook/` and `scripts/` were not reviewed beyond a grep of the README for API names.
