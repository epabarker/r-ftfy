# Departure `decoded-nul-dropped` (inst/departures/decoded-nul-dropped.dcf,
# ADR 0007): C0 80 decoded with `utf-8-variants` gives nothing, where the
# reference version gives U+0000.
#
# Asserted here at the decoder level and through fix_encoding(),
# apply_plan(), fix_and_explain() and fix_text().

# The bytes of 'null\u00c0\u20acseparated' in sloppy-windows-1252.
nul_bytes <- function() "null\u00c0\u0080separated"

test_that("a decoded C0 80 is dropped", {
  expect_identical(ftfy:::codec_decode(nul_bytes(), "utf-8-variants"), "nullseparated")
  expect_identical(
    ftfy:::codec_decode(c("\u00c0\u0080", "\u00c0\u0080\u00c0\u0080a", "caf\u00c3\u00a9\u00c0\u0080"),
                        "utf-8-variants"),
    c("", "a", "caf\u00e9")
  )
})

test_that("the text that encodes to C0 80 decodes to nothing in its place", {
  bytes <- ftfy:::codec_try_encode("null\u00c0\u20acseparated", "sloppy-windows-1252")

  expect_identical(bytes, nul_bytes())
  expect_identical(ftfy:::codec_decode(bytes, "utf-8-variants"), "nullseparated")
})

test_that("the bytes on the two sides of a dropped C0 80 are not joined", {
  # E2 82 AC is the euro sign; with C0 80 inside it, it is undecodable, as
  # it is in the reference version.
  bytes <- c("\u00e2\u00c0\u0080\u0082\u00ac", "\u00e2\u0082\u00c0\u0080\u00ac")

  expect_identical(ftfy:::codec_decode(bytes, "utf-8-variants"), c(NA_character_, NA_character_))
})

test_that("strict utf-8 does not decode C0 80", {
  expect_identical(ftfy:::codec_decode(nul_bytes(), "utf-8"), NA_character_)
})

test_that("the registry entry matches this difference and no other", {
  matcher <- departure_matchers()[["decoded-nul-dropped"]]
  # The reference version's text, still escaped: see unescape_reference().
  reference <- unescape_reference("null\\u0000separated")
  actual <- ftfy:::codec_decode(nul_bytes(), "utf-8-variants")
  difference <- function(...) {
    utils::modifyList(
      list(fun = decoder_fun, input = nul_bytes(), reference = reference, actual = actual),
      list(...)
    )
  }

  expect_true(matcher(difference()))
  expect_true(matcher(difference(fun = "fix_encoding", input = "null\u00c0\u20acseparated")))
  # Not this departure: another text, a failure, or a reference without U+0000.
  expect_false(matcher(difference(actual = "null separated")))
  expect_false(matcher(difference(actual = NA_character_)))
  expect_false(matcher(difference(actual = simpleError("invalid UTF-8"))))
  expect_false(matcher(difference(reference = "null separated")))
  expect_false(matcher(difference(reference = "nullseparated", actual = "nullseparate")))
})

test_that("fix_encoding() puts nothing in place of a decoded C0 80", {
  # The reference version gives 'null\\x00separated', 'caf\\xe9 \\x00
  # cr\\xe8me \\x00' and 'sch\\xf6n \\x00' (run on ftfy 6.3.1 with Python 3.13).
  expect_identical(
    fix_encoding(c("null\u00c0\u20acseparated",
                   "caf\u00c3\u00a9 \u00c0\u20ac cr\u00c3\u00a8me \u00c0\u20ac",
                   "sch\u00c3\u00b6n \u00c0\u0080")),
    c("nullseparated", "caf\u00e9  cr\u00e8me ", "sch\u00f6n ")
  )
})

test_that("the two characters alone are not bad enough to be repaired, as in the reference version", {
  expect_identical(fix_encoding("\u00c0\u20ac"), "\u00c0\u20ac")
})

test_that("the registry entry matches the difference in fix_encoding()", {
  matcher <- departure_matchers()[["decoded-nul-dropped"]]
  text <- c("null\u00c0\u20acseparated", "sch\u00c3\u00b6n \u00c0\u0080")
  reference <- unescape_reference(c("null\\u0000separated", "sch\\u00F6n \\u0000"))
  actual <- fix_encoding(text)

  for (i in seq_along(text)) {
    expect_true(matcher(list(fun = "fix_encoding", input = text[[i]],
                             reference = reference[[i]], actual = actual[[i]])))
    # Returning the input unchanged is not this departure.
    expect_false(matcher(list(fun = "fix_encoding", input = text[[i]],
                              reference = reference[[i]], actual = text[[i]])))
  }
})

