# Tests of fix_and_explain() against the committed snapshot of the
# reference version, reference/fix_and_explain.tsv, and of its R-only
# behaviour. The upstream tests that go through fix_and_explain are ported
# in test-characters.R, test-entities.R and test-apply_plan.R.

snapshot <- read_fix_and_explain_snapshot()

test_that("fix_and_explain() gives the reference version's texts and plans with default options", {
  rows <- snapshot$default
  explained <- fix_and_explain(rows$text)

  expect_reference("fix_and_explain", rows$text, explained$text, rows$fixed)
  expect_reference("fix_and_explain", rows$text, as.character(explained$plan), rows$plan)
})

test_that("the only differences from the snapshot are the registered departures, on the rows put there for them", {
  rows <- snapshot$default
  explained <- fix_and_explain(rows$text)
  # The registry is read once, not for every row.
  matchers <- departure_matchers()
  departures_of <- function(actual, reference) {
    differs <- which(actual != reference)
    vapply(differs, function(i) {
      departure_matching(list(
        fun = "fix_and_explain", input = rows$text[[i]],
        reference = reference[[i]], actual = actual[[i]]
      ), matchers)
    }, "")
  }
  in_text <- departures_of(explained$text, rows$fixed)
  in_plan <- departures_of(as.character(explained$plan), rows$plan)

  # With default options a decoded U+0000 shows in the plan only: the two
  # rows that decode C0 80.
  expect_identical(sum(in_plan == "decoded-nul-dropped"), 2L)
  expect_true(all(in_text == "normalization-follows-icu"))
  expect_true(all(in_plan %in% c("decoded-nul-dropped", "normalization-follows-icu")))
  # The rows with characters of Unicode 15.0 are the only ones that can
  # differ by the ICU: four inputs.
  expect_lte(length(in_text), 4L)
  expect_identical(
    sum(in_text == "normalization-follows-icu") > 0L,
    stringi::stri_detect_charclass(intToUtf8(0x10EFD), "\\p{Cn}")
  )
})

test_that("each option changes the texts and the plans as in the reference version", {
  for (variant in setdiff(names(snapshot), "default")) {
    rows <- snapshot[[variant]]
    explained <- fix_and_explain_variant(rows$text, variant)

    # The variant shows: the reference version's results differ from its
    # results with default options on some rows.
    expect_gte(
      sum(rows$fixed != snapshot$default$fixed | rows$plan != snapshot$default$plan), 5L,
      label = variant
    )
    expect_reference("fix_and_explain", rows$text, explained$text, rows$fixed)
    expect_reference("fix_and_explain", rows$text, as.character(explained$plan), rows$plan)
  }
})

test_that("options given through a saved config act as options given by name", {
  x <- snapshot$default$text
  variants <- fix_and_explain_variants()

  for (variant in c("no_fix_encoding", "no_uncurl_quotes", "normalization_NULL",
                    "normalization_NFKD", "unescape_html_TRUE")) {
    config <- do.call(ftfy_config, variants[[variant]])
    expect_identical(
      fix_and_explain(x, config = config), fix_and_explain_variant(x, variant),
      info = variant
    )
  }
  # A named argument overrides the config.
  expect_identical(
    fix_and_explain(x, uncurl_quotes = TRUE, config = ftfy_config(uncurl_quotes = FALSE)),
    fix_and_explain(x)
  )
})

