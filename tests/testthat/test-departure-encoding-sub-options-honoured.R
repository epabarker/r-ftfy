# Departure `encoding-sub-options-honoured`
# (inst/departures/encoding-sub-options-honoured.dcf, ADR 0001): the four
# options of the encoding repair are honoured by fix_text() when they are
# given by name. The reference version honours them only in a
# TextFixerConfig; given as keyword arguments it repairs the encoding as
# with default options.
#
# The reference results here were run on ftfy 6.3.1 with Python 3.13 and
# are also in the snapshot reference/fix_text.tsv: the columns
# `no_<option>` hold the keyword form and `config_no_<option>` the
# TextFixerConfig form.

# One text for each option: the input, what the reference version gives
# for the keyword form (which is what it gives with default options), and
# what it gives for the option in a TextFixerConfig.
sub_option_examples <- function() {
  data.frame(
    option = c("restore_byte_a0", "replace_lossy_sequences",
               "decode_inconsistent_utf8", "fix_c1_controls"),
    text = c("voil\u00c3  le travail", "\u00c3\ufffdtude",
             "\u2603 caf\u00c3\u00a9", "\u0094\u044f"),
    keyword = c("voil\u00e0 le travail", "\ufffdtude", "\u2603 caf\u00e9", "\"\u044f"),
    config = c("voil\u00e0  le travail", "\u00c3\ufffdtude",
               "\u2603 caf\u00c3\u00a9", "\u0094\u044f"),
    stringsAsFactors = FALSE
  )
}

fix_text_without <- function(x, option, ...) {
  do.call(fix_text, c(list(x), stats::setNames(list(FALSE), option), list(...)))
}

test_that("fix_text() honours each option of the encoding repair given by name", {
  examples <- sub_option_examples()

  for (i in seq_len(nrow(examples))) {
    option <- examples$option[[i]]
    text <- examples$text[[i]]
    # With default options, the reference version's text.
    expect_identical(fix_text(text), examples$keyword[[i]], info = option)
    # With the option off, what the reference version gives for the option
    # in a TextFixerConfig, and not what it gives for the keyword.
    expect_identical(fix_text_without(text, option), examples$config[[i]], info = option)
    expect_false(examples$config[[i]] == examples$keyword[[i]], info = option)
  }
})

test_that("the option does the same by name, in a saved config, and in the other core functions", {
  examples <- sub_option_examples()

  for (i in seq_len(nrow(examples))) {
    option <- examples$option[[i]]
    text <- examples$text[[i]]
    saved <- do.call(ftfy_config, stats::setNames(list(FALSE), option))
    expect_identical(fix_text(text, config = saved), examples$config[[i]], info = option)
    expect_identical(
      do.call(fix_and_explain, c(list(text), stats::setNames(list(FALSE), option)))$text,
      examples$config[[i]],
      info = option
    )
  }
  # Each line of a string is repaired with the option, not only the first.
  expect_identical(
    fix_text("voil\u00c3  le travail\nvoil\u00c3  le travail\n", restore_byte_a0 = FALSE),
    "voil\u00e0  le travail\nvoil\u00e0  le travail\n"
  )
})

test_that("the snapshot shows the departure for every one of the four options", {
  snapshot <- read_fix_text_snapshot()

  for (option in encoding_sub_options) {
    keyword <- snapshot[[paste0("no_", option)]]
    config <- snapshot[[paste0("config_no_", option)]]
    actual <- fix_text_variant(keyword$text, paste0("no_", option))

    # The reference version ignores the keyword on every row.
    expect_identical(keyword$fixed, snapshot$default$fixed, info = option)
    # R gives what the reference version gives for the option in a config.
    expect_reference("fix_text", config$text, actual, config$fixed)
    # So R differs from the keyword form on the rows where the option
    # matters, and each of those differences is this departure or, on the
    # rows put there for it, the trailing-newline departure.
    differs <- which(actual != keyword$fixed)
    expect_gte(length(differs), 3L, label = option)
    ids <- vapply(differs, function(at) {
      departure_matching(list(fun = "fix_text", input = keyword$text[[at]],
                              reference = keyword$fixed[[at]], actual = actual[[at]]))
    }, "")
    expect_true(
      all(ids %in% c("encoding-sub-options-honoured", "utf8-variants-trailing-newline")),
      info = option
    )
    expect_gte(sum(ids == "encoding-sub-options-honoured"), 3L, label = option)
  }
})

test_that("the registry entry matches this difference and no other", {
  matcher <- departure_matchers()[["encoding-sub-options-honoured"]]
  examples <- sub_option_examples()

  for (i in seq_len(nrow(examples))) {
    text <- examples$text[[i]]
    keyword <- examples$keyword[[i]]
    config <- examples$config[[i]]
    expect_true(matcher(list(fun = "fix_text", input = text,
                             reference = keyword, actual = config)))
    # Only fix_text() differs: the other core functions honour the options
    # in the reference version too.
    for (fun in c("fix_and_explain", "fix_encoding", "fix_encoding_and_explain", "apply_plan")) {
      expect_false(matcher(list(fun = fun, input = text,
                                reference = keyword, actual = config)))
    }
    # R gave something that no one of the four options gives.
    expect_false(matcher(list(fun = "fix_text", input = text,
                              reference = keyword, actual = paste0(config, "x"))))
    expect_false(matcher(list(fun = "fix_text", input = text,
                              reference = keyword, actual = NA_character_)))
    # The reference text is not what default options give.
    expect_false(matcher(list(fun = "fix_text", input = text,
                              reference = paste0(keyword, "x"), actual = config)))
    expect_false(matcher(list(fun = "fix_text", input = text,
                              reference = config, actual = keyword)))
  }
  # A difference made by another option is not this departure.
  expect_false(matcher(list(fun = "fix_text", input = "\u201cq\u201d caf\u00c3\u00a9",
                            reference = "\"q\" caf\u00e9", actual = "\u201cq\u201d caf\u00e9")))
})