# apply_plan() (ticket #39). The reference version's plan for this text is
# `encode sloppy-windows-1252 > decode utf-8-variants`, and its apply_plan()
# replays it to 'null\\x00separated' (run on ftfy 6.3.1 with Python 3.13).
test_that("apply_plan() puts nothing in place of a decoded C0 80", {
  text <- "null\u00c0\u20acseparated"
  plan <- "encode sloppy-windows-1252 > decode utf-8-variants"

  expect_identical(apply_plan(text, plan), "nullseparated")
  expect_identical(apply_plan(text, fix_encoding_and_explain(text)$plan), "nullseparated")
  expect_true(departure_matchers()[["decoded-nul-dropped"]](list(
    fun = "apply_plan", input = text,
    reference = unescape_reference("null\\u0000separated"), actual = apply_plan(text, plan)
  )))
})

# fix_and_explain() (ticket #40). The reference version gives
# ('nullseparated', [('encode', 'sloppy-windows-1252'), ('decode',
# 'utf-8-variants'), ('apply', 'remove_control_chars')]): its fixer
# remove_control_chars removes the decoded U+0000 and is recorded for it.
# With remove_control_chars=False it gives 'null\\x00separated' and the
# first two steps (run on ftfy 6.3.1 with Python 3.13).
test_that("fix_and_explain() records no step for removing a U+0000 that was never there", {
  text <- "null\u00c0\u20acseparated"
  explained <- fix_and_explain(text)

  expect_identical(explained$text, "nullseparated")
  expect_identical(
    as.character(explained$plan), "encode sloppy-windows-1252 > decode utf-8-variants"
  )
  expect_identical(apply_plan(text, explained$plan), explained$text)
  expect_identical(fix_and_explain(text, remove_control_chars = FALSE), explained)
})

test_that("the registry entry matches the plan difference in fix_and_explain() and no other", {
  matcher <- departure_matchers()[["decoded-nul-dropped"]]
  text <- "null\u00c0\u20acseparated"
  difference <- function(...) {
    utils::modifyList(
      list(
        fun = "fix_and_explain", input = text,
        reference = "encode sloppy-windows-1252 > decode utf-8-variants > apply remove_control_chars",
        actual = as.character(fix_and_explain(text)$plan)
      ),
      list(...)
    )
  }

  expect_true(matcher(difference()))
  # The text with remove_control_chars off, as for fix_encoding().
  expect_true(matcher(difference(
    reference = unescape_reference("null\\u0000separated"),
    actual = fix_and_explain(text, remove_control_chars = FALSE)$text
  )))
  # Not this departure: another function, a plan that differs otherwise,
  # a step missing that is not the removal of control characters or that
  # comes before the decoding, or an input that does not encode to C0 80.
  expect_false(matcher(difference(fun = "fix_encoding_and_explain")))
  expect_false(matcher(difference(actual = "none")))
  expect_false(matcher(difference(actual = "encode latin-1 > decode utf-8-variants")))
  expect_false(matcher(difference(
    reference = "encode sloppy-windows-1252 > decode utf-8-variants > apply uncurl_quotes"
  )))
  expect_false(matcher(difference(
    reference = "apply remove_control_chars > encode sloppy-windows-1252 > decode utf-8-variants"
  )))
  expect_false(matcher(difference(
    reference = "encode sloppy-windows-1252 > decode utf-8 > apply remove_control_chars",
    actual = "encode sloppy-windows-1252 > decode utf-8"
  )))
  expect_false(matcher(difference(input = "caf\u00c3\u00a9\u0007")))
})

# fix_text() (ticket #41). With default options the reference version
# removes the U+0000 it decoded, as a control character, so the texts are
# equal; with remove_control_chars off it keeps it (run on ftfy 6.3.1 with
# Python 3.13: 'null\x00separated' and 'caf\xe9 \x00 end\nnext \xe9\n').
test_that("fix_text() gives the reference version's text without the U+0000", {
  text <- c("null\u00c0\u20acseparated", "caf\u00c3\u00a9 \u00c0\u0080 end\nnext \u00c3\u00a9\n")
  fixed <- c("nullseparated", "caf\u00e9  end\nnext \u00e9\n")

  expect_identical(fix_text(text), fixed)
  kept <- fix_text(text, remove_control_chars = FALSE)
  expect_identical(kept, fixed)
  expect_reference(
    "fix_text", text, kept,
    unescape_reference(c("null\\u0000separated", "caf\\u00E9 \\u0000 end\\u000Anext \\u00E9\\u000A"))
  )
  expect_identical(
    departure_matching(list(fun = "fix_text", input = text[[1]],
                            reference = "null\\u0000separated", actual = kept[[1]])),
    "decoded-nul-dropped"
  )
})
