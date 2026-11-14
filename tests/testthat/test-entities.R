# Derived from python-ftfy v6.3.1, tests/test_entities.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# The mirror of upstream's tests/test_entities.py. A ticket that ports
# another of its assertions adds it to this file, in upstream's order.
#
# Here are the assertions of test_entities (tests/test_entities.py:7) that
# call `unescape_html()` directly: lines 27 to 33, and its other assertions,
# each through the function it calls:
#
# - tests/test_entities.py:9, :12, :15: `fix_text()`, the last two with the
#   option `unescape_html`.
# - tests/test_entities.py:10, :13, :16, :18 to :26, :35:
#   `fix_text_segment()`, which upstream defines as the text that
#   `fix_and_explain()` returns (ftfy/__init__.py:609) and which is internal
#   here. They are ported below through `fix_and_explain()`; lines 13, 16,
#   18, 19, 23 and 24 pass an option. (`fix_text()` will not do: lines 9
#   and 10 expect different results from the two functions for one input.)
# - tests/test_entities.py:40, test_old_parameter_name: ported in
#   test-config.R as an unknown-option error.

# `fix_text_segment()` of upstream: the text of `fix_and_explain()`.
fix_text_segment <- function(x, ...) fix_and_explain(x, ...)$text

# tests/test_entities.py:7, test_entities: its lines 9, 12 and 15
test_that("test_entities: fix_text()", {
  example <- "&amp;\n<html>\n&amp;"
  expect_identical(fix_text(example), "&\n<html>\n&amp;")

  expect_identical(fix_text(example, unescape_html = TRUE), "&\n<html>\n&")

  expect_identical(fix_text(example, unescape_html = FALSE), "&amp;\n<html>\n&amp;")
})

# tests/test_entities.py:7, test_entities: its lines 10, 13, 16 and 18 to 26
test_that("test_entities: fix_text_segment()", {
  example <- "&amp;\n<html>\n&amp;"
  expect_identical(fix_text_segment(example), "&amp;\n<html>\n&amp;")

  expect_identical(fix_text_segment(example, unescape_html = TRUE), "&\n<html>\n&")

  expect_identical(fix_text_segment(example, unescape_html = FALSE), "&amp;\n<html>\n&amp;")

  expect_identical(fix_text_segment("&lt;&gt;", unescape_html = FALSE), "&lt;&gt;")
  expect_identical(fix_text_segment("&lt;&gt;", unescape_html = TRUE), "<>")
  expect_identical(fix_text_segment("&lt;&gt;"), "<>")
  expect_identical(fix_text_segment("jednocze&sacute;nie"), "jednocze\u015bnie")
  expect_identical(fix_text_segment("JEDNOCZE&Sacute;NIE"), "JEDNOCZE\u015aNIE")
  expect_identical(fix_text_segment("ellipsis&#133;", normalization = "NFKC"), "ellipsis...")
  expect_identical(fix_text_segment("ellipsis&#x85;", normalization = "NFKC"), "ellipsis...")
  expect_identical(fix_text_segment("broken&#x81;"), "broken\u0081")
  expect_identical(fix_text_segment("&amp;amp;amp;"), "&")
})

# tests/test_entities.py:7, test_entities: its lines 27 to 33
test_that("test_entities: unescape_html()", {
  expect_identical(unescape_html("euro &#x80;"), "euro \u20ac")
  expect_identical(unescape_html("EURO &EURO;"), "EURO \u20ac")
  expect_identical(unescape_html("not an entity &#20x6;"), "not an entity &#20x6;")
  expect_identical(unescape_html("JEDNOCZE&SACUTE;NIE"), "JEDNOCZE\u015aNIE")
  expect_identical(unescape_html("V&SCARON;ICHNI"), "V\u0160ICHNI")
  expect_identical(unescape_html("&#xffff;"), "")
  expect_identical(unescape_html("&#xffffffff;"), "\ufffd")
})

# tests/test_entities.py:7, test_entities: its line 35
test_that("test_entities: fix_text_segment() leaves informal text alone", {
  expect_identical(
    fix_text_segment("this is just informal english &not html"),
    "this is just informal english &not html"
  )
})
