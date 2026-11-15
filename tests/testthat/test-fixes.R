# Derived from python-ftfy v6.3.1, ftfy/fixes.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# The doctests of the fixers in upstream's ftfy/fixes.py. A ticket that
# exports another fixer of that file adds its doctest here, in upstream's
# order.
#
# Not ported, by the resolution of issue #14: the doctests of
# `fix_surrogates` (ftfy/fixes.py:279; its inputs are lone surrogates,
# which no R string holds), `remove_bom` (ftfy/fixes.py:335) and
# `decode_escapes` (ftfy/fixes.py:369), none of which is ported.
# `remove_control_chars` (ftfy/fixes.py:297) has no doctest.

# ftfy/fixes.py:118 to :136
test_that("unescape_html doctest", {
  expect_identical(unescape_html("&lt;tag&gt;"), "<tag>")
  expect_identical(
    unescape_html("&Jscr;ohn &HilbertSpace;ancock"),
    "\U0001d4a5ohn \u210bancock"
  )
  expect_identical(unescape_html("&checkmark;"), "\u2713")
  expect_identical(unescape_html("P&eacute;rez"), "P\u00e9rez")
  expect_identical(unescape_html("P&EACUTE;REZ"), "P\u00c9REZ")
  expect_identical(unescape_html("BUNDESSTRA&SZLIG;E"), "BUNDESSTRASSE")
  expect_identical(
    unescape_html("&ntilde; &Ntilde; &NTILDE; &nTILDE;"),
    "\u00f1 \u00d1 \u00d1 &nTILDE;"
  )
})

# ftfy/fixes.py:150
test_that("remove_terminal_escapes doctest", {
  expect_identical(
    remove_terminal_escapes("\033[36;44mI'm blue, da ba dee da ba doo...\033[0m"),
    "I'm blue, da ba dee da ba doo..."
  )
})

# ftfy/fixes.py:162
test_that("uncurl_quotes doctest", {
  expect_identical(
    uncurl_quotes("\u201chere\u2019s a test\u201d"),
    "\"here's a test\""
  )
})

# ftfy/fixes.py:180
test_that("fix_latin_ligatures doctest", {
  expect_identical(fix_latin_ligatures("\ufb02u\ufb03e\ufb06"), "fluffiest")
})

# ftfy/fixes.py:198 to :200
test_that("fix_character_width doctest", {
  expect_identical(
    fix_character_width(
      "\uff2c\uff2f\uff35\uff24\u3000\uff2e\uff2f\uff29\uff33\uff25\uff33"
    ),
    "LOUD NOISES"
  )
  # This means "U-turn".
  expect_identical(
    fix_character_width("\uff35\uff80\uff70\uff9d"),
    "U\u30bf\u30fc\u30f3"
  )
})

# ftfy/fixes.py:225 to :246
test_that("fix_line_breaks doctest", {
  expect_identical(
    fix_line_breaks(paste0(
      "This string is made of two things:\u2029",
      "1. Unicode\u2028",
      "2. Spite"
    )),
    "This string is made of two things:\n1. Unicode\n2. Spite"
  )
  expect_identical(
    fix_line_breaks("Content-type: text/plain\r\n\r\nHi."),
    "Content-type: text/plain\n\nHi."
  )
  expect_identical(
    fix_line_breaks("This is how Microsoft \r trolls Mac users"),
    "This is how Microsoft \n trolls Mac users"
  )
  expect_identical(
    fix_line_breaks("What is this \u0085 I don't even"),
    "What is this \n I don't even"
  )
})
