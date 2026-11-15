# Derived from python-ftfy v6.3.1, ftfy/bad_codecs/ and tests/test_encodings.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# Upstream's doctests and tests of its own codecs, at the decoder level.
# Bytes are held as text: byte b is the character U+00b.

# Upstream doctest, ftfy/bad_codecs/utf8_variants.py:14. The reference
# version gives U+0000 for C0 80; an R string cannot hold it, so nothing
# stands in its place (departure `decoded-nul-dropped`).
test_that("utf-8-variants decodes Java's null", {
  bytes <- "here comes a null! \u00c0\u0080"

  expect_identical(ftfy:::codec_decode(bytes, "utf-8-variants"), "here comes a null! ")
})

# Upstream doctest, ftfy/bad_codecs/__init__.py:29.
test_that("utf-8-variants decodes a CESU-8 surrogate pair", {
  bytes <- "í ½í¸\u008d"

  expect_identical(ftfy:::codec_decode(bytes, "utf-8-variants"), "\U0001f60d")
})

# Upstream doctest, ftfy/bad_codecs/sloppy.py:58.
test_that("sloppy-windows-1252 merges Windows-1252 with Latin-1", {
  some_bytes <- "\u0080\u0081\u0082"

  expect_identical(ftfy:::codec_decode(some_bytes, "latin-1"), "\u0080\u0081\u0082")
  # Upstream decodes with errors="replace" here and shows U+FFFD for byte
  # 81. This package has no error modes: strict windows-1252 fails on its
  # holes, and decodes the two bytes around this one as upstream shows.
  expect_identical(ftfy:::codec_decode(some_bytes, "windows-1252"), NA_character_)
  expect_identical(ftfy:::codec_decode("\u0080\u0082", "windows-1252"), "\u20ac\u201a")
  expect_identical(ftfy:::codec_decode(some_bytes, "sloppy-windows-1252"), "\u20ac\u0081\u201a")
})

# Upstream test_cesu8, tests/test_encodings.py:4. Its first half checks
# that "cesu8" and "cesu-8" name the same codec; here neither is a name
# (ADR 0003). U+0000 is dropped, as above.
test_that("utf-8-variants decodes CESU-8", {
  test_bytes <- paste0(
    "\u00ed\u00a6\u009d\u00ed\u00bd\u00b7",
    " is an unassigned character, and \u00c0\u0080 is null"
  )
  test_text <- "\U00077777 is an unassigned character, and  is null"

  expect_identical(ftfy:::codec_decode(test_bytes, "utf-8-variants"), test_text)
  expect_error(ftfy:::codec_decode(test_bytes, "cesu8"), "Unknown codec")
  expect_error(ftfy:::codec_decode(test_bytes, "cesu-8"), "Unknown codec")
})

# Upstream test_russian_crash, tests/test_encodings.py:14: Windows-1251
# bytes do not crash `utf-8-variants`. Upstream decodes with the error
# mode "replace", which has no counterpart here: the package decodes
# strictly only, so the check is that decoding raises no error and
# reports the failure as `NA`. The second half of the upstream test calls
# guess_bytes(), which is not ported.
test_that("Windows-1251 bytes do not crash utf-8-variants", {
  thebytes <- paste0(
    "\u00e8\u00ed\u00e2\u00e5\u00ed\u00f2\u00e0\u00f0",
    "\u00e8\u00e7\u00e0\u00f6\u00e8\u00ff "
  )

  # An error here fails the test.
  decoded <- ftfy:::codec_decode(thebytes, "utf-8-variants")

  expect_identical(decoded, NA_character_)
})
