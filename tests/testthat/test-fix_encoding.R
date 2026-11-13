# Derived from python-ftfy v6.3.1, ftfy/__init__.py and README.md. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# Upstream's test_byte_order_mark (tests/test_characters.py:17) is in
# test-characters.R, the mirror of that file.

# The snapshot reference/fix_encoding.tsv, written by
# data-raw/generators/snapshot_fix_encoding.py. A sparse column is filled
# from the column it stands for, and every reference text is read with
# `unescape_reference()`, which leaves a text holding U+0000 escaped.
encoding_options <- c(
  "restore_byte_a0", "replace_lossy_sequences",
  "decode_inconsistent_utf8", "fix_c1_controls"
)

read_encoding_snapshot <- function() {
  raw <- read_reference_table("fix_encoding.tsv", text = character())
  fill <- function(column, from) ifelse(raw[[column]] == "", raw[[from]], raw[[column]])
  out <- data.frame(
    text = stringi::stri_unescape_unicode(raw$text),
    fixed = unescape_reference(raw$fixed),
    plan = raw$plan,
    decode_inconsistent_utf8 = unescape_reference(fill("decode_inconsistent_utf8", "text")),
    fix_c1_controls = unescape_reference(fill("fix_c1_controls", "text")),
    stringsAsFactors = FALSE
  )
  for (option in encoding_options) {
    out[[paste0("no_", option)]] <- unescape_reference(fill(paste0("no_", option), "fixed"))
    out[[paste0("plan_no_", option)]] <- fill(paste0("plan_no_", option), "plan")
  }
  out
}

# The plans the repair records inside itself, which ticket #37 exports
# through fix_encoding_and_explain(). Until then they are read here.
internal_plans <- function(x, ...) {
  repaired <- ftfy:::repair_encoding(x, ftfy_config(...))
  ftfy:::encoding_plan_text(repaired, x)
}

# The rows on which the package departs from the reference version, by
# the registry entry that matches the difference.
departure_rows <- function(snapshot, result) {
  matchers <- departure_matchers()
  vapply(seq_along(result), function(i) {
    if (identical(result[[i]], snapshot$fixed[[i]])) {
      return("")
    }
    id <- departure_matching(
      list(fun = "fix_encoding", input = snapshot$text[[i]],
           reference = snapshot$fixed[[i]], actual = result[[i]]),
      matchers
    )
    if (is.null(id)) "unmatched" else id
  }, "")
}

# Upstream doctest of fix_encoding(), ftfy/__init__.py:593.
test_that("fix_encoding() repairs mojibake and leaves HTML entities alone", {
  expect_identical(fix_encoding("\u00c3\u00b3"), "\u00f3")
  expect_identical(fix_encoding("&ATILDE;&SUP3;"), "&ATILDE;&SUP3;")
})

# Upstream doctest of fix_encoding_and_explain(), ftfy/__init__.py:437.
test_that("fix_encoding() repairs a one-layer mix-up, also across a space that was a no-break space", {
  expect_identical(fix_encoding("s\u00c3\u00b3"), "s\u00f3")
  expect_identical(fix_encoding("voil\u00c3 le travail"), "voil\u00e0 le travail")
  expect_identical(
    internal_plans(c("s\u00c3\u00b3", "voil\u00c3 le travail")),
    c("encode latin-1 > decode utf-8",
      "encode latin-1 > transcode restore_byte_a0 > decode utf-8")
  )
})

# README.md:9
test_that("fix_encoding() repairs the README's example", {
  expect_identical(
    fix_encoding("(\u00e0\u00b8\u2021'\u00e2\u0152\u00a3')\u00e0\u00b8\u2021"),
    "(\u0e07'\u2323')\u0e07"
  )
})

test_that("fix_encoding() works over a whole vector and leaves text that is not bad unchanged", {
  x <- c(
    "caf\u00c3\u00a9", "caf\u00e9", "plain", "", NA,
    "it\u00e2\u20ac\u2122s", "\u00c3\u00a9t\u00c3\u00a9", "caf\u00c3\u00a9"
  )

  expect_identical(
    fix_encoding(x),
    c("caf\u00e9", "caf\u00e9", "plain", "", NA, "it\u2019s", "\u00e9t\u00e9", "caf\u00e9")
  )
})

test_that("fix_encoding() leaves quotes, ligatures and line breaks alone", {
  x <- c("\u201cquoted\u201d", "\ufb01n", "one\r\ntwo", "&amp;")

  expect_identical(fix_encoding(x), x)
})

test_that("fix_encoding() gives the reference version's text for every snapshot input", {
  snapshot <- read_encoding_snapshot()
  expect_gt(nrow(snapshot), 2300)
  # Every part of the heuristic is in the snapshot.
  for (part in c(paste0("encode ", ftfy:::charmap_codecs()), "decode windows-1252",
                 "decode utf-8-variants", "transcode restore_byte_a0",
                 "transcode replace_lossy_sequences", "apply decode_inconsistent_utf8",
                 "transcode fix_c1_controls")) {
    expect_gt(sum(grepl(part, snapshot$plan, fixed = TRUE)), 0, label = part)
  }
  # Several layers.
  expect_gt(sum(lengths(gregexpr("decode utf-8", snapshot$plan, fixed = TRUE)) > 1L), 50)

  result <- fix_encoding(snapshot$text)

  expect_reference("fix_encoding", snapshot$text, actual = result, reference = snapshot$fixed)
})

test_that("fix_encoding() differs from the snapshot only on the rows of the two utf-8-variants departures", {
  snapshot <- read_encoding_snapshot()

  rows <- departure_rows(snapshot, fix_encoding(snapshot$text))

  expect_identical(
    as.list(table(rows[rows != ""])),
    list("decoded-nul-dropped" = 3L, "utf8-variants-trailing-newline" = 4L)
  )
})

