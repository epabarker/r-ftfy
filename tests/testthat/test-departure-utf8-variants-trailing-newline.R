# Departure `utf8-variants-trailing-newline`
# (inst/departures/utf8-variants-trailing-newline.dcf, ADR 0004): C0, or
# five bytes of a six-byte surrogate pair, followed by a newline that ends
# the input is undecodable, where the reference version reads the newline
# as the missing byte.
#
# Asserted here at the decoder level and through fix_encoding(),
# apply_plan(), fix_and_explain() and fix_text().

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
    # Not a departure of fix_and_explain(): no snapshot row shows it there.
    expect_false(matcher(list(fun = "fix_and_explain", input = text[[i]],
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

# fix_and_explain() (ticket #40). The reference version gives ('sch\\xf6n ',
# [('encode', 'latin-1'), ('decode', 'utf-8-variants'), ('apply',
# 'remove_control_chars')]) for this text: the newline is read as the
# second byte of C0 80 and the U+0000 is then removed (run on ftfy 6.3.1
# with Python 3.13). No row of the fix_and_explain() snapshot shows this
# departure, so the matcher is not widened to it.
test_that("fix_and_explain() keeps the newline after a sequence cut short", {
  text <- "sch\u00c3\u00b6n \u00c0\n"
  explained <- fix_and_explain(text)

  expect_identical(explained$text, "sch\u00f6n \u00c0\n")
  expect_identical(as.character(explained$plan), "apply decode_inconsistent_utf8")
  expect_identical(apply_plan(text, explained$plan), explained$text)
})

# fix_text() (ticket #41): the example of ADR 0004. Each line is repaired
# with its newline, so the departure is met at the end of any line, not
# only at the end of the input. The reference results were run on ftfy
# 6.3.1 with Python 3.13 and are in the snapshot reference/fix_text.tsv.
cut_short_lines <- function() {
  c("sch\u00c3\u00b6n \u00c0\n", "one \u00c3\u00a9 \u00c0\ntwo \u00c3\u00a9",
    "caf\u00c3\u00a9 \u00ed\u00a0\u00bd\u00ed\u00b8\n")
}
cut_short_lines_reference <- function() {
  c("sch\u00f6n ", "one \u00e9 two \u00e9", paste0("caf\u00e9 ", intToUtf8(0x1F60A)))
}

test_that("fix_text() keeps the newline and the character before it", {
  # ADR 0004: the reference version gives 'sch\u00f6n ' for the first.
  expect_identical(
    fix_text(cut_short_lines()),
    c("sch\u00f6n \u00c0\n", "one \u00e9 \u00c0\ntwo \u00e9",
      "caf\u00e9 \u00ed\u00a0\u00bd\u00ed\u00b8\n")
  )
  expect_identical(
    fix_text("sch\u00c3\u00b6n \u00c0\n", remove_control_chars = FALSE),
    "sch\u00f6n \u00c0\n"
  )
})

test_that("fix_text() agrees with the reference version when the line does not end there", {
  snapshot <- read_fix_text_snapshot()$default
  rows <- snapshot[snapshot$text %in% c(
    "sch\u00c3\u00b6n \u00c0",
    "caf\u00c3\u00a9 \u00ed\u00a0\u00bd\u00ed\u00b8\u008a\n"
  ), ]

  expect_identical(nrow(rows), 2L)
  expect_identical(fix_text(rows$text), rows$fixed)
  expect_identical(
    fix_text("caf\u00c3\u00a9 \u00ed\u00a0\u00bd\u00ed\u00b8\u008a\n"),
    paste0("caf\u00e9 ", intToUtf8(0x1F60A), "\n")
  )
})

test_that("the snapshot of fix_text() shows the departure on the three rows put there for it", {
  snapshot <- read_fix_text_snapshot()

  expect_true(all(cut_short_lines() %in% snapshot$default$text))
  for (variant in names(snapshot)) {
    rows <- snapshot[[variant]]
    actual <- fix_text_variant(rows$text, variant)
    differs <- which(actual != rows$fixed)
    ids <- vapply(differs, function(at) {
      id <- departure_matching(list(fun = "fix_text", input = rows$text[[at]],
                                    reference = rows$fixed[[at]], actual = actual[[at]]))
      if (is.null(id)) "" else id
    }, "")
    shown <- rows$text[differs[ids == "utf8-variants-trailing-newline"]]
    expected <- switch(
      variant,
      # With no encoding repair nothing is decoded, and cut into pieces of
      # 3 characters no piece ends in such a sequence and a newline.
      no_fix_encoding = ,
      max_decode_length_3 = character(),
      # The first two are lines of no more than 10 characters.
      max_decode_length_10 = cut_short_lines()[1:2],
      cut_short_lines()
    )
    expect_setequal(shown, expected)
  }
})

test_that("the registry entry matches the difference in fix_text() and no other", {
  matcher <- departure_matchers()[["utf8-variants-trailing-newline"]]
  text <- cut_short_lines()
  reference <- cut_short_lines_reference()
  actual <- fix_text(text)

  for (i in seq_along(text)) {
    expect_true(matcher(list(fun = "fix_text", input = text[[i]],
                             reference = reference[[i]], actual = actual[[i]])))
    # The reference version kept as many newlines as R: some other difference.
    expect_false(matcher(list(fun = "fix_text", input = text[[i]],
                              reference = paste0(reference[[i]], "\n"), actual = actual[[i]])))
    # R lost the newline too, or gave nothing.
    expect_false(matcher(list(fun = "fix_text", input = text[[i]],
                              reference = reference[[i]], actual = reference[[i]])))
    expect_false(matcher(list(fun = "fix_text", input = text[[i]],
                              reference = reference[[i]], actual = NA_character_)))
  }
  # With remove_control_chars off the reference text holds U+0000 and
  # stays escaped.
  expect_true(matcher(list(fun = "fix_text", input = text[[1]],
                           reference = "sch\\u00F6n \\u0000", actual = actual[[1]])))
  expect_false(matcher(list(fun = "fix_text", input = text[[1]],
                            reference = "sch\\u00F6n \\u0000\\u000A", actual = actual[[1]])))
  # Texts in which no line ends in the sequence and a newline.
  for (other in c("one\ntwo\n", "sch\u00c3\u00b6n \u00c0", "caf\u00c3\u00a9\n\u00c0",
                  "\u00ed\u00a0\u00bd\n")) {
    expect_false(matcher(list(fun = "fix_text", input = other,
                              reference = "x", actual = "x\n")))
  }
})
