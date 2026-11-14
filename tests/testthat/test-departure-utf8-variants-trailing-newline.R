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
    # Not matched for fix_and_explain() without the options R was called
    # with: that is the rule below, at the end of this file.
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
# with Python 3.13). The corpus shows it there; the matcher reaches it
# through the rule for differences that name R's options (end of this file).
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
  # The registry is read once, not for every row.
  matchers <- departure_matchers()

  expect_true(all(cut_short_lines() %in% snapshot$default$text))
  for (variant in names(snapshot)) {
    rows <- snapshot[[variant]]
    actual <- fix_text_variant(rows$text, variant)
    differs <- which(actual != rows$fixed)
    ids <- vapply(differs, function(at) {
      id <- departure_matching(list(fun = "fix_text", input = rows$text[[at]],
                                    reference = rows$fixed[[at]], actual = actual[[at]]),
                               matchers)
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

# The cases the corpus comparison (ticket #44) found that the rules above
# do not reach: a line that only a later codec encodes to the bytes, a
# piece cut by `max_decode_length`, the texts and plans of the two
# explaining functions. The reference results were run on ftfy 6.3.1 with
# Python 3.13. R keeps the newline in each.
test_that("R keeps the newline where only a later codec, or a cut piece, reaches the bytes", {
  # Latin-1 cannot encode U+201A; sloppy-windows-1252 can, and gives no C0;
  # MacRoman gives the inverted question mark as C0. The reference version
  # gives "David O'Brien".
  expect_identical(
    fix_text("David O\u201a\u00c4\u00f4Brien\u00bf\n"),
    "David O'\u00c4\u00f4Brien\u00bf\n"
  )
  # The last piece of ten characters is "arc\u00c3\u00ada \u00c0\n". The
  # reference version gives "Grzegorz Garc\u00eda ".
  expect_identical(
    fix_text("Grzegorz Garc\u00c3\u00ada \u00c0\n", max_decode_length = 10),
    "Grzegorz Garc\u00eda \u00c0\n"
  )
  # Five bytes of a surrogate pair through sloppy-windows-1250. The
  # reference version gives the text with U+1F60A and the plan
  # `encode sloppy-windows-1250 > decode utf-8-variants`.
  explained <- fix_and_explain("Emma Kowalski\u00ed\u00a0\u02dd\u00ed\u00b8\n")
  expect_identical(explained$text, "Emma Kowalski\u00ed\u00a0\u02dd\u00ed\u00b8\n")
  expect_identical(as.character(explained$plan), "none")
})

# The rule for a difference that names the options R was called with, as
# the corpus comparison gives it: R is run again with its decoder reading a
# final newline as the reference version does, and must then give the
# reference version's result.
trailing_newline_differences <- function() {
  scho <- "sch\u00c3\u00b6n \u00c0\n"
  david <- "David O\u201a\u00c4\u00f4Brien\u00bf\n"
  emma <- "Emma Kowalski\u00ed\u00a0\u02dd\u00ed\u00b8\n"
  list(
    list(fun = "fix_and_explain", input = scho, reference = "sch\u00f6n ",
         actual = "sch\u00f6n \u00c0\n", what = "text", options = list()),
    list(fun = "fix_and_explain", input = scho,
         reference = "encode latin-1 > decode utf-8-variants > apply remove_control_chars",
         actual = "apply decode_inconsistent_utf8", what = "plan", options = list()),
    # With remove_control_chars off the reference text keeps U+0000, and
    # stays escaped.
    list(fun = "fix_and_explain", input = scho, reference = "sch\\u00F6n \\u0000",
         actual = "sch\u00f6n \u00c0\n", what = "text",
         options = list(remove_control_chars = FALSE)),
    list(fun = "fix_and_explain", input = scho,
         reference = "encode latin-1 > decode utf-8-variants",
         actual = "apply decode_inconsistent_utf8", what = "plan",
         options = list(remove_control_chars = FALSE)),
    list(fun = "fix_encoding_and_explain", input = scho, reference = "sch\\u00F6n \\u0000",
         actual = "sch\u00f6n \u00c0\n", what = "text", options = list()),
    list(fun = "fix_encoding_and_explain", input = emma,
         reference = "encode sloppy-windows-1250 > decode utf-8-variants",
         actual = "none", what = "plan", options = list()),
    list(fun = "fix_encoding", input = emma, reference = paste0("Emma Kowalski", intToUtf8(0x1F60A)),
         actual = emma, options = list()),
    list(fun = "fix_text", input = david, reference = "David O'Brien",
         actual = "David O'\u00c4\u00f4Brien\u00bf\n", options = list()),
    list(fun = "fix_text", input = "Grzegorz Garc\u00c3\u00ada \u00c0\n",
         reference = "Grzegorz Garc\u00eda ", actual = "Grzegorz Garc\u00eda \u00c0\n",
         options = list(max_decode_length = 10)),
    # The reference version's keyword form ignores the option: its result
    # is looked for with default options.
    list(fun = "fix_text", input = scho, reference = "sch\u00f6n ",
         actual = "sch\u00f6n \u00c0\n", options = list(restore_byte_a0 = FALSE),
         form = "keyword"),
    list(fun = "apply_plan", input = david, reference = "David O'Brien", actual = NA_character_,
         plan = "encode macroman > decode utf-8-variants > apply uncurl_quotes > apply remove_control_chars",
         options = list())
  )
}

test_that("the registry entry matches these differences when they name R's options", {
  matcher <- departure_matchers()[["utf8-variants-trailing-newline"]]
  differences <- trailing_newline_differences()

  for (difference in differences) {
    expect_true(matcher(difference), info = paste(difference$fun, difference$what))
  }
  # Without the options only the older rules apply, and they reach neither
  # the explaining functions nor a line that a later codec encodes.
  expect_false(matcher(differences[[1]][c("fun", "input", "reference", "actual")]))
  expect_false(matcher(differences[[8]][c("fun", "input", "reference", "actual")]))
})

test_that("the registry entry matches no other difference that names R's options", {
  matcher <- departure_matchers()[["utf8-variants-trailing-newline"]]
  differences <- trailing_newline_differences()
  with <- function(i, ...) utils::modifyList(differences[[i]], list(...))

  # The reference version's result is not what reading the newline as it
  # does gives.
  expect_false(matcher(with(1, reference = "sch\u00f6n x")))
  expect_false(matcher(with(1, reference = "sch\u00f6n \n")))
  expect_false(matcher(with(2, reference = "encode sloppy-windows-1252 > decode utf-8-variants > apply remove_control_chars")))
  expect_false(matcher(with(8, reference = "David O'Brien\u00bf\n")))
  # An extra `apply remove_control_chars` is allowed for fix_and_explain()
  # only, which runs that fixer.
  expect_false(matcher(with(6, reference = "encode sloppy-windows-1250 > decode utf-8-variants > apply remove_control_chars")))
  # The decoder never meets such bytes: something follows the newline, the
  # repair is switched off, or the line is cut too short.
  expect_false(matcher(with(1, input = "sch\u00c3\u00b6n \u00c0\nx", actual = "sch\u00f6n \u00c0\nx")))
  expect_false(matcher(with(1, options = list(fix_encoding = FALSE))))
  expect_false(matcher(with(9, options = list(max_decode_length = 3))))
  # R raised an error or gave nothing; a replay that gave a text.
  expect_false(matcher(with(1, actual = simpleError("boom"))))
  expect_false(matcher(with(1, actual = NA_character_)))
  expect_false(matcher(with(11, actual = "David O'Brien")))
  # Another function.
  expect_false(matcher(with(1, fun = "uncurl_quotes")))
})
