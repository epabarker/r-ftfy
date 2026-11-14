# The generated data of the larger corpus and of the benchmark columns:
# that R can read it with base R and stringi, and that it holds what the
# resolution of #14 asks for. The comparison of the package with the
# snapshot is not here (ticket #44). Both directories are kept out of the
# built package, so every test skips when they are absent.

skip_without_corpus <- function() {
  skip_if_not(corpus_present(), "The larger corpus, tests/corpus/, is not here.")
}

test_that("every slice has an inputs file and a snapshot, row for row", {
  skip_without_corpus()

  snapshots <- sub("[.]tsv[.]xz$", "", sort(list.files(file.path(corpus_dir(), "snapshot"))))
  expect_identical(snapshots, corpus_slices())
  expect_true("own" %in% corpus_slices())
  for (slice in corpus_slices()) {
    inputs <- read_corpus_table("inputs", slice)
    snapshot <- read_corpus_table("snapshot", slice)
    expect_identical(names(inputs), c("id", "slice", "variant", "detail", "unicode", "text"))
    expect_identical(inputs$id, as.character(seq_len(nrow(inputs))))
    expect_identical(snapshot$id, inputs$id)
    expect_true(all(inputs$slice == slice))
  }
})

test_that("the corpus is within its caps: about 50,000 inputs and 20 MB", {
  skip_without_corpus()

  files <- list.files(corpus_dir(), recursive = TRUE, full.names = TRUE)
  expect_lte(sum(file.size(files)), 20e6)
  expect_lte(nrow(read_corpus_inputs()), 50000L)
})

test_that("the inputs are distinct valid UTF-8 strings that R holds as they were written", {
  skip_without_corpus()

  raw <- do.call(rbind, lapply(corpus_slices(), function(slice) read_corpus_table("inputs", slice)))
  inputs <- read_corpus_inputs()
  expect_false(anyNA(inputs$text))
  expect_true(all(stringi::stri_enc_isutf8(inputs$text)))
  expect_false(anyDuplicated(inputs$text) > 0L)
  # Escaped again as the generator escapes, an input is the field of the
  # file: nothing was lost on the way in, a leading U+FEFF and characters
  # outside the first plane included.
  escape <- function(one) {
    cp <- utf8ToInt(one)
    plain <- cp >= 0x20L & cp <= 0x7EL & cp != 0x5CL
    out <- ifelse(cp <= 0xFFFFL, sprintf("\\u%04X", cp), sprintf("\\U%08X", cp))
    out[plain] <- rawToChar(as.raw(cp[plain]), multiple = TRUE)
    paste(out, collapse = "")
  }
  bom <- startsWith(raw$text, "\\uFEFF")
  astral <- grepl("\\U000", raw$text, fixed = TRUE)
  expect_gte(sum(bom), 5L)
  expect_gte(sum(astral), 500L)
  some <- unique(c(seq(1L, nrow(inputs), by = 23L), which(bom), utils::head(which(astral), 300L)))
  some <- some[nzchar(inputs$text[some])]
  expect_identical(vapply(inputs$text[some], escape, "", USE.NAMES = FALSE), raw$text[some])
  expect_true(all(grepl("^[ -~]*$", raw$text)))
})

