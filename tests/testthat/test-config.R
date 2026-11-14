# Derived from python-ftfy v6.3.1, tests/test_entities.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# Options and `ftfy_config()` (ADR 0001), seen through `ftfy_config()` and
# `fix_encoding()`.

option_names <- c(
  "unescape_html", "remove_terminal_escapes", "fix_encoding",
  "restore_byte_a0", "replace_lossy_sequences", "decode_inconsistent_utf8",
  "fix_c1_controls", "fix_latin_ligatures", "fix_character_width",
  "uncurl_quotes", "fix_line_breaks", "remove_control_chars",
  "normalization", "max_decode_length"
)

mojibake <- c("caf\u00c3\u00a9", "plain", NA)
repaired <- c("caf\u00e9", "plain", NA)

test_that("ftfy_config() has the 14 options under upstream's names and defaults", {
  config <- ftfy_config()

  expect_s3_class(config, "ftfy_config")
  expect_identical(names(config), option_names)
  expect_identical(config$unescape_html, "auto")
  expect_identical(config$normalization, "NFC")
  expect_identical(config$max_decode_length, 1e6)
  for (name in option_names[2:12]) {
    expect_identical(config[[name]], TRUE, label = name)
  }
})

test_that("ftfy_config() saves the options it is given and keeps all 14", {
  config <- ftfy_config(uncurl_quotes = FALSE, normalization = NULL,
                        unescape_html = FALSE, max_decode_length = 10L)

  expect_identical(names(config), option_names)
  expect_identical(config$uncurl_quotes, FALSE)
  expect_null(config$normalization)
  expect_identical(config$unescape_html, FALSE)
  expect_identical(config$fix_line_breaks, TRUE)
  # A whole number is the same option whether integer or double.
  expect_identical(config, ftfy_config(
    uncurl_quotes = FALSE, normalization = NULL, unescape_html = FALSE,
    max_decode_length = 10
  ))
})

test_that("an ftfy_config prints every option", {
  shown <- capture.output(print(ftfy_config(normalization = NULL)))

  expect_identical(shown[[1]], "<ftfy_config>")
  expect_length(shown, 15L)
  expect_match(shown[[2]], "unescape_html += \"auto\"")
  expect_match(shown[[14]], "normalization += NULL")
})

test_that("fix_encoding() has the signature (x, ..., config = ftfy_config())", {
  expect_identical(names(formals(fix_encoding)), c("x", "...", "config"))
  expect_identical(formals(fix_encoding)$config, quote(ftfy_config()))
})

test_that("a named argument turns an option off for one call", {
  expect_identical(fix_encoding(mojibake), repaired)
  expect_identical(fix_encoding(mojibake, fix_encoding = FALSE), mojibake)
})

test_that("a saved config is used by every call it is passed to", {
  off <- ftfy_config(fix_encoding = FALSE)

  expect_identical(fix_encoding(mojibake, config = off), mojibake)
  expect_identical(fix_encoding(rev(mojibake), config = off), rev(mojibake))
  expect_identical(fix_encoding(mojibake, config = ftfy_config()), repaired)
})

test_that("a named argument overrides a saved config for one call", {
  off <- ftfy_config(fix_encoding = FALSE)
  on <- ftfy_config()

  expect_identical(fix_encoding(mojibake, fix_encoding = TRUE, config = off),
                   repaired)
  expect_identical(fix_encoding(mojibake, fix_encoding = FALSE, config = on),
                   mojibake)
  # The saved config is not changed by the call.
  expect_identical(off, ftfy_config(fix_encoding = FALSE))
})

test_that("normalization = NULL overrides a saved form, and a form a saved NULL", {
  expect_identical(
    fix_encoding(mojibake, normalization = NULL,
                 config = ftfy_config(normalization = "NFKC")),
    repaired
  )
  expect_identical(
    fix_encoding(mojibake, normalization = "NFC",
                 config = ftfy_config(normalization = NULL)),
    repaired
  )
})

test_that("the encoding-only function accepts every option and ignores the others", {
  off <- list(
    unescape_html = FALSE, remove_terminal_escapes = FALSE,
    fix_latin_ligatures = FALSE, fix_character_width = FALSE,
    uncurl_quotes = FALSE, fix_line_breaks = FALSE,
    remove_control_chars = FALSE, normalization = NULL,
    max_decode_length = 1
  )
  # Text the other fixers would change: none of them runs, whatever is set.
  x <- c(mojibake, "&amp; \u201cq\u201d \ufb01 e\u0301\r\n")
  expected <- c(repaired, x[[4]])

  expect_identical(fix_encoding(x), expected)
  expect_identical(do.call(fix_encoding, c(list(x), off)), expected)
  expect_identical(fix_encoding(x, config = do.call(ftfy_config, off)),
                   expected)
  for (name in names(off)) {
    expect_identical(do.call(fix_encoding, c(list(x), off[name])), expected,
                     label = name)
  }
  # The four options under `fix_encoding` are accepted too. None of them
  # takes part in repairing this text.
  for (name in option_names[4:7]) {
    given <- stats::setNames(list(FALSE), name)
    expect_identical(do.call(fix_encoding, c(list(x), given)), expected,
                     label = name)
  }
})