test_that("the snapshot shows every fixer, every action and steps that changed nothing", {
  plans <- unlist(lapply(snapshot, `[[`, "plan"))
  steps <- unique(unlist(strsplit(plans, " > ", fixed = TRUE)))

  expect_true(all(paste("apply", c(
    "unescape_html", "remove_terminal_escapes", "fix_c1_controls",
    "fix_latin_ligatures", "fix_character_width", "uncurl_quotes",
    "fix_line_breaks", "remove_control_chars", "decode_inconsistent_utf8"
  )) %in% steps))
  expect_true(all(paste("transcode", c(
    "fix_c1_controls", "restore_byte_a0", "replace_lossy_sequences"
  )) %in% steps))
  expect_true(all(paste("normalize", c("NFC", "NFD", "NFKC", "NFKD")) %in% steps))
  expect_true(any(startsWith(steps, "encode ")) && any(startsWith(steps, "decode ")))
  # A fixer recorded once for each round in which it changed the text.
  expect_true("apply unescape_html > apply unescape_html > apply unescape_html" %in% plans)
  # A step of the encoding repair that changed nothing, recorded in each
  # round that took it.
  rows <- snapshot$default
  expect_identical(
    rows$plan[rows$text == "broken&#x81;"],
    "apply unescape_html > transcode fix_c1_controls > transcode fix_c1_controls"
  )
  expect_identical(rows$plan[rows$text == "a\u0081b"], "transcode fix_c1_controls")
  expect_identical(rows$fixed[rows$text == "a\u0081b"], "a\u0081b")
})

test_that("every plan replays to its text, with every option", {
  for (variant in names(snapshot)) {
    x <- snapshot[[variant]]$text
    explained <- fix_and_explain_variant(x, variant)
    expect_identical(apply_plan(x, explained$plan), explained$text, info = variant)
  }
})

test_that("fix_and_explain() returns the data frame that fix_encoding_and_explain() returns", {
  x <- c("plain ascii", "G\u00c3\u00a0idhlig \u201cq\u201d", NA, "caf\u00e9", "", "plain ascii")
  result <- fix_and_explain(x)
  encoding <- fix_encoding_and_explain(x)

  expect_identical(class(result), "data.frame")
  expect_identical(names(result), names(encoding))
  expect_identical(attributes(result), attributes(encoding))
  expect_identical(vapply(result, function(column) class(column)[[1L]], ""),
                   vapply(encoding, function(column) class(column)[[1L]], ""))
  expect_identical(
    result$text, c("plain ascii", "G\u00e0idhlig \"q\"", NA, "caf\u00e9", "", "plain ascii")
  )
  expect_s3_class(result$plan, "ftfy_plan", exact = TRUE)
  expect_identical(
    as.character(result$plan),
    c("none", "apply decode_inconsistent_utf8 > apply uncurl_quotes", NA, "none", "none", "none")
  )
  expect_identical(
    Encoding(result$text), c("unknown", "UTF-8", "unknown", "UTF-8", "unknown", "unknown")
  )
})

test_that("zero-length and all-missing input give a data frame of the same shape", {
  empty <- fix_and_explain(character())
  expect_identical(empty, fix_encoding_and_explain(character()))
  expect_identical(nrow(empty), 0L)

  missing <- fix_and_explain(c(NA, NA))
  expect_identical(missing$text, c(NA_character_, NA_character_))
  expect_identical(as.character(missing$plan), c(NA_character_, NA_character_))
  expect_identical(fix_and_explain(NA), fix_and_explain(NA_character_))
})

test_that("names, dim and dimnames of the input are not carried", {
  named <- c(a = "caf\u00c3\u00a9", b = "plain")
  expect_identical(fix_and_explain(named), fix_and_explain(unname(named)))
  expect_null(names(fix_and_explain(named)$text))

  grid <- matrix(c("caf\u00c3\u00a9", "a", "b", NA), 2L, dimnames = list(c("r1", "r2"), NULL))
  expect_identical(fix_and_explain(grid), fix_and_explain(as.vector(grid)))
})

test_that("one call on the whole vector gives what one call per element gives", {
  # Not among the tests issue #14 keeps on CRAN: thousands of calls on one
  # string each, the slowest kind of test here. It runs wherever NOT_CRAN
  # is "true": every job of the R-CMD-check workflow.
  skip_on_cran()
  x <- c(snapshot$default$text, NA, snapshot$default$text[1:20], NA)
  whole <- fix_and_explain(x)
  each <- lapply(x, fix_and_explain)

  expect_identical(whole$text, vapply(each, function(one) one$text, ""))
  expect_identical(
    as.character(whole$plan), vapply(each, function(one) as.character(one$plan), "")
  )
  # And with options, in another order.
  shuffled <- rev(x)
  whole <- fix_and_explain(shuffled, unescape_html = TRUE, normalization = "NFKC")
  each <- lapply(shuffled, fix_and_explain, unescape_html = TRUE, normalization = "NFKC")
  expect_identical(whole$text, vapply(each, function(one) one$text, ""))
  expect_identical(
    as.character(whole$plan), vapply(each, function(one) as.character(one$plan), "")
  )
})

