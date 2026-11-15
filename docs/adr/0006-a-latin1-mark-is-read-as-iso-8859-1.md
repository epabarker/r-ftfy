# A latin1 mark is read as ISO 8859-1

A string that R marks `latin1` is converted to text at entry as true ISO 8859-1, through the package's own `latin-1` codec table. Bytes 80-9F become the C1 controls U+0080-U+009F. This disagrees with base R: `?Encoding` says the mark is read "if possible" as Windows code page 1252, and `enc2utf8()` does so (byte `80` becomes `€`, and a hole such as `81` becomes the four ASCII characters `<81>`). stringi and `iconv()` read the mark as ISO 8859-1.

We chose ISO 8859-1 because the package's whole method depends on the difference between Latin-1 and Windows-1252, so entry must not quietly pick between them. Read as ISO 8859-1, C1 bytes reach the fixers unchanged. `fix_c1_controls`, which is on by default, then turns them into Windows-1252 characters as a recorded step in the plan. Reading the mark as CP-1252 would do that repair before the plan starts, leave no record of it, and turn holes into literal text that cannot be undone.

Decided in https://github.com/epabarker/r-ftfy/issues/12.

## Consequences

- `fix_text()` with default options gives the same text for a `latin1`-marked string whichever reading is used, except at the five Windows-1252 holes. Its plan records the C1 repair as a step. Amended in https://github.com/epabarker/r-ftfy/issues/40: which step is the reference version's choice, not `apply fix_c1_controls` as first written. With default options the encoding repair usually takes the C1 controls first and records `encode latin-1 > decode windows-1252`; when a Windows-1252 hole is among the bytes it records `transcode fix_c1_controls`. `apply fix_c1_controls` appears with `fix_encoding = FALSE`.
- With `fix_c1_controls = FALSE`, or through `fix_encoding()`, C1 controls from a `latin1`-marked input stay in the output.
- Entry never calls `enc2utf8()` on a `latin1`-marked string. It calls it only on unmarked native strings. Amended in https://github.com/epabarker/r-ftfy/issues/43: only on unmarked native strings in a session whose native encoding is not UTF-8. In a UTF-8 session the bytes already are the text, so entry only marks them UTF-8. On R 4.2.3, `enc2utf8()` turned an invalid byte in such a string into text such as `<e9>`, so the invalid-UTF-8 error never fired.
- Two consequences of reading unmarked native strings through `enc2utf8()` are measured and pinned as tests, but not yet decided. In a Latin-1 session, unmarked bytes 80-9F are read as Windows-1252, unlike a `latin1` mark. The five holes differ by platform: `<81>` as text on Linux and macOS, U+0081 on Windows with code page 1252. In the C locale, an unmarked non-ASCII byte becomes text such as `<e9>` with no error.
