# Derived from python-ftfy v6.3.1, tests/test_entities.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# The mirror of upstream's tests/test_entities.py. A ticket that ports
# another of its assertions adds it to this file, in upstream's order.
#
# Here are the assertions of test_entities (tests/test_entities.py:7) that
# call `unescape_html()` directly: lines 27 to 33. Its other assertions go
# through functions that later tickets deliver, and are ported there:
#
# - tests/test_entities.py:9, :12, :15: `fix_text()`, the last two with the
#   option `unescape_html`.
# - tests/test_entities.py:10, :13, :16, :18 to :26, :34: `fix_text_segment()`,
#   which is internal here; they are ported through `fix_text()`, with
#   options where upstream passes them.
# - tests/test_entities.py:40, test_old_parameter_name: ported in
#   test-config.R as an unknown-option error.

# tests/test_entities.py:27 to :33
test_that("test_entities: unescape_html()", {
  expect_identical(unescape_html("euro &#x80;"), "euro \u20ac")
  expect_identical(unescape_html("EURO &EURO;"), "EURO \u20ac")
  expect_identical(unescape_html("not an entity &#20x6;"), "not an entity &#20x6;")
  expect_identical(unescape_html("JEDNOCZE&SACUTE;NIE"), "JEDNOCZE\u015aNIE")
  expect_identical(unescape_html("V&SCARON;ICHNI"), "V\u0160ICHNI")
  expect_identical(unescape_html("&#xffff;"), "")
  expect_identical(unescape_html("&#xffffffff;"), "\ufffd")
})
