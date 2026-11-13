# Departure `utf8-variants-trailing-newline`
# (inst/departures/utf8-variants-trailing-newline.dcf, ADR 0004): C0, or
# five bytes of a six-byte surrogate pair, followed by a newline that ends
# the input is undecodable, where the reference version reads the newline
# as the missing byte.
#
# Asserted here at the decoder level and through fix_encoding(). Ticket
# #41 adds the assertions through fix_text().

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

# The texts that reach the two sequences, and what the reference version
# gives for them (run on ftfy 6.3.1 with Python 3.13; U+0000 stays escaped).
cut_short_texts <- function() {
  c("sch\u00c3\u00b6n \u00c0\n", "\u00c3\u00a9t\u00c3\u00a9 \u00c0\n",
    "\u00ed\u00a0\u00bd\u00ed\u00b8\n", "caf\u00c3\u00a9 \u00ed\u00a0\u00bd\u00ed\u00b8\n")
}
cut_short_reference <- function() {
  unescape_reference(
    c("sch\\u00F6n \\u0000", "\\u00E9t\\u00E9 \\u0000", "\\U0001F60A", "caf\\u00E9 \\U0001F60A")
  )
}

test_that("fix_encoding() does not read the final newline as the missing byte", {
  # The whole string does not decode, so what remains is repaired
  # sequence by sequence, and the newline is kept.
  expect_identical(
    fix_encoding(cut_short_texts()),
    c("sch\u00f6n \u00c0\n", "\u00e9t\u00e9 \u00c0\n",
      "\u00ed\u00a0\u00bd\u00ed\u00b8\n", "caf\u00e9 \u00ed\u00a0\u00bd\u00ed\u00b8\n")
  )
})

test_that("fix_encoding() agrees with the reference version when anything else follows", {
  # Without the newline, and with a character after it, the reference
  # version fails to decode too. Its results are in the snapshot
  # reference/fix_encoding.tsv; these are the same texts.
  expect_identical(
    fix_encoding(c("sch\u00c3\u00b6n \u00c0", "sch\u00c3\u00b6n \u00c0\nx",
                   "sch\u00c3\u00b6n \u00c0\n\n",
                   "caf\u00c3\u00a9 \u00ed\u00a0\u00bd\u00ed\u00b8\nx")),
    c("sch\u00f6n \u00c0", "sch\u00f6n \u00c0\nx", "sch\u00f6n \u00c0\n\n",
      "caf\u00e9 \u00ed\u00a0\u00bd\u00ed\u00b8\nx")
  )
  # The complete pair decodes, with its newline kept.
  expect_identical(
    fix_encoding("\u00ed\u00a0\u00bd\u00ed\u00b8\u008a\n"),
    paste0(intToUtf8(0x1F60A), "\n")
  )
})

test_that("the registry entry matches the difference in fix_encoding() and no other", {
  matcher <- departure_matchers()[["utf8-variants-trailing-newline"]]
  text <- cut_short_texts()
  reference <- cut_short_reference()
  actual <- fix_encoding(text)

  for (i in seq_along(text)) {
    expect_true(matcher(list(fun = "fix_encoding", input = text[[i]],
                             reference = reference[[i]], actual = actual[[i]])))
    # Not yet a departure of any other export (ticket #41 adds fix_text()).
    expect_false(matcher(list(fun = "fix_text", input = text[[i]],
                              reference = reference[[i]], actual = actual[[i]])))
    # R lost the newline too, or gave nothing.
    expect_false(matcher(list(fun = "fix_encoding", input = text[[i]],
                              reference = reference[[i]], actual = "x")))
    expect_false(matcher(list(fun = "fix_encoding", input = text[[i]],
                              reference = reference[[i]], actual = NA_character_)))
    # The reference version kept the newline: some other difference.
    expect_false(matcher(list(fun = "fix_encoding", input = text[[i]],
                              reference = "x\n", actual = actual[[i]])))
  }
  # Texts that do not end in the sequence and a newline.
  for (other in c("one \u00c0\ntwo", "sch\u00c3\u00b6n \u00c0\n\n", "sch\u00c3\u00b6n \u00c0",
                  "caf\u00c3\u00a9\n", "\u00ed\u00a0\u00bd\n")) {
    expect_false(matcher(list(fun = "fix_encoding", input = other,
                              reference = "x", actual = other)))
  }
})

# apply_plan() (ticket #39). The plan the reference version gives for each
# of these texts is `encode latin-1 > decode utf-8-variants` (run on ftfy
# 6.3.1 with Python 3.13), and its own apply_plan() replays it to the
# texts of `cut_short_reference()`. Here that replay fails.
cut_short_plan <- "encode latin-1 > decode utf-8-variants"

test_that("apply_plan() fails on the reference version's plan for these texts", {
  text <- cut_short_texts()

  expect_identical(ftfy:::replay_plan(text, cut_short_plan), rep(NA_character_, 4L))
  expect_error(
    apply_plan(text, cut_short_plan),
    "failed in 4 of 4 elements.*In element 1, step 2 .*`decode utf-8-variants`, met bytes that the codec cannot decode",
    class = "ftfy_replay_failed"
  )
  # With anything after the newline the reference version fails too.
  expect_error(apply_plan(paste0(text[[1]], "x"), cut_short_plan), class = "ftfy_replay_failed")
  # The package's own plan for the same texts replays to its own text.
  explained <- fix_encoding_and_explain(text)
  expect_identical(apply_plan(text, explained$plan), explained$text)
})

test_that("the registry entry matches the failed replay in apply_plan() and no other", {
  matcher <- departure_matchers()[["utf8-variants-trailing-newline"]]
  text <- cut_short_texts()
  reference <- cut_short_reference()

  for (i in seq_along(text)) {
    expect_true(matcher(list(fun = "apply_plan", input = text[[i]],
                             reference = reference[[i]], actual = NA_character_)))
    # A replay that gave a text is not this departure.
    expect_false(matcher(list(fun = "apply_plan", input = text[[i]],
                              reference = reference[[i]], actual = text[[i]])))
    # Nor is a reference text that kept the newline.
    expect_false(matcher(list(fun = "apply_plan", input = text[[i]],
                              reference = text[[i]], actual = NA_character_)))
  }
  # A failed replay on a text that does not reach these bytes.
  expect_false(matcher(list(fun = "apply_plan", input = "caf\u00e9\n",
                            reference = "caf", actual = NA_character_)))
})
