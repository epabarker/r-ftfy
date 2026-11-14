# The 66 noncharacters of Unicode (U+FDD0 to U+FDEF and the last two code
# points of each of the 17 planes) are valid in UTF-8, and the reference
# version treats them as any other character: they stay where they are and
# everything around them is repaired. Base R's `chartr()` refuses a string
# holding U+FFFE or U+FFFF, which the larger corpus found (ticket #44).
#
# The expected values are what ftfy 6.3.1 on Python 3.13 returns, which is
# the same for every noncharacter.

noncharacters <- as.integer(c(
  0xFDD0:0xFDEF,
  as.vector(outer(c(0xFFFE, 0xFFFF), 0x10000 * (0:16), "+"))
))
noncharacter <- intToUtf8(noncharacters, multiple = TRUE)

test_that("there are 66 noncharacters and R holds each as valid UTF-8", {
  expect_length(noncharacter, 66L)
  expect_true(all(stringi::stri_enc_isutf8(noncharacter)))
  expect_identical(vapply(noncharacter, utf8ToInt, 0L, USE.NAMES = FALSE), noncharacters)
})

test_that("the fixers that translate characters keep a noncharacter", {
  expect_identical(
    fix_character_width(paste0("\uff21", noncharacter, "\uff42")),
    paste0("A", noncharacter, "b")
  )
  expect_identical(
    fix_latin_ligatures(paste0("\ufb01", noncharacter, "\u0132")),
    paste0("fi", noncharacter, "IJ")
  )
  expect_identical(
    fix_c1_controls(paste0("\u0085", noncharacter, "\u0080")),
    paste0("\u2026", noncharacter, "\u20ac")
  )
  expect_identical(
    decode_inconsistent_utf8(paste0(noncharacter, " sch\u00c3\u00b6n \u00e9")),
    paste0(noncharacter, " sch\u00f6n \u00e9")
  )
})

test_that("the other text fixers keep a noncharacter", {
  x <- paste0("a", noncharacter, "b")
  expect_identical(remove_control_chars(x), x)
  expect_identical(
    uncurl_quotes(paste0("\u201c", noncharacter, "\u2019")),
    paste0("\"", noncharacter, "'")
  )
  expect_identical(fix_line_breaks(paste0(noncharacter, "\r\n")), paste0(noncharacter, "\n"))
  expect_identical(unescape_html(paste0(noncharacter, "&amp;")), paste0(noncharacter, "&"))
  expect_identical(remove_terminal_escapes(paste0(noncharacter, "\033[0m")), noncharacter)
})

test_that("the encoding repair works beside a noncharacter", {
  x <- paste0("\u0085", noncharacter, " sch\u00c3\u00b6n")
  fixed <- paste0("\u2026", noncharacter, " sch\u00f6n")
  expect_identical(fix_encoding(x), fixed)
  expect_identical(fix_encoding_and_explain(x)$text, fixed)
  expect_identical(
    fix_encoding_and_explain(paste0(noncharacter, "\u00c3\u00b6n"))$text,
    paste0(noncharacter, "\u00f6n")
  )
  expect_identical(is_bad(paste0(noncharacter, "\u00c3\u00b6")), rep(TRUE, 66L))
  expect_identical(badness(paste0(noncharacter, "\u00c3\u00b6")), rep(1L, 66L))
})

test_that("a noncharacter read as Latin-1 is decoded again", {
  # Its UTF-8 bytes read as Latin-1: the reference version gives the plan
  # `encode latin-1 > decode utf-8` and the noncharacter back.
  as_latin1 <- vapply(noncharacters, function(code_point) {
    intToUtf8(as.integer(charToRaw(intToUtf8(code_point))))
  }, "")
  explained <- fix_encoding_and_explain(paste0("sch\u00c3\u00b6n ", as_latin1))
  expect_identical(explained$text, paste0("sch\u00f6n ", noncharacter))
  expect_identical(
    unique(as.character(explained$plan)),
    "encode latin-1 > decode utf-8"
  )
  expect_identical(
    apply_plan(paste0("sch\u00c3\u00b6n ", as_latin1), "encode latin-1 > decode utf-8"),
    paste0("sch\u00f6n ", noncharacter)
  )
})

test_that("fix_text() and fix_and_explain() repair a text holding a noncharacter", {
  expect_identical(
    fix_text(paste0("\uff21", noncharacter, " sch\u00c3\u00b6n\n\ufb01", noncharacter)),
    paste0("A", noncharacter, " sch\u00f6n\nfi", noncharacter)
  )
  explained <- fix_and_explain(paste0("\uff21", noncharacter, " sch\u00c3\u00b6n"))
  expect_identical(explained$text, paste0("A", noncharacter, " sch\u00f6n"))
  expect_identical(
    unique(as.character(explained$plan)),
    "apply decode_inconsistent_utf8 > apply fix_character_width"
  )
})

test_that("a vector with and without noncharacters is repaired element by element", {
  x <- c("\uff21\uffff", "\uff21", "A", NA, "\uff21\ufffe\uff42", "plain \uffff")
  fixed <- c("A\uffff", "A", "A", NA, "A\ufffeb", "plain \uffff")
  expect_identical(fix_character_width(x), fixed)
  expect_identical(fix_text(x), fixed)
})