test_that("our own slice has every kind of input the resolution of #14 names", {
  skip_without_corpus()

  inputs <- read_corpus_inputs("own")
  counts <- table(inputs$variant)
  least <- c(
    "json-original" = 150, "json-fixed" = 100, "json-layer" = 250, clean = 2500,
    column = 2500, "mixup-1" = 7000, "mixup-2" = 5500, "lossy-replaced" = 800,
    "lossy-question" = 350, "lossy-a0-space" = 700, "lossy-dropped" = 500,
    "lossy-c1-stripped" = 400, "decoded-nul" = 150, "fuzz-assigned" = 1800,
    "fuzz-mixed" = 1800, "fuzz-bytes" = 1800, "fuzz-markup" = 900, "fuzz-new" = 500,
    "multiline-note" = 900, "multiline-mixed" = 1800, "multiline-markup" = 450,
    "multiline-cut-short" = 350, "multiline-blank" = 10, "long-line" = 220,
    "long-lines" = 130
  )
  expect_setequal(names(counts), names(least))
  expect_true(all(counts[names(least)] >= least))
  # Room for the outside-text slice within the cap.
  expect_lte(nrow(inputs), 42000L)

  # Mix-ups between every two of the 13 codecs, but for the pairs that
  # cannot give one (see corpus_inputs.py).
  pairs <- unique(inputs$detail[inputs$variant == "mixup-1"])
  codecs <- c(
    "latin-1", "sloppy-windows-1252", "sloppy-windows-1251", "sloppy-windows-1250",
    "sloppy-windows-1253", "sloppy-windows-1254", "sloppy-windows-1257", "iso-8859-2",
    "macroman", "cp437", "windows-1252", "utf-8", "utf-8-variants"
  )
  expect_true(all(unlist(strsplit(pairs, ">", fixed = TRUE)) %in% codecs))
  expect_gte(length(pairs), 130L)
  expect_true(all(unlist(strsplit(inputs$detail[inputs$variant == "mixup-2"], ">", fixed = TRUE)) %in% codecs))

  # Strings of several lines, and lines longer than the small values of
  # max_decode_length that the snapshot uses.
  lines <- strsplit(inputs$text, "\n", fixed = TRUE)
  expect_gte(sum(grepl("\n", inputs$text, fixed = TRUE)), 4000L)
  expect_gte(sum(vapply(lines, function(one) any(nchar(one) > 60L), NA)), 4000L)
  expect_gte(sum(nchar(inputs$text) > 1000L), 200L)
})

# The outside-text slice (ticket #45): natural-language text from outside
# sources under the licence rule of the resolution of #15, selected by
# data-raw/outside/select.py and committed in data-raw/outside/, from which
# corpus_inputs_outside.py builds the inputs. Its `detail` is
# "<source> <language> <kind>", then ", <codecs>" for a mix-up.

outside_dir <- function() {
  test_path("..", "..", "data-raw", "outside")
}

test_that("the outside-text slice is there beside our own slice, with every variant of variants.tsv", {
  skip_without_corpus()
  skip_if_not(dir.exists(outside_dir()), "data-raw/outside/ is not here.")

  # The cap over every slice together is checked above.
  expect_identical(corpus_slices(), c("outside", "own"))
  inputs <- read_corpus_inputs("outside")
  expect_gte(nrow(inputs), 5000L)
  # The variants and the fewest rows of each: corpus_inputs_outside.py
  # reads the same file and stops when a variant has fewer.
  variants <- utils::read.delim(file.path(outside_dir(), "variants.tsv"), colClasses = "character")
  expect_identical(names(variants), c("variant", "least", "what"))
  least <- stats::setNames(as.integer(variants$least), variants$variant)
  expect_false(anyNA(least))
  counts <- table(inputs$variant)
  expect_setequal(names(counts), names(least))
  expect_true(all(counts[names(least)] >= least))
  expect_true(all(grepl("^[a-z]+ [a-z]{2,3} [a-z-]+(, [a-z0-9>-]+)?$", inputs$detail)))
  # Free text of several lines is there, as the sources wrote it.
  expect_gte(sum(grepl("\n", inputs$text, fixed = TRUE)), 100L)
})

test_that("every source of the outside-text slice is listed in SOURCES with its licence and attribution", {
  skip_without_corpus()
  skip_if_not(dir.exists(outside_dir()), "data-raw/outside/ is not here.")

  sources <- read.dcf(file.path(outside_dir(), "SOURCES"))
  expect_true(all(c("Id", "Name", "Version", "Licence", "Attribution", "Files") %in% colnames(sources)))
  expect_false(anyNA(sources[, c("Id", "Name", "Version", "Licence", "Attribution")]))
  # Only licences the rule of the resolution of #15 accepts, by its
  # categories: "public domain, CC0, MIT/BSD-style, attribution-only
  # (CC-BY, OGL, Unicode licence)". Share-alike, non-commercial,
  # no-derivatives and no-redistribution licences are excluded. A licence
  # is named by its SPDX id, but for public domain, which has none.
  accepted <- c(
    "public domain",
    "CC0-1.0",
    "MIT", "BSD-2-Clause", "BSD-3-Clause",
    "CC-BY-4.0", "OGL-UK-3.0", "Unicode-3.0"
  )
  expect_true(all(sources[, "Licence"] %in% accepted))
  used <- unique(sub(" .*$", "", read_corpus_inputs("outside")$detail))
  expect_setequal(used, sources[, "Id"])
  # Every file the selection downloads is pinned with a checksum.
  pins <- utils::read.delim(file.path(outside_dir(), "pins.tsv"), colClasses = "character")
  expect_identical(names(pins), c("source", "url", "sha256"))
  expect_true(all(grepl("^[0-9a-f]{64}$", pins$sha256)))
  expect_setequal(unique(pins$source), sources[, "Id"])
  expect_true(all(grepl("^https://", pins$url)))
  expect_false(anyDuplicated(pins$url) > 0L)
})