test_that("an unknown option name is an error suggesting the nearest name", {
  expect_error(fix_encoding(mojibake, uncurl_quote = FALSE),
               "Unknown option `uncurl_quote`. Did you mean `uncurl_quotes`?",
               fixed = TRUE)
  expect_error(ftfy_config(uncurl_quote = FALSE),
               "Unknown option `uncurl_quote`. Did you mean `uncurl_quotes`?",
               fixed = TRUE)
  expect_error(fix_encoding(mojibake, normalisation = NULL),
               "Did you mean `normalization`?", fixed = TRUE)
  expect_error(fix_encoding(mojibake, restore_byte_A0 = FALSE),
               "Did you mean `restore_byte_a0`?", fixed = TRUE)
  # An abbreviation is never matched to an option or to `config`.
  expect_error(fix_encoding(mojibake, conf = ftfy_config()),
               "Unknown option `conf`. Did you mean `config`?", fixed = TRUE)
  expect_error(fix_encoding(mojibake, uncurl = FALSE),
               "Unknown option `uncurl`. Did you mean `uncurl_quotes`?",
               fixed = TRUE)
  expect_error(fix_encoding(mojibake, fix_c1 = FALSE),
               "Unknown option `fix_c1`. Did you mean `fix_c1_controls`?",
               fixed = TRUE)
  # Nothing is near: the options are listed.
  expect_error(fix_encoding(mojibake, verbose = TRUE),
               "Unknown option `verbose`. The options are: unescape_html, ",
               fixed = TRUE)
  # The unknown name is reported even when another option is valid.
  expect_error(ftfy_config(uncurl_quotes = FALSE, fix_linebreaks = FALSE),
               "Did you mean `fix_line_breaks`?", fixed = TRUE)
})

test_that("an unnamed extra argument is an error", {
  message <- "without a name"
  expect_error(fix_encoding(mojibake, FALSE), message)
  expect_error(fix_encoding(mojibake, FALSE, uncurl_quotes = FALSE), message)
  expect_error(fix_encoding(mojibake, uncurl_quotes = FALSE, "NFC"), message)
  expect_error(fix_encoding(mojibake, ftfy_config()), message)
  expect_error(ftfy_config(FALSE), message)
  expect_error(ftfy_config(ftfy_config()), message)
})

test_that("an option given twice is an error", {
  expect_error(
    fix_encoding(mojibake, uncurl_quotes = FALSE, uncurl_quotes = TRUE),
    "`uncurl_quotes` is given more than once"
  )
  expect_error(ftfy_config(uncurl_quotes = FALSE, uncurl_quotes = FALSE),
               "`uncurl_quotes` is given more than once")
})

test_that("explain and fix_surrogates are rejected as unknown options", {
  for (name in c("explain", "fix_surrogates")) {
    for (value in list(TRUE, FALSE)) {
      given <- stats::setNames(list(value), name)
      expect_error(do.call(fix_encoding, c(list(mojibake), given)),
                   paste0("Unknown option `", name, "`. Python ftfy's"),
                   fixed = TRUE)
      expect_error(do.call(ftfy_config, given),
                   paste0("Unknown option `", name, "`. Python ftfy's"),
                   fixed = TRUE)
    }
  }
})

# tests/test_entities.py:40, test_old_parameter_name(). Upstream accepts the
# old name `fix_entities` with a deprecation warning; here it is an unknown
# option (ADR 0001). Upstream's two calls are the ones on `fix_text()`
# (tests/test_entities.py:43 and :45).
test_that("the old parameter name fix_entities is an unknown-option error", {
  example <- "&amp;\n<html>\n&amp;"
  message <- "Unknown option `fix_entities`. .*`unescape_html`"

  expect_error(fix_text(example, fix_entities = TRUE), message)
  expect_error(fix_text(example, fix_entities = FALSE), message)
  expect_error(fix_encoding(example, fix_entities = TRUE), message)
  expect_error(fix_encoding(example, fix_entities = FALSE), message)
  expect_error(fix_and_explain(example, fix_entities = TRUE), message)
  expect_error(fix_and_explain(example, fix_entities = FALSE), message)
  expect_error(ftfy_config(fix_entities = TRUE), message)
  expect_error(ftfy_config(fix_entities = FALSE), message)
})

