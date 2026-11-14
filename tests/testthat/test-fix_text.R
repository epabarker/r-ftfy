# Derived from python-ftfy v6.3.1, ftfy/__init__.py and README.md. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# Tests of fix_text(): upstream's doctests, the committed snapshot of the
# reference version (reference/fix_text.tsv), and its R-only behaviour.
# The upstream tests that go through fix_text are ported in
# test-characters.R, test-entities.R and test-json-cases.R.

# ftfy/__init__.py:297, the doctests of fix_text()
test_that("fix_text() gives the results of upstream's doctests", {
  # ftfy/__init__.py:297
  expect_identical(fix_text("\u00e2\u0153\u201d No problems"), "\u2714 No problems")
  # ftfy/__init__.py:300
  expect_identical(
    fix_text("&macr;\\_(\u00e3\u0083\u0084)_/&macr;"),
    "\u00af\\_(\u30c4)_/\u00af"
  )
  # ftfy/__init__.py:303. The docstring shows three full stops; the
  # reference version gives U+2026, which NFC leaves alone (the snapshot
  # reference/fix_text.tsv has this text).
  expect_identical(
    fix_text("Broken text&hellip; it&#x2019;s \ufb02ubberi\ufb01c!"),
    "Broken text\u2026 it's flubberific!"
  )
  # ftfy/__init__.py:306
  expect_identical(
    fix_text("\uff2c\uff2f\uff35\uff24\u3000\uff2e\uff2f\uff29\uff33\uff25\uff33"),
    "LOUD NOISES"
  )
})

# README.md:46 to :78, the examples of fix_text()
test_that("fix_text() gives the results of upstream's README", {
  # README.md:46
  expect_identical(fix_text("\u00e2\u0153\u201d No problems"), "\u2714 No problems")
  # README.md:53
  expect_identical(
    fix_text(paste0(
      "The Mona Lisa doesn\u00c3\u0192\u00c2\u00a2\u00c3\u00a2\u00e2\u20ac\u0161\u00c2\u00ac",
      "\u00c3\u00a2\u00e2\u20ac\u017e\u00c2\u00a2t have eyebrows."
    )),
    "The Mona Lisa doesn't have eyebrows."
  )
  # README.md:58
  expect_identical(fix_text("l\u2019humanit\u00c3\u00a9"), "l'humanit\u00e9")
  # README.md:63
  expect_identical(
    fix_text("\u00c3\u00a0 perturber la r\u00c3\u00a9flexion"),
    "\u00e0 perturber la r\u00e9flexion"
  )
  # README.md:65
  expect_identical(
    fix_text("\u00c3 perturber la r\u00c3\u00a9flexion"),
    "\u00e0 perturber la r\u00e9flexion"
  )
  # README.md:71
  expect_identical(fix_text("P&EACUTE;REZ"), "P\u00c9REZ")
  # README.md:78
  expect_identical(fix_text("IL Y MARQU\u00c9\u2026"), "IL Y MARQU\u00c9\u2026")
})

snapshot <- read_fix_text_snapshot()

test_that("fix_text() gives the reference version's texts with default options", {
  rows <- snapshot$default

  expect_reference("fix_text", rows$text, fix_text(rows$text), rows$fixed)
})

test_that("with default options the only differences from the snapshot are the trailing-newline rows", {
  rows <- snapshot$default
  actual <- fix_text(rows$text)
  differs <- which(actual != rows$fixed)
  ids <- vapply(differs, function(at) {
    departure_matching(list(fun = "fix_text", input = rows$text[[at]],
                            reference = rows$fixed[[at]], actual = actual[[at]]))
  }, "")

  expect_identical(length(differs), 3L)
  expect_identical(unique(ids), "utf8-variants-trailing-newline")
})

test_that("each option changes the texts as in the reference version", {
  for (variant in setdiff(names(snapshot), "default")) {
    rows <- snapshot[[variant]]
    actual <- fix_text_variant(rows$text, variant)

    expect_reference("fix_text", rows$text, actual, rows$fixed)
    # The variant shows: the reference version's results differ from its
    # results with default options on some rows. An option of the encoding
    # repair given by name is the exception: the reference version does
    # not pass it on (test-departure-encoding-sub-options-honoured.R).
    if (!variant %in% paste0("no_", encoding_sub_options)) {
      expect_gte(sum(rows$fixed != snapshot$default$fixed), 3L, label = variant)
    }
  }
})

