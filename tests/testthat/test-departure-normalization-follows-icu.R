# Departure `normalization-follows-icu`
# (inst/departures/normalization-follows-icu.dcf, ADR 0005): normalisation
# is done by the ICU that stringi was built with, so text that holds a
# character newer than that ICU's Unicode can be normalised differently
# from the reference version, which has Unicode 15.1.
#
# These tests must pass with any ICU. What the package gives is asserted
# against stringi's own normalisation; the difference from the reference
# version is asserted only where the running ICU does not know the
# character.

# U+10EFD ARABIC SMALL LOW WORD SAKTA (combining class 220) and U+1E030
# MODIFIER LETTER CYRILLIC SMALL A (decomposes to U+0430), both assigned
# in Unicode 15.0.
sakta_text <- "a\U00010efd\u0301"
modifier_text <- "\U0001e030"

icu_knows <- function(character) {
  !stringi::stri_detect_charclass(character, "\\p{Cn}")
}

test_that("fix_and_explain() normalises as the user's ICU does, in every form", {
  x <- c(sakta_text, "q\u0301\U00010efd", modifier_text, "x\u0301\U0001e4ee \U0001e08f")
  forms <- list(
    NFC = stringi::stri_trans_nfc, NFD = stringi::stri_trans_nfd,
    NFKC = stringi::stri_trans_nfkc, NFKD = stringi::stri_trans_nfkd
  )

  for (form in names(forms)) {
    explained <- fix_and_explain(x, normalization = form)
    expected <- forms[[form]](x)
    expect_identical(explained$text, expected, info = form)
    expect_identical(
      as.character(explained$plan),
      ifelse(expected == x, "none", paste("normalize", form)),
      info = form
    )
    expect_identical(apply_plan(x, explained$plan), explained$text, info = form)
  }
  expect_identical(fix_and_explain(x, normalization = NULL)$text, x)
})

test_that("with an ICU that knows the characters R gives the reference version's result, and otherwise the text is left", {
  # Run on ftfy 6.3.1 with Python 3.13 (Unicode 15.1):
  # fix_and_explain('a\U00010EFD\u0301') gives ('\xe1\U00010efd', [('normalize', 'NFC')]),
  # fix_and_explain('\U0001E030', normalization='NFKC') gives ('\u0430', [('normalize', 'NFKC')]).
  nfc <- fix_and_explain(sakta_text)
  nfkc <- fix_and_explain(modifier_text, normalization = "NFKC")

  if (icu_knows("\U00010efd")) {
    expect_identical(nfc$text, "\u00e1\U00010efd")
    expect_identical(as.character(nfc$plan), "normalize NFC")
  } else {
    expect_identical(nfc$text, sakta_text)
    expect_identical(as.character(nfc$plan), "none")
  }
  if (icu_knows("\U0001e030")) {
    expect_identical(nfkc$text, "\u0430")
    expect_identical(as.character(nfkc$plan), "normalize NFKC")
  } else {
    expect_identical(nfkc$text, modifier_text)
    expect_identical(as.character(nfkc$plan), "none")
  }
})

test_that("text of characters both Unicode versions have is normalised as the reference version does", {
  # Run on ftfy 6.3.1 with Python 3.13.
  x <- c("e\u0301", "\u212b", "q\u0323\u0307", "q\u0307\u0323")
  explained <- fix_and_explain(x)

  expect_identical(explained$text, c("\u00e9", "\u00c5", "q\u0323\u0307", "q\u0323\u0307"))
  expect_identical(
    as.character(explained$plan),
    c("normalize NFC", "normalize NFC", "none", "normalize NFC")
  )
})

test_that("the registry entry matches this difference only where the ICU does not know the character", {
  matcher <- departure_matchers()[["normalization-follows-icu"]]
  difference <- function(...) {
    utils::modifyList(
      list(fun = "fix_and_explain", input = sakta_text,
           reference = "\u00e1\U00010efd", actual = sakta_text),
      list(...)
    )
  }

  expect_identical(matcher(difference()), !icu_knows("\U00010efd"))
  expect_identical(
    matcher(difference(reference = "normalize NFC", actual = "none")),
    !icu_knows("\U00010efd")
  )
  expect_identical(matcher(difference(fun = "fix_text")), !icu_knows("\U00010efd"))
  # Not this departure: text without such a character, another function,
  # or no text from R.
  expect_false(matcher(difference(input = "e\u0301", reference = "\u00e9", actual = "e\u0301")))
  expect_false(matcher(difference(input = "a\u0600\u0301")))
  expect_false(matcher(difference(fun = "fix_encoding")))
  expect_false(matcher(difference(actual = NA_character_)))
  expect_false(matcher(difference(actual = simpleError("failed"))))
})

test_that("the snapshot rows that show the departure are excused only by this entry", {
  snapshot <- read_fix_and_explain_snapshot()$default
  rows <- which(grepl("[\U00010efd-\U00010eff\U0001e030-\U0001e06d\U0001e08f\U0001e4ec-\U0001e4ef]",
                      snapshot$text, perl = TRUE))
  explained <- fix_and_explain(snapshot$text[rows])

  expect_gte(length(rows), 3L)
  for (i in seq_along(rows)) {
    difference <- list(
      fun = "fix_and_explain", input = snapshot$text[[rows[[i]]]],
      reference = snapshot$fixed[[rows[[i]]]], actual = explained$text[[i]]
    )
    if (identical(difference$reference, difference$actual)) {
      next
    }
    expect_identical(departure_matching(difference), "normalization-follows-icu")
  }
})