test_that("each option must be a single non-NA value of the right type", {
  for (name in option_names[2:12]) {
    for (value in list(NA, 0, 1L, "FALSE", "auto", NULL, c(TRUE, FALSE),
                       logical(), list(TRUE), NA_character_)) {
      expect_error(do.call(ftfy_config, stats::setNames(list(value), name)),
                   paste0("Option `", name, "` must be `TRUE` or `FALSE`"),
                   fixed = TRUE)
    }
  }
  expect_error(
    fix_encoding(mojibake, restore_byte_a0 = "no"),
    "`restore_byte_a0` must be `TRUE` or `FALSE`, not the string \"no\"",
    fixed = TRUE
  )
  expect_error(fix_encoding(mojibake, uncurl_quotes = NA), "not `NA`")

  for (value in list(NA, "Auto", "always", 1, NULL, c("auto", "auto"),
                     NA_character_, c(TRUE, TRUE))) {
    expect_error(
      ftfy_config(unescape_html = value),
      "Option `unescape_html` must be `\"auto\"`, `TRUE` or `FALSE`",
      fixed = TRUE
    )
  }
  expect_identical(ftfy_config(unescape_html = TRUE)$unescape_html, TRUE)
  expect_identical(ftfy_config(unescape_html = "auto")$unescape_html, "auto")

  for (value in list("nfc", "NFC ", "none", NA, NA_character_, FALSE, 1,
                     c("NFC", "NFD"), character())) {
    expect_error(
      ftfy_config(normalization = value),
      "`normalization` must be `\"NFC\"`, `\"NFD\"`, `\"NFKC\"`, `\"NFKD\"` or `NULL`",
      fixed = TRUE
    )
  }
  for (form in c("NFC", "NFD", "NFKC", "NFKD")) {
    expect_identical(ftfy_config(normalization = form)$normalization, form)
  }

  for (value in list(NA, NA_real_, NA_integer_, 0, -1, 1.5, "10", TRUE, Inf,
                     NaN, NULL, c(1, 2), numeric())) {
    expect_error(
      ftfy_config(max_decode_length = value),
      "`max_decode_length` must be a single whole number, at least 1",
      fixed = TRUE
    )
  }
  expect_identical(ftfy_config(max_decode_length = 1L)$max_decode_length, 1)
})

test_that("options are never vectorised over x", {
  expect_error(
    fix_encoding(mojibake, fix_encoding = c(TRUE, FALSE, TRUE)),
    "not a <logical> of length 3. An option holds one value for the whole call"
  )
  expect_error(
    fix_encoding(mojibake, normalization = c("NFC", "NFD", "NFC")),
    "An option holds one value for the whole call"
  )
})

test_that("config must come from ftfy_config()", {
  message <- "`config` must be a set of options made by `ftfy_config()`"
  rejected <- list(
    NULL, list(), list(uncurl_quotes = FALSE), unclass(ftfy_config()),
    ftfy_config, TRUE, "NFC", NA
  )
  for (config in rejected) {
    expect_error(fix_encoding(mojibake, config = config), message,
                 fixed = TRUE)
  }

  # An object of the class that was changed by hand.
  altered <- "`config` does not hold the options `ftfy_config()` gives"
  missing_one <- ftfy_config()
  missing_one$uncurl_quotes <- NULL
  expect_error(fix_encoding(mojibake, config = missing_one), altered,
               fixed = TRUE)
  extra <- ftfy_config()
  extra$explain <- TRUE
  expect_error(fix_encoding(mojibake, config = extra), altered, fixed = TRUE)
  expect_error(
    fix_encoding(mojibake, config = structure(list(), class = "ftfy_config")),
    altered, fixed = TRUE
  )
  wrong_type <- ftfy_config()
  wrong_type$fix_encoding <- "yes"
  expect_error(fix_encoding(mojibake, config = wrong_type),
               "Option `fix_encoding` must be `TRUE` or `FALSE`", fixed = TRUE)
  # A bad config is an error even when a named argument would replace the
  # bad value.
  expect_error(
    fix_encoding(mojibake, fix_encoding = TRUE, config = wrong_type),
    "Option `fix_encoding` must be `TRUE` or `FALSE`", fixed = TRUE
  )
})

test_that("options are checked even when x is empty or all missing", {
  expect_error(fix_encoding(character(), uncurl_quote = FALSE),
               "Unknown option")
  expect_error(fix_encoding(NA_character_, FALSE), "without a name")
  expect_error(fix_encoding(character(), config = NULL), "ftfy_config()",
               fixed = TRUE)
})
