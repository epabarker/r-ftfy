Every release that changes what a function returns with default options says so here: every changed default output is listed, with an example of an input, what it gave before and what it gives now. Such a change is made only in a minor release. The output of `fix_text()` with default options never changes in a patch release.

A move to a new reference version and a new departure are both changes of this kind. The departures in force are listed, with examples, on the help page `?"ftfy-differences"`.

# ftfy 0.1.0

The first release, which has not been made yet. Its reference version is Python ftfy 6.3.1 on Python 3.13: with the exceptions below, every function returns what that version returns.

## Default output that differs from the reference version

There is no earlier release to compare with, so this list compares with the reference version. Strings are written as R source; an output of the reference version is written as Python prints it.

* A line that ends just after a byte C0, or after the first five bytes of a six-byte surrogate pair, is not repaired by reading its newline as the missing byte. `fix_text("one \u00c3\u00a9 \u00c0\ntwo \u00c3\u00a9")` gives `"one \u00e9 \u00c0\ntwo \u00e9"`, on two lines; the reference version gives `'one \xe9 two \xe9'`, on one.
* A decoded U+0000 is dropped, because an R string cannot hold it. `fix_encoding("null\u00c0\u20acseparated")` gives `"nullseparated"`; the reference version gives `'null\x00separated'`. `fix_text()` gives `"nullseparated"` in both.
* Normalisation uses the Unicode data of the ICU library that stringi was built with. With ICU 71.1, which has Unicode 14.0, `fix_text("a\U00010EFD\u0301")` returns its input; the reference version, which has Unicode 15.1, gives `'\xe1\U00010efd'`. With an ICU that has Unicode 15.0 or later the two agree.
* A string that is not valid UTF-8 is an error in every function. The nearest input in Python, a string holding a lone surrogate, is accepted there: `fix_text('\ud800')` gives `'\ufffd'`.
* A regular expression that needs more than 1e9 bytes of backtracking stack is an error of class `ftfy_regex_overflow`. It takes one string of tens of millions of characters to reach the limit; Python has no limit.

## Other differences from the reference version

* `fix_text()` honours the options `restore_byte_a0`, `replace_lossy_sequences`, `decode_inconsistent_utf8` and `fix_c1_controls` when they are given by name. The reference version ignores them there: `fix_text("voil\u00c3  le travail", restore_byte_a0 = FALSE)` keeps both spaces, `"voil\u00e0  le travail"`, where the reference version's `fix_text('voil\xc3  le travail', restore_byte_a0=False)` gives `'voil\xe0 le travail'`.
* `apply_plan()` replays `normalize` steps, which the reference version's `apply_plan()` refuses with `ValueError: Unknown plan step: normalize`.
