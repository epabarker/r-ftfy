# Departure `utf8-variants-trailing-newline`
# (inst/departures/utf8-variants-trailing-newline.dcf, ADR 0004): C0, or
# five bytes of a six-byte surrogate pair, followed by a newline that ends
# the input is undecodable, where the reference version reads the newline
# as the missing byte.
#
# Asserted here at the decoder level. Ticket #36 adds the assertions
# through fix_encoding() beside these, and ticket #41 through fix_text().

# C0 0A and ED A0 BD ED B8 0A, alone and after text.
cut_short_bytes <- function() {
  c(
    "\u00c0\n", "abc\u00c0\n", "sch\u00c3\u00b6n \u00c0\n",
    "\u00ed\u00a0\u00bd\u00ed\u00b8\n", "caf\u00c3\u00a9 \u00ed\u00a0\u00bd\u00ed\u00b8\n"
  )
}

test_that("C0 0A and ED A0 BD ED B8 0A at the end of the input are undecodable", {
  bytes <- cut_short_bytes()

  expect_identical(ftfy:::codec_decode(bytes, "utf-8-variants"), rep(NA_character_, length(bytes)))
  expect_identical(ftfy:::codec_decode(bytes, "utf-8"), rep(NA_character_, length(bytes)))
})

test_that("they are undecodable wherever the input ends, as in the reference version", {
  bytes <- cut_short_bytes()

  cut <- sub("\n", "", bytes, fixed = TRUE)

  # Something after the newline, and no newline at all.
  for (changed in list(paste0(bytes, "\n"), paste0(bytes, "x"), cut, paste0(cut, "x"))) {
    expect_identical(
      ftfy:::codec_decode(changed, "utf-8-variants"),
      rep(NA_character_, length(bytes))
    )
  }
})

test_that("the complete sequences decode with a newline after them", {
  expect_identical(
    ftfy:::codec_decode(c("\u00ed\u00a0\u00bd\u00ed\u00b8\u008a\n", "abc\u00c0\u0080\n"), "utf-8-variants"),
    c("\U0001f60a\n", "abc\n")
  )
})

test_that("the text that reaches these bytes encodes to them", {
  expect_identical(
    ftfy:::codec_try_encode("sch\u00c3\u00b6n \u00c0\n", "latin-1"),
    cut_short_bytes()[[3]]
  )
})

test_that("the registry entry matches this difference and no other", {
  matcher <- departure_matchers()[["utf8-variants-trailing-newline"]]
  bytes <- cut_short_bytes()
  # What the reference version decodes them to; U+0000 stays escaped.
  reference <- unescape_reference(
    c("\\u0000", "abc\\u0000", "sch\\u00F6n \\u0000", "\\U0001F60A", "caf\\u00E9 \\U0001F60A")
  )
  actual <- ftfy:::codec_decode(bytes, "utf-8-variants")

  for (i in seq_along(bytes)) {
    expect_true(matcher(list(fun = decoder_fun, input = bytes[[i]],
                             reference = reference[[i]], actual = actual[[i]])))
  }
  # Not this departure at the decoder level: R decoded something, the
  # reference version failed too, or the bytes do not end this way.
  expect_false(matcher(list(fun = decoder_fun, input = bytes[[1]],
                            reference = reference[[1]], actual = "")))
  expect_false(matcher(list(fun = decoder_fun, input = bytes[[1]],
                            reference = NA_character_, actual = NA_character_)))
  expect_false(matcher(list(fun = decoder_fun, input = "abc\u00c0\nx",
                            reference = "abc", actual = NA_character_)))
  expect_false(matcher(list(fun = decoder_fun, input = "\u00ed\u00a0\u00bd\u00ed\u00a0\n",
                            reference = "x", actual = NA_character_)))
  expect_false(matcher(list(fun = decoder_fun, input = "\u00c3\n",
                            reference = "x", actual = NA_character_)))
})

test_that("the registry entry excuses no difference in an exported function yet", {
  # No exported function reaches these bytes until ticket #36, so a text
  # with such a line is no excuse for a difference. Ticket #36 replaces
  # this test with the assertions through fix_encoding().
  matcher <- departure_matchers()[["utf8-variants-trailing-newline"]]
  text <- c("sch\u00c3\u00b6n \u00c0\n", "\u00ed\u00a0\u00bd\u00ed\u00b8\n",
            "one \u00c0\ntwo", "\u0421\u0440\u0410\n")
  reference <- unescape_reference(
    c("sch\\u00F6n \\u0000", "\\U0001F60A", "one \\u0000two", "x")
  )

  for (i in seq_along(text)) {
    expect_false(matcher(list(fun = "fix_encoding", input = text[[i]],
                              reference = reference[[i]], actual = text[[i]])))
    expect_false(matcher(list(fun = "fix_text", input = text[[i]],
                              reference = reference[[i]], actual = NA_character_)))
  }
})
