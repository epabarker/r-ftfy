# The utf-8-variants decoder does not copy upstream's trailing-newline behaviour

Python ftfy 6.3.1's `utf-8-variants` decoder misreads two byte sequences when they are followed by a newline that is the last byte of the input. The R decoder treats both as undecodable, as upstream does when anything other than a final newline follows. This is a deliberate departure and the only one so far that changes what `fix_text()` returns with default options; do not "fix" it back to match Python.

| Bytes at the end of the input | Python ftfy 6.3.1 | This package |
|---|---|---|
| `C0 0A` | U+0000, newline lost | decoding fails |
| `ED A0 BD ED B8 0A` (five bytes of a six-byte surrogate pair, then newline) | U+1F60A, newline lost | decoding fails |

The cause upstream is a regular expression using `$`, which in Python also matches just before a final newline, so the newline byte is consumed as if it were the missing last byte of the sequence. It is reachable from ordinary text because `fix_text` works line by line and most lines end in a newline: `fix_text('schÃ¶n À\n')` returns `'schön '` in Python, losing the `À` and the newline.

We depart because copying it means copying data loss that nothing pins: none of upstream's 161 JSON test cases reaches either sequence, so the parity bar is unaffected. Observed on installed ftfy 6.3.1, Python 3.9.6, macOS arm64.

Decided in https://github.com/epabarker/r-ftfy/issues/10.

## Consequences

- For inputs that reach these sequences, `fix_text()`, `fix_encoding()` and their plans differ from Python's. This is listed as a known difference in the package documentation.
- The decoder test corpus includes both sequences, marked as departures, with Python's answer recorded beside ours.
- `C0 80` is now the only way the decoder can meet U+0000, which an R string cannot hold. What the package returns in that case is a separate decision.
