# Derived from python-ftfy v6.3.1, ftfy/. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# The generated patterns (ADR 0005), checked below the exported functions:
# each of the ten must match exactly where the reference version's pattern
# matches. The span fixture is written by
# data-raw/generators/snapshot_pattern_spans.py.

pattern_names <- c(
  "BADNESS_RE", "UTF8_DETECTOR_RE", "ANSI_RE", "HTML_ENTITY_RE",
  "SINGLE_QUOTE_RE", "DOUBLE_QUOTE_RE", "C1_CONTROL_RE",
  "ALTERED_UTF8_RE", "LOSSY_UTF8_RE", "A_GRAVE_WORD_RE"
)
bytes_pattern_names <- c("ALTERED_UTF8_RE", "LOSSY_UTF8_RE", "A_GRAVE_WORD_RE")
# Generated too, but derived from upstream's BADNESS_RE rather than ported:
# they answer only whether a string holds a match of it, faster (#52).
# Python cannot compile the second, so they are checked below against
# BADNESS_RE's column of the fixture and are not columns of their own.
derived_pattern_names <- c("BADNESS_SCREEN_RE", "BADNESS_DETECT_RE")

read_pattern_spans <- function() {
  read_reference("pattern_spans.tsv")
}

# R's matches in the fixture's form: "start-end" joined by spaces, counted
# in code points from 0 with the end excluded.
spans_as_python_writes_them <- function(x, pattern) {
  found <- regex_locate_all(x, pattern)
  count <- lengths(found, use.names = FALSE) %/% 2L
  all <- do.call(rbind, found)
  one <- paste0(all[, 1L] - 1L, "-", all[, 2L])
  out <- character(length(x))
  joined <- vapply(split(one, rep(seq_along(x), count)), paste, "", collapse = " ")
  out[as.integer(names(joined))] <- joined
  out
}

test_that("the package holds the ten generated patterns and the two derived ones, each one ASCII line", {
  expect_setequal(names(patterns), c(pattern_names, derived_pattern_names))
  expect_true(all(stringi::stri_enc_isascii(patterns)))
  expect_false(any(grepl("\n", patterns, fixed = TRUE)))
  expect_false(any(grepl("\r", patterns, fixed = TRUE)))
})

test_that("no generated pattern sets an option inside itself or holds a space or a hash", {
  # "(?x)" and its like would switch on what ADR 0005 forbids. The only
  # groups that start "(?" are the three the generator writes, and the
  # lookbehind of BADNESS_DETECT_RE. Every literal is written as \x{...},
  # so no pattern needs a space or a hash.
  rest <- patterns
  for (group in c("(?:", "(?!", "(?<!", "(?<=")) {
    rest <- gsub(group, "", rest, fixed = TRUE)
  }
  expect_false(any(grepl("(?", rest, fixed = TRUE)))
  expect_false(any(grepl(" ", patterns, fixed = TRUE)))
  expect_false(any(grepl("#", patterns, fixed = TRUE)))
})

test_that("the span fixture has about 20,000 strings and exercises every pattern", {
  fixture <- read_pattern_spans()

  expect_gt(nrow(fixture), 18000)
  expect_setequal(names(fixture), c("kind", "text", pattern_names))
  expect_setequal(fixture$kind, c("text", "bytes"))
  for (name in pattern_names) {
    expect_gte(sum(nzchar(fixture[[name]])), 300, label = name)
    # Strings with two or more matches.
    expect_gte(sum(grepl(" ", fixture[[name]], fixed = TRUE)), 40, label = name)
  }
})

test_that("a bytes row of the fixture is a byte string held as text", {
  fixture <- read_pattern_spans()
  bytes <- fixture$text[fixture$kind == "bytes"]

  expect_gt(length(bytes), 5000)
  expect_true(all(vapply(lapply(bytes, utf8ToInt), max, 0L) <= 0xFFL))
  # The bytes patterns are not run on text rows.
  for (name in bytes_pattern_names) {
    expect_true(all(fixture[[name]][fixture$kind == "text"] == ""), label = name)
  }
})

for (name in pattern_names) {
  test_that(paste(name, "matches exactly where the reference version's pattern matches"), {
    fixture <- read_pattern_spans()
    if (name %in% bytes_pattern_names) {
      fixture <- fixture[fixture$kind == "bytes", ]
    }

    spans <- spans_as_python_writes_them(fixture$text, patterns[[name]])

    differs <- which(spans != fixture[[name]])
    expect_identical(
      stringi::stri_escape_unicode(fixture$text[differs]), character(0),
      label = paste("the strings on which", name, "differs")
    )
  })
}

test_that("BADNESS_SCREEN_RE matches every string that BADNESS_RE matches in the reference version", {
  fixture <- read_pattern_spans()
  fixture <- fixture[fixture$kind == "text", ]
  bad <- nzchar(fixture$BADNESS_RE)

  screened <- regex_detect(fixture$text, patterns[["BADNESS_SCREEN_RE"]])

  expect_identical(
    stringi::stri_escape_unicode(fixture$text[bad & !screened]), character(0),
    label = "the bad strings the screen lets through as not bad"
  )
  # A screen that matched everything would pass the line above.
  expect_gt(sum(!screened & !bad), 1000)
})

test_that("BADNESS_DETECT_RE matches a string exactly when BADNESS_RE matches it in the reference version", {
  fixture <- read_pattern_spans()
  fixture <- fixture[fixture$kind == "text", ]

  found <- regex_detect(fixture$text, patterns[["BADNESS_DETECT_RE"]])

  differs <- which(found != nzchar(fixture$BADNESS_RE))
  expect_identical(
    stringi::stri_escape_unicode(fixture$text[differs]), character(0),
    label = "the strings on which BADNESS_DETECT_RE differs"
  )
})

test_that("every branch of BADNESS_DETECT_RE starts on a character that cannot be ASCII, or at the start", {
  # What makes it fast (#52): ICU can skip every ASCII character, because
  # no match of it starts on one. BADNESS_RE's matches do, on the strings
  # where a branch that begins with [a-z] or \s matches.
  fixture <- read_pattern_spans()
  text <- fixture$text[fixture$kind == "text"]
  starts_on_ascii <- function(pattern) {
    located <- regex_locate_all(text, pattern)
    first <- unlist(lapply(located, function(m) m[, 1L]), use.names = FALSE)
    of <- rep.int(seq_along(text), vapply(located, nrow, 0L))
    character_at <- substring(text[of], first, first)
    sum(first > 1L & stringi::stri_enc_isascii(character_at))
  }

  expect_gt(starts_on_ascii(patterns[["BADNESS_RE"]]), 100)
  expect_identical(starts_on_ascii(patterns[["BADNESS_DETECT_RE"]]), 0L)
})

test_that("regex_locate_all() gives one two-column matrix per string, and NA for NA", {
  found <- regex_locate_all(c("a\u2018b\u2019", "none", NA, ""), patterns[["SINGLE_QUOTE_RE"]])

  expect_length(found, 4L)
  expect_equal(unname(found[[1]]), cbind(c(2L, 4L), c(2L, 4L)))
  expect_identical(nrow(found[[2]]), 0L)
  expect_true(all(is.na(found[[3]])))
  expect_identical(nrow(found[[4]]), 0L)
})

test_that("a match is located by code point after a leading U+FEFF and astral characters", {
  found <- regex_locate_all("\ufeff\U0001f600\u201cx", patterns[["DOUBLE_QUOTE_RE"]])

  expect_equal(unname(found[[1]]), cbind(3L, 3L))
})