test_that("each of the four options under fix_encoding changes the repair as in the reference version", {
  snapshot <- read_encoding_snapshot()

  for (option in encoding_options) {
    reference <- snapshot[[paste0("no_", option)]]
    # The option matters: without it some texts are repaired differently.
    expect_gte(sum(reference != snapshot$fixed), 10, label = option)

    result <- do.call(fix_encoding, c(list(snapshot$text), stats::setNames(list(FALSE), option)))
    saved <- fix_encoding(snapshot$text, config = do.call(ftfy_config, stats::setNames(list(FALSE), option)))

    expect_reference("fix_encoding", snapshot$text, actual = result, reference = reference)
    expect_identical(saved, result, label = option)
  }
})

test_that("an embedded sequence is repaired with default options whatever the caller's are", {
  # Upstream's decode_inconsistent_utf8 calls fix_encoding() with no
  # config (ftfy/fixes.py:494). So with restore_byte_a0 off the string as
  # a whole is not decoded, and its sequence C3 20 is then repaired alone
  # with the option on.
  x <- "voil\u00c3 le travail"

  expect_identical(fix_encoding(x, restore_byte_a0 = FALSE), "voil\u00e0 le travail")
  expect_identical(internal_plans(x, restore_byte_a0 = FALSE), "apply decode_inconsistent_utf8")
  expect_identical(
    fix_encoding(x, restore_byte_a0 = FALSE, decode_inconsistent_utf8 = FALSE),
    x
  )
})

test_that("with fix_encoding = FALSE nothing is repaired", {
  x <- c("caf\u00c3\u00a9", "\u0085", NA, "plain")

  expect_identical(fix_encoding(x, fix_encoding = FALSE), x)
  expect_identical(internal_plans(x, fix_encoding = FALSE), c("none", "none", NA, "none"))
})

test_that("the steps recorded inside the repair are the reference version's plans", {
  snapshot <- read_encoding_snapshot()
  departs <- departure_rows(snapshot, fix_encoding(snapshot$text)) != ""

  expect_identical(internal_plans(snapshot$text)[!departs], snapshot$plan[!departs])
  for (option in encoding_options) {
    plans <- do.call(internal_plans, c(list(snapshot$text), stats::setNames(list(FALSE), option)))
    expect_identical(plans[!departs], snapshot[[paste0("plan_no_", option)]][!departs], label = option)
  }
})

test_that("a step that changed nothing is recorded, as the reference version records it", {
  # U+0081 is a hole of Windows-1252: the second pass finds the C1 pattern
  # again and leaves the text as it is.
  x <- c("\u0080\u0099 C1 with a hole \u0081", "\u0081 alone \u0081\u008d", "\ufffd\u00c3\u00a9")

  expect_identical(
    fix_encoding(x),
    c("\u20ac\u2122 C1 with a hole \u0081", "\u0081 alone \u0081\u008d", "\ufffd\u00e9")
  )
  expect_identical(
    internal_plans(x),
    c("transcode fix_c1_controls > transcode fix_c1_controls",
      "transcode fix_c1_controls",
      "encode sloppy-windows-1252 > transcode replace_lossy_sequences > decode utf-8")
  )
})

test_that("the steps recorded for the 161 JSON cases are the reference version's encoding plans", {
  cases <- read_json_cases()

  expect_identical(internal_plans(cases$original), cases$reference.fix_encoding_plan)
})

test_that("the repair returns its steps as a long table over the elements it was given", {
  x <- c("plain", NA, "s\u00c3\u00b3", "\u0085")

  repaired <- ftfy:::repair_encoding(x, ftfy_config())

  expect_identical(repaired$text, c("plain", NA, "s\u00f3", "\u2026"))
  expect_identical(
    repaired$steps,
    data.frame(
      element = c(3L, 3L, 4L, 4L),
      action = c("encode", "decode", "encode", "decode"),
      parameter = c("latin-1", "utf-8", "latin-1", "windows-1252"),
      stringsAsFactors = FALSE
    )
  )
})

test_that("one call on the whole vector gives the same texts as one call per element", {
  snapshot <- read_encoding_snapshot()
  x <- c(snapshot$text, NA, snapshot$text[1:200], NA)
  # A fixed shuffle, so that duplicates and `NA`s are not next to each other.
  x <- x[order((seq_along(x) * 7919) %% 2503, seq_along(x))]
  names(x) <- paste0("n", seq_along(x))

  whole <- fix_encoding(x)
  each <- vapply(seq_along(x), function(i) fix_encoding(x[i]), "")

  expect_identical(unname(whole), each)
  expect_identical(names(whole), names(x))
  expect_identical(is.na(whole), is.na(x))
})

test_that("fix_encoding() gives UTF-8 marked text", {
  expect_identical(
    Encoding(fix_encoding(c("caf\u00c3\u00a9", "caf\u00e9", "plain", "\u2603 \u00c3\u00a9", "\u0085"))),
    c("UTF-8", "UTF-8", "unknown", "UTF-8", "UTF-8")
  )
})

test_that("a leading U+FEFF survives every part of the repair", {
  x <- c(
    "\ufeffcaf\u00c3\u00a9", "\ufeffvoil\u00c3 le travail", "\ufeff\u2603 \u00c3\u00a9",
    "\ufeffall\u0085", "\ufeff\u0081 \u0080"
  )

  expect_identical(
    fix_encoding(x),
    c("\ufeffcaf\u00e9", "\ufeffvoil\u00e0 le travail", "\ufeff\u2603 \u00e9",
      "\ufeffall\u2026", "\ufeff\u0081 \u20ac")
  )
})
