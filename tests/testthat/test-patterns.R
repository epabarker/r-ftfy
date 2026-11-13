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

test_that("the package holds the ten generated patterns, each one ASCII line", {
  expect_setequal(names(patterns), pattern_names)
  expect_true(all(stringi::stri_enc_isascii(patterns)))
  expect_false(any(grepl("\n", patterns, fixed = TRUE)))
  expect_false(any(grepl("\r", patterns, fixed = TRUE)))
})

test_that("no generated pattern sets an option inside itself or holds a space or a hash", {
  # "(?x)" and its like would switch on what ADR 0005 forbids. The only
  # groups that start "(?" are the three the generator writes. Every
  # literal is written as \x{...}, so no pattern needs a space or a hash.
  rest <- patterns
  for (group in c("(?:", "(?!", "(?<!")) {
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