test_that("options given through a saved config act as options given by name", {
  x <- snapshot$default$text
  variants <- fix_text_variants()

  for (variant in c("no_fix_encoding", "no_uncurl_quotes", "normalization_NULL",
                    "unescape_html_TRUE", "unescape_html_FALSE", "max_decode_length_3",
                    "no_decode_inconsistent_utf8")) {
    config <- do.call(ftfy_config, variants[[variant]])
    expect_identical(fix_text(x, config = config), fix_text_variant(x, variant), info = variant)
  }
  # A named argument overrides the config.
  expect_identical(
    fix_text(x, uncurl_quotes = TRUE, config = ftfy_config(uncurl_quotes = FALSE)),
    fix_text(x)
  )
})

# ftfy/__init__.py:346: the segments.
test_that("each line is fixed by itself, with the newline that ends it", {
  # A line that is not mojibake does not keep the repair from its
  # neighbours, as it does when the string is fixed whole.
  x <- "caf\u00c3\u00a9\n\u0413\u00a9 \u2603\nvoil\u00c3 le travail\n"
  lines <- c("caf\u00c3\u00a9\n", "\u0413\u00a9 \u2603\n", "voil\u00c3 le travail\n")

  expect_identical(fix_text(x), paste(fix_and_explain(lines)$text, collapse = ""))
  # Only "\n" ends a segment; the other line breaks become "\n" inside one.
  expect_identical(fix_text("a\r\nb\rc\u2028d\n\n"), "a\nb\nc\nd\n\n")
  # No last newline, nothing but newlines, and nothing at all.
  expect_identical(fix_text(c("caf\u00c3\u00a9\ncaf\u00c3\u00a9", "\n", "\n\n\n", "")),
                   c("caf\u00e9\ncaf\u00e9", "\n", "\n\n\n", ""))
})

test_that("a line longer than max_decode_length is fixed in pieces of that length", {
  x <- "caf\u00c3\u00a9 caf\u00c3\u00a9\ncaf\u00c3\u00a9"

  # Pieces of 5 from the start of each line: "caf\u00c3\u00a9", " caf\u00c3",
  # "\u00a9\n" and "caf\u00c3\u00a9". The second sequence is cut in two and
  # stays.
  expect_identical(
    fix_text(x, max_decode_length = 5),
    "caf\u00e9 caf\u00c3\u00a9\ncaf\u00e9"
  )
  # A line of exactly the length is one piece, newline and all.
  expect_identical(fix_text(x, max_decode_length = 12), "caf\u00e9 caf\u00e9\ncaf\u00e9")
  expect_identical(fix_text(x, max_decode_length = 11), "caf\u00e9 caf\u00e9\ncaf\u00e9")
  expect_identical(fix_text(x, max_decode_length = 10), "caf\u00e9 caf\u00c3\u00a9\ncaf\u00e9")
  # One character to a piece: nothing can be repaired, and nothing is lost.
  expect_identical(fix_text(x, max_decode_length = 1), x)
  expect_identical(fix_text(x, max_decode_length = 2^40), fix_text(x))
})

test_that("a leading U+FEFF and characters outside the first plane survive the cuts", {
  astral <- intToUtf8(c(0x1F600, 0x10000, 0x10FFFD))
  x <- c(
    paste0("\ufeff", astral, "\n\ufeff", astral, "\ufeff\n", astral),
    "\ufeff", "\ufeff\n\ufeff", paste0(astral, "\ufeffz\n"),
    paste0("\ufeff", strrep(paste0("\u00e9", astral, "\u4e16a"), 7))
  )
  # With the fixers that would change these texts off, they come back
  # whole however they are cut.
  for (length in c(1, 2, 3, 4, 7, 1e6)) {
    fixed <- fix_text(x, max_decode_length = length, remove_control_chars = FALSE)
    expect_identical(fixed, x, info = length)
    expect_identical(Encoding(fixed), rep("UTF-8", length(x)))
  }
  # With default options every U+FEFF goes, wherever the cuts fall.
  expect_identical(
    fix_text(x, max_decode_length = 2),
    gsub("\ufeff", "", x, fixed = TRUE)
  )
})