test_that("the outside-text slice covers the languages of the resolution of #15, each through its own codec", {
  skip_without_corpus()

  inputs <- read_corpus_inputs("outside")
  language <- sub("^[a-z]+ ([a-z]+) .*$", "\\1", inputs$detail)
  clean <- inputs$variant == "clean"
  # Western European, Central European, Russian or Ukrainian, Greek,
  # Turkish; and CJK, Arabic, Hebrew and emoji as clean controls.
  for (lang in c("fr", "de", "es", "pl", "cs", "hu", "ru", "uk", "el", "tr", "ja", "zh", "ko", "ar", "he")) {
    expect_gte(sum(clean & language == lang), 30L, label = lang)
  }
  expect_gte(sum(clean & grepl(" emoji$", inputs$detail)), 50L)
  mixed_through <- function(lang, codec) {
    sum(inputs$variant == "mixup-1" & language == lang & endsWith(inputs$detail, paste0("utf-8>", codec)))
  }
  expect_gte(mixed_through("fr", "sloppy-windows-1252"), 20L)
  expect_gte(mixed_through("de", "latin-1"), 20L)
  expect_gte(mixed_through("pl", "sloppy-windows-1250"), 20L)
  expect_gte(mixed_through("cs", "iso-8859-2"), 20L)
  expect_gte(mixed_through("ru", "sloppy-windows-1251"), 20L)
  expect_gte(mixed_through("uk", "sloppy-windows-1251"), 20L)
  expect_gte(mixed_through("el", "sloppy-windows-1253"), 20L)
  expect_gte(mixed_through("tr", "sloppy-windows-1254"), 20L)
  # Every value of the slice is outside text: it holds a letter beyond
  # ASCII, or it is an emoji.
  expect_true(all(grepl("[^\\x01-\\x7F]", inputs$text, perl = TRUE)))
})

test_that("every row is tagged with a Unicode version, and the tags tell rows apart", {
  skip_without_corpus()

  inputs <- read_corpus_inputs()
  snapshot <- read_corpus_snapshot()
  version <- "^[0-9]+[.][0-9]+$"
  expect_true(all(grepl(version, inputs$unicode)))
  expect_true(all(grepl(version, snapshot$unicode) | snapshot$unicode == "unassigned"))
  # The snapshot's tag also covers the outputs, so it is never older.
  known <- snapshot$unicode != "unassigned"
  expect_true(all(numeric_version(snapshot$unicode[known]) >= numeric_version(inputs$unicode[known])))
  expect_true(any(numeric_version(snapshot$unicode[known]) > numeric_version(inputs$unicode[known])))
  expect_true(all(c("1.1", "11.0", "12.0", "13.0", "14.0", "15.0", "15.1") %in% snapshot$unicode))

  expect_identical(
    corpus_comparable(c("1.1", "10.0", "14.0", "15.0", "15.1", "unassigned"), icu = "14.0"),
    c(TRUE, TRUE, TRUE, FALSE, FALSE, FALSE)
  )
  # A tag is the truth about the input, as far as the running ICU can say:
  # an input holds a character the ICU does not know exactly when its tag
  # is newer than the ICU. (A noncharacter is unassigned to ICU's general
  # category and has an age all the same.)
  icu <- stringi::stri_info()$Unicode.version
  newer <- numeric_version(inputs$unicode) > numeric_version(icu)
  unknown <- "[[\\p{Cn}]-[\\p{Noncharacter_Code_Point}]]"
  expect_identical(stringi::stri_detect_charclass(inputs$text, unknown), newer)
})

