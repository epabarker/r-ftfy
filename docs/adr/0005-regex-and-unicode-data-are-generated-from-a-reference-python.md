# Regex and Unicode data are generated from a reference Python, and ICU only normalises

Reference behaviour is what Python ftfy 6.3.1 does on Python 3.13. Every regex the package uses is generated from installed ftfy 6.3.1 running on that Python, with Python's meanings of `\s`, `\w` and `\d` written in as explicit code-point sets. Every regex call passes `unix_lines = TRUE` and `stack_limit = 1e9` and never `comments = TRUE`. The only Unicode data taken from the user's ICU at run time is normalisation.

The package uses stringi, so ICU's own `\w` and `\s` and its default regex options look like the natural choice. They give different answers from Python: the two engines define `\s` and `\w` differently (Python's `\w` includes `²` and `½`, ICU's includes combining marks), which changes badness scores; ICU's `.` and `$` treat U+2028, U+0085 and CR as line ends, which sends text down the wrong decode path; `comments = TRUE` silently drops spaces inside character classes; and ICU's default backtracking limit overflows inside upstream's 1,000,000-character segment. Even Python ftfy is not single-valued: `\w`, `\d` and normalisation follow the running Python's Unicode version (13.0 on Python 3.9 to 16.0 on 3.14), so a reference has to be named.

Python 3.13 is the newest Python upstream tested 6.3.1 on (its `tox.ini` lists 3.9 to 3.13), it stays installable until October 2029, and its Unicode version (15.1) is that of stringi's bundled ICU 74.1.

Decided in https://github.com/epabarker/r-ftfy/issues/11. Measurements: `research/regex-unicode-parity.md` on branch `research/regex-unicode-parity`.

## Considered options

- **Hand-port the patterns into readable R source.** Rejected: `BADNESS_RE` alone has 37 alternatives, and the research found that a translation mistake can compile and match wrongly without any error. A generated pattern can be checked against upstream exactly; a hand-ported one only by sampling.
- **Use ICU's `\s`, `\w` and `\d` and document the difference.** Rejected: it changes which text counts as mojibake, and the difference would then vary with each user's ICU version as well.
- **Ship Unicode normalisation data too.** Rejected: normalisation can differ only for text containing characters assigned after the older of the two Unicode versions, which Unicode's stability policy guarantees and 200,000 measured sequences confirmed. The data would be large for that.
- **Rewrite `ANSI_RE` so that it cannot overflow.** Rejected: it breaks "generated, not hand-written", and does not help `UTF8_DETECTOR_RE`.

## Consequences

- Two departures from reference behaviour, listed in the package documentation:
  - normalisation (all four forms) follows the user's ICU, so text with recently assigned characters can normalise differently;
  - Python's `re` has no backtracking limit, while here a regex that needs more than the 1e9-byte limit raises an error naming the function and the input length. Only input tens of millions of characters long gets near it.
- The package does not check the ICU version or warn about it.
- A bug fixed in a later Python's `\w` or `\d` is not picked up until the data is regenerated against a new reference, and changing the reference means regenerating every fixture.
- The two CESU-8 patterns inside the `utf-8-variants` decoder are not generated: they are written by hand so that end of input means the true end ([ADR 0004](0004-utf-8-variants-does-not-copy-upstreams-trailing-newline-behaviour.md)).
- `stack_limit = 0L` does not lift the limit in stringi, and values above about 1.07e9 overflow immediately; do not change the limit to either.