# ftfy/__init__.py:356: unescape_html = "auto" and the "<".
test_that("a segment with a `<` keeps the entities of the later segments of its string", {
  expect_identical(fix_text("&amp;\n<html>\n&amp;"), "&\n<html>\n&amp;")
  # In the segment that holds it too, and in every later one.
  expect_identical(fix_text("&amp;\n&amp; <\n&amp;\n&amp;"), "&\n&amp; <\n&amp;\n&amp;")
  # A "<" that unescaping makes does not count.
  expect_identical(fix_text("&lt;\n&amp;"), "<\n&")
  # Pieces of a long line are segments too.
  expect_identical(
    fix_text("&amp;&amp;<&amp;&amp;", max_decode_length = 5),
    "&&<&amp;&amp;"
  )
  expect_identical(fix_text("&amp;&amp;<&amp;&amp;"), "&amp;&amp;<&amp;&amp;")
})

test_that("a `<` never reaches into another element", {
  x <- c("<html>", "&amp;", "<\n&amp;", "&amp;", "&amp;\n<", "&amp;")

  expect_identical(fix_text(x), c("<html>", "&", "<\n&amp;", "&", "&\n<", "&"))
  # The same segment is fixed in both ways in one call, whatever the order.
  expect_identical(fix_text(rev(x)), rev(fix_text(x)))
  expect_identical(fix_text(c("&amp;\n", "<\n&amp;\n")), c("&\n", "<\n&amp;\n"))
  expect_identical(fix_text(c("<\n&amp;\n", "&amp;\n")), c("<\n&amp;\n", "&\n"))
})

test_that("unescape_html = TRUE and FALSE hold for every segment", {
  x <- c("&amp;\n<html>\n&amp;", "&amp;")

  expect_identical(fix_text(x, unescape_html = TRUE), c("&\n<html>\n&", "&"))
  expect_identical(fix_text(x, unescape_html = FALSE), x)
})

test_that("fix_text() keeps the shape of its input, missing strings and repeats", {
  x <- c(a = "caf\u00c3\u00a9\ncaf\u00c3\u00a9", b = NA, c = "plain", d = "caf\u00c3\u00a9\ncaf\u00c3\u00a9", e = "")

  expect_identical(
    fix_text(x),
    c(a = "caf\u00e9\ncaf\u00e9", b = NA, c = "plain", d = "caf\u00e9\ncaf\u00e9", e = "")
  )
  expect_identical(fix_text(character()), character())
  expect_identical(fix_text(NA), NA_character_)
  expect_identical(fix_text(c(NA_character_, NA_character_)), c(NA_character_, NA_character_))
  m <- matrix(c("caf\u00c3\u00a9", "a\nb", NA, "&amp;"), 2, dimnames = list(c("r1", "r2"), c("c1", "c2")))
  expect_identical(
    fix_text(m),
    matrix(c("caf\u00e9", "a\nb", NA, "&"), 2, dimnames = list(c("r1", "r2"), c("c1", "c2")))
  )
})

test_that("with default options a leading U+FEFF is removed, as in the reference version", {
  expect_identical(fix_text("\ufeffcaf\u00c3\u00a9\n\ufeffb"), "caf\u00e9\nb")
  expect_identical(fix_text("\ufeffhello", remove_control_chars = FALSE), "\ufeffhello")
})

# ADR 0008: each distinct value and each distinct segment is fixed once,
# and a value that no fixer can change is not looked at.
test_that("repeated values and segments are fixed once, and plain ASCII is skipped", {
  seen <- list()
  real <- ftfy:::fix_segments
  local_mocked_bindings(fix_segments = function(x, config, unescape_html = NULL) {
    seen[[length(seen) + 1L]] <<- x
    real(x, config, unescape_html)
  })
  x <- c(
    "plain ASCII, nothing to do", "two plain\nlines\n", "tab\tand ~ too",
    "caf\u00c3\u00a9", "caf\u00c3\u00a9", "caf\u00c3\u00a9\ncaf\u00c3\u00a9\nplain\n", NA,
    "&amp;", "<\n&amp;"
  )

  fixed <- fix_text(x)

  expect_identical(
    fixed,
    c("plain ASCII, nothing to do", "two plain\nlines\n", "tab\tand ~ too",
      "caf\u00e9", "caf\u00e9", "caf\u00e9\ncaf\u00e9\nplain\n", NA, "&", "<\n&amp;")
  )
  # One call for the whole vector. The plain values never reach it; the
  # segment "&amp;" is there twice, for its two settings of unescape_html.
  expect_length(seen, 1L)
  expect_setequal(
    seen[[1]],
    c("caf\u00c3\u00a9", "caf\u00c3\u00a9\n", "plain\n", "&amp;", "<\n")
  )
  expect_length(seen[[1]], 6L)

  # With unescape_html fixed for the call, each distinct segment is there once.
  seen <- list()
  fix_text(x, unescape_html = TRUE)
  expect_identical(anyDuplicated(seen[[1]]), 0L)

  # Nothing to do at all: the loop is not called.
  seen <- list()
  expect_identical(fix_text(c("plain", "", NA, "a\nb\n")), c("plain", "", NA, "a\nb\n"))
  expect_length(seen, 0L)
})