test_that("the snapshot has every column of the scope, and every cell reads", {
  skip_without_corpus()

  inputs <- read_corpus_inputs()
  snapshot <- read_corpus_snapshot()
  fixers <- c(
    "unescape_html", "remove_terminal_escapes", "uncurl_quotes", "fix_latin_ligatures",
    "fix_character_width", "fix_line_breaks", "remove_control_chars",
    "decode_inconsistent_utf8", "fix_c1_controls"
  )
  variants <- names(corpus_variants())
  expect_length(variants, 15L)
  sub_options <- encoding_sub_options
  explaining <- c("fix_and_explain", "fix_encoding_and_explain")
  text_columns <- c(
    paste0("fixer.", fixers),
    paste0("fix_text.", c(variants, "max_decode_length_10", "max_decode_length_60")),
    paste0("fix_text.keyword_no_", sub_options),
    paste0(rep(explaining, each = length(variants)), ".", variants),
    paste0("apply_plan.", explaining)
  )
  plan_columns <- paste0(rep(explaining, each = length(variants)), ".", variants, ".plan")
  expect_setequal(names(snapshot), c("id", "unicode", "badness", "is_bad", text_columns, plan_columns))

  expect_true(all(grepl("^(0|[1-9][0-9]*)$", snapshot$badness)))
  expect_true(all(snapshot$is_bad %in% c("TRUE", "FALSE")))
  expect_identical(snapshot$is_bad == "TRUE", as.integer(snapshot$badness) > 0L)

  raised <- 0L
  for (column in text_columns) {
    reference <- corpus_text(snapshot, inputs, column)
    expect_false(anyNA(reference$text[is.na(reference$error)]), info = column)
    raised <- raised + sum(!is.na(reference$error))
    if (!startsWith(column, "apply_plan.")) {
      expect_true(all(is.na(reference$error)), info = column)
    }
  }
  # Replaying a plan with a `normalize` step is the one thing the reference
  # version raises on here.
  replay <- corpus_text(snapshot, inputs, "apply_plan.fix_and_explain")
  expect_gte(sum(!is.na(replay$error)), 100L)
  expect_identical(unique(stats::na.omit(replay$error)), "ValueError: Unknown plan step: normalize")
  expect_identical(
    !is.na(replay$error),
    grepl("normalize", corpus_plan(snapshot, "fix_and_explain"), fixed = TRUE)
  )
  expect_identical(raised, sum(!is.na(replay$error)))

  step <- "(encode|decode|transcode|apply|normalize) [A-Za-z0-9_-]+"
  for (fun in explaining) {
    for (variant in variants) {
      plan <- corpus_plan(snapshot, fun, variant)
      expect_true(all(grepl(paste0("^(none|", step, "( > ", step, ")*)$"), plan)), info = paste(fun, variant))
    }
  }
  # Results that hold U+0000 are there, and stay escaped.
  fixed <- corpus_text(snapshot, inputs, "fix_text.no_remove_control_chars")$text
  expect_gte(sum(grepl("\\u0000", fixed, fixed = TRUE)), 50L)
})

test_that("the committed benchmark columns are what their list says", {
  directory <- test_path("..", "..", "bench", "columns")
  skip_if_not(dir.exists(directory), "The benchmark columns, bench/columns/, are not here.")

  columns <- utils::read.delim(file.path(directory, "columns.tsv"), stringsAsFactors = FALSE)
  expect_identical(
    columns$column,
    c("names_n1e4", "names_n1e5", "names_n1e6", "names_clean100_u20", "names_clean50_u20",
      "names_clean95_u1", "names_clean95_u100", "ascii_n1e5", "notes_n1e4")
  )
  expect_setequal(list.files(directory), c("columns.tsv", paste0(columns$column, ".txt.xz")))
  for (i in seq_len(nrow(columns))) {
    path <- file.path(directory, paste0(columns$column[[i]], ".txt.xz"))
    connection <- xzfile(path, open = "rt")
    lines <- readLines(connection)
    close(connection)
    values <- stringi::stri_unescape_unicode(lines)
    expect_length(values, columns$distinct[[i]])
    expect_false(anyDuplicated(values) > 0L)
    expect_true(all(stringi::stri_enc_isutf8(values)))
    expect_identical(sum(nchar(values)), columns$characters[[i]], info = columns$column[[i]])
    expect_length(rep_len(values, columns$n[[i]]), columns$n[[i]])
  }
  notes <- columns$column == "notes_n1e4"
  expect_gt(columns$characters[notes] / columns$distinct[notes], 200)
})