test_that("each string is one segment, whatever lines it has", {
  # With "auto", a "<" anywhere switches unescape_html off for the whole
  # string, also for the lines before it; fix_text() would fix line 1.
  explained <- fix_and_explain(c("&amp;\n<html>\n&amp;", "&amp;\nhtml\n&amp;"))

  expect_identical(explained$text, c("&amp;\n<html>\n&amp;", "&\nhtml\n&"))
  expect_identical(as.character(explained$plan), c("none", "apply unescape_html"))
})

test_that("unescape_html = \"auto\" is decided from the text as it comes in", {
  # The "<" that unescaping makes does not switch the fixer off: the
  # second round still unescapes (run on the reference version:
  # '&lt;b&gt; &amp;amp;' gives '<b> &').
  explained <- fix_and_explain("&lt;b&gt; &amp;amp;")

  expect_identical(explained$text, "<b> &")
  expect_identical(as.character(explained$plan), "apply unescape_html > apply unescape_html")
})

test_that("fix_c1_controls in the loop is gated by its own option, not by fix_encoding", {
  # Run on the reference version: fix_and_explain('it\x92s', fix_encoding=False)
  # gives ("it's", [('apply', 'fix_c1_controls'), ('apply', 'uncurl_quotes')]).
  explained <- fix_and_explain("it\u0092s", fix_encoding = FALSE)
  expect_identical(explained$text, "it's")
  expect_identical(as.character(explained$plan), "apply fix_c1_controls > apply uncurl_quotes")

  left <- fix_and_explain("it\u0092s", fix_encoding = FALSE, fix_c1_controls = FALSE)
  expect_identical(left$text, "it\u0092s")
  expect_identical(as.character(left$plan), "none")
})

test_that("with every fixer off and no normalisation nothing changes and no step is recorded", {
  x <- snapshot$default$text
  off <- fix_and_explain(
    x, unescape_html = FALSE, remove_terminal_escapes = FALSE, fix_encoding = FALSE,
    fix_c1_controls = FALSE, fix_latin_ligatures = FALSE, fix_character_width = FALSE,
    uncurl_quotes = FALSE, fix_line_breaks = FALSE, remove_control_chars = FALSE,
    normalization = NULL
  )

  expect_identical(off$text, x)
  expect_true(all(as.character(off$plan) == "none"))
})

# ADR 0006: a `latin1` mark is read as ISO 8859-1, so bytes 80 to 9F reach
# the fixers as C1 controls and their repair is a step of the plan.
test_that("a latin1-marked string with bytes 80 to 9F is repaired by a recorded step", {
  marked <- c("\x93quoted\x94 \x80 5", "it\x92s \x81 hole", "a\x85b", "it\x92s")
  Encoding(marked) <- "latin1"
  as_text <- c("\u0093quoted\u0094 \u0080 5", "it\u0092s \u0081 hole", "a\u0085b", "it\u0092s")

  explained <- fix_and_explain(marked)

  # What the reference version gives for the C1 controls (run on ftfy
  # 6.3.1 with Python 3.13).
  expect_identical(
    explained$text,
    c("\"quoted\" \u20ac 5", "it's \u0081 hole", "a\u2026b", "it's")
  )
  expect_identical(
    as.character(explained$plan),
    c("encode latin-1 > decode windows-1252 > apply uncurl_quotes",
      paste("transcode fix_c1_controls > transcode fix_c1_controls >",
            "apply uncurl_quotes > transcode fix_c1_controls"),
      "encode latin-1 > decode windows-1252",
      "encode latin-1 > decode windows-1252 > apply uncurl_quotes")
  )
  expect_identical(explained, fix_and_explain(as_text))
  expect_identical(apply_plan(marked, explained$plan), explained$text)
  # With the repair off, the C1 controls stay, and nothing is recorded.
  kept <- fix_and_explain(marked, fix_encoding = FALSE, fix_c1_controls = FALSE,
                          fix_line_breaks = FALSE)
  expect_identical(kept$text, as_text)
  expect_identical(as.character(kept$plan), rep("none", 4L))
})