test_that("many lines in one string, and many strings, give what the lines give one by one", {
  lines <- snapshot$default$text
  lines <- lines[!grepl("[\n<]", lines) & nzchar(lines)]
  fixed <- fix_text(paste0(lines, "\n"))

  expect_gte(length(lines), 10L)
  expect_identical(fix_text(paste0(lines, "\n", collapse = "")), paste(fixed, collapse = ""))
  # Cut in batches of a few bytes, the result is the same.
  local_mocked_bindings(segment_batch_bytes = function() 16)
  x <- c(paste0(lines, "\n", collapse = ""), paste0(lines, "\n", lines, "\n"))
  expect_identical(
    fix_text(x),
    c(paste(fixed, collapse = ""), paste0(fixed, fixed))
  )
})

test_that("options are checked by fix_text() as by the other core functions", {
  expect_error(fix_text("a", uncurl_quote = FALSE), "Unknown option `uncurl_quote`")
  expect_error(fix_text("a", FALSE), "without a name")
  expect_error(fix_text(character(), max_decode_length = 0), "max_decode_length")
  expect_error(fix_text(1), "as.character()", fixed = TRUE)
  expect_error(fix_text("a", explain = FALSE), "Unknown option")
})

test_that("a regex overflow names fix_text()", {
  local_mocked_bindings(
    regex_opts = function() stringi::stri_opts_regex(unix_lines = TRUE, stack_limit = 1)
  )
  expect_error(
    fix_text(strrep("caf\u00c3\u00a9 ", 2000)),
    "^fix_text\\(\\): the regular expression engine ran out of stack",
    class = "ftfy_regex_overflow"
  )
})

# The fixture vector for the test below: the JSON cases, their extra-layer
# forms and the inputs of the fix_text() snapshot, with missing strings and
# repeats spread through it, and names.
whole_vector_fixture <- function() {
  cases <- read_json_cases()
  x <- c(cases$original, cases$reference.extra_layer, snapshot$default$text)
  x <- c(x, NA, x[seq(1, length(x), by = 3)], NA, NA)
  # A fixed shuffle, so that repeats and `NA`s are not next to each other.
  x <- x[order((seq_along(x) * 7919) %% 2503, seq_along(x))]
  names(x) <- paste0("n", seq_along(x))
  x
}

test_that("for all four core functions, one call on the whole vector gives what one call per element gives", {
  x <- whole_vector_fixture()
  expect_true(anyNA(x) && anyDuplicated(x) > 0L)
  option_sets <- list(
    list(),
    list(unescape_html = TRUE, normalization = "NFKC", max_decode_length = 7),
    list(restore_byte_a0 = FALSE, decode_inconsistent_utf8 = FALSE, uncurl_quotes = FALSE)
  )

  for (options in option_sets) {
    call <- function(fun, x) do.call(fun, c(list(x), options))
    info <- paste(names(options), collapse = ", ")

    # The two that return a vector: texts, names and missing strings.
    for (fun in list(fix_text, fix_encoding)) {
      whole <- call(fun, x)
      each <- vapply(seq_along(x), function(i) unname(call(fun, x[i])), "")
      expect_identical(unname(whole), each, info = info)
      expect_identical(names(whole), names(x), info = info)
      expect_identical(is.na(whole), is.na(x), info = info)
    }
    # The two that return a data frame: texts and plans.
    for (fun in list(fix_and_explain, fix_encoding_and_explain)) {
      whole <- call(fun, x)
      each <- lapply(seq_along(x), function(i) call(fun, x[i]))
      expect_identical(whole$text, vapply(each, function(one) one$text, ""), info = info)
      expect_identical(
        as.character(whole$plan),
        vapply(each, function(one) as.character(one$plan), ""),
        info = info
      )
      expect_identical(is.na(whole$text), unname(is.na(x)), info = info)
    }
  }
})
