# Derived from python-ftfy v6.3.1, tests/test_characters.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# The mirror of upstream's tests/test_characters.py. A ticket that ports
# another of its tests adds it to this file, in upstream's order.
#
# Not ported, by the resolution of issue #14:
#
# - tests/test_characters.py:10, test_possible_encoding: `possible_encoding`
#   is internal here. (It also runs over U+0000, which no R string holds.)
# - tests/test_characters.py:44, test_surrogates: `fix_surrogates` is not
#   ported, and its inputs are lone surrogates, which no R string holds.
#
# Ported by the tickets that deliver the functions they call:
#
# - tests/test_characters.py:16, test_byte_order_mark: `fix_encoding()`.
# - tests/test_characters.py:36, test_ohio_flag: `fix_text()`.
# - tests/test_characters.py:49, test_color_escapes: `fix_and_explain()`.

# tests/test_characters.py:20
test_that("test_control_chars", {
  text <- paste0(
    "\ufeffSometimes, \ufffcbad ideas \u007f\ufffalike these characters\ufffb ",
    "\u206aget standardized.\r\n"
  )
  fixed <- "Sometimes, bad ideas like these characters get standardized.\r\n"
  expect_identical(remove_control_chars(text), fixed)
})

# tests/test_characters.py:29
test_that("test_welsh_flag", {
  # ftfy used to remove "tag characters", but they have been repurposed in
  # the "Flag of England", "Flag of Scotland", and "Flag of Wales" emoji
  # sequences.
  text <- paste0(
    "This flag has a dragon on it ",
    "\U0001f3f4\U000e0067\U000e0062\U000e0077\U000e006c\U000e0073\U000e007f"
  )
  expect_identical(remove_control_chars(text), text)
})