test_that("with default options a leading U+FEFF is removed as a recorded step", {
  explained <- fix_and_explain(c("\ufeffhello", "\ufeff", "\ufeffcaf\u00c3\u00a9"))

  expect_identical(explained$text, c("hello", "", "caf\u00e9"))
  expect_identical(
    as.character(explained$plan),
    c("apply remove_control_chars", "apply remove_control_chars",
      "apply decode_inconsistent_utf8 > apply remove_control_chars")
  )
  # It is the fixer that removes it: with the fixer off it stays, through
  # every other fixer and all four normalisation forms.
  x <- c("\ufeffhello", "\ufeff", "\ufeff\u201ccaf\u00c3\u00a9\u201d &amp; \ufb01 e\u0301\r\n")
  for (form in c("NFC", "NFD", "NFKC", "NFKD")) {
    kept <- fix_and_explain(x, remove_control_chars = FALSE, normalization = form)$text
    expect_identical(substring(kept, 1L, 1L), rep("\ufeff", 3L), info = form)
  }
})

test_that("option errors are those of every core function", {
  expect_error(fix_and_explain("a", uncurl_quote = FALSE), "Unknown option")
  expect_error(fix_and_explain("a", FALSE), "without a name")
  expect_error(fix_and_explain(character(), config = NULL), "ftfy_config()", fixed = TRUE)
  expect_error(fix_and_explain("a", normalization = "nfc"), "Option `normalization`")
  expect_error(fix_and_explain(1), "as.character()", fixed = TRUE)
})

# The loop itself. ADR 0008: each fixer runs once over every element still
# changing, and only the elements a round changed go round again.
test_that("each fixer runs once a round, on the elements still changing only", {
  seen <- list()
  real <- ftfy:::fixer_uncurl_quotes
  local_mocked_bindings(fixer_uncurl_quotes = function(x) {
    seen[[length(seen) + 1L]] <<- x
    real(x)
  })

  explained <- fix_and_explain(c(
    "&amp;amp;amp;", "\u201cq\u201d", "plain", NA, "caf\u00e9", "\u201cq\u201d"
  ))

  expect_identical(explained$text, c("&", "\"q\"", "plain", NA, "caf\u00e9", "\"q\""))
  # Round 1: every distinct value that is neither missing nor plain ASCII.
  # Round 2: the two that changed. Rounds 3 and 4: the one still changing.
  expect_identical(seen, list(
    c("&amp;amp;", "\u201cq\u201d", "caf\u00e9"),
    c("&amp;", "\"q\""),
    "&",
    "&"
  ))
})

# The seam for fix_text() (ticket #41): the loop takes, for each segment,
# whether unescape_html runs on it.
test_that("the loop takes unescape_html per element and otherwise decides it from the config", {
  x <- c("&amp; a", "&amp; <b>", "&amp; a", NA)
  plans <- function(result) ftfy:::encoding_plan_text(result, x)

  auto <- ftfy:::fix_segments(x, ftfy_config())
  expect_identical(auto$text, c("& a", "&amp; <b>", "& a", NA))
  expect_identical(plans(auto), c("apply unescape_html", "none", "apply unescape_html", NA))
  expect_identical(names(auto$steps), c("element", "action", "parameter"))

  expect_identical(
    ftfy:::fix_segments(x, ftfy_config(unescape_html = TRUE))$text,
    c("& a", "& <b>", "& a", NA)
  )
  expect_identical(ftfy:::fix_segments(x, ftfy_config(unescape_html = FALSE))$text, x)

  # Given per element, it is used as given, whatever the config says and
  # whatever the element holds.
  given <- ftfy:::fix_segments(x, ftfy_config(), unescape_html = c(FALSE, TRUE, TRUE, TRUE))
  expect_identical(given$text, c("&amp; a", "& <b>", "& a", NA))
  expect_identical(plans(given), c("none", "apply unescape_html", "apply unescape_html", NA))
})
