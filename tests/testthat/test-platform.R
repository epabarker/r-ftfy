# What the package does with unmarked strings in each native encoding, and
# whether this session is the one its CI job says it is (issue #43).
#
# helper-entry-step.R already checks, for every export, that an unmarked
# string of characters from U+00A0 up is read in the native encoding. The
# tests here cover the rest of what the entry step does with unmarked
# strings. Each one runs in the sessions it applies to and is skipped in
# the others; the check matrix runs the suite in each: UTF-8 (every
# default job), Latin-1 on Ubuntu, code page 1252 on Windows, and the C
# locale.
#
# Three of the behaviours asserted below were MEASURED, NOT DECIDED (the
# notes of tickets #31 and #43): they are what base R's `enc2utf8()` does,
# and no issue or ADR says the package should behave so. They are asserted
# so that a platform or an R version on which base R does otherwise is
# seen, not to fix them as the intended behaviour. They are marked
# "measured" in the test names.

# An unmarked string made of the given bytes. Built from raw bytes because
# the parser marks "\xe9" as latin1 in a Latin-1 session.
unmarked <- function(...) {
  x <- rawToChar(as.raw(c(...)))
  stopifnot(identical(Encoding(x), "unknown"))
  x
}

# Each registered export as `function(x)` giving the vector parallel to `x`.
platform_runs <- function() {
  registrations <- entry_step_registrations()
  registrations <- registrations[
    !vapply(registrations, function(r) !is.null(r$exempt), logical(1L))
  ]
  lapply(registrations, function(registration) {
    take <- if (is.null(registration$value)) identity else registration$value
    function(x) take(registration$call(x))
  })
}

# The native encoding as this file tells sessions apart.
platform_native <- function() {
  l10n <- l10n_info()
  if (isTRUE(l10n[["UTF-8"]])) {
    "UTF-8"
  } else if (isTRUE(l10n[["Latin-1"]])) {
    "Latin-1"
  } else if (Sys.getlocale("LC_CTYPE") %in% c("C", "POSIX")) {
    "C"
  } else {
    "other"
  }
}

# Windows-1252 at bytes 80 to 9F: the 27 characters it assigns, in byte
# order, and its five holes.
cp1252_holes <- c(0x81, 0x8d, 0x8f, 0x90, 0x9d)
cp1252_assigned_bytes <- setdiff(0x80:0x9f, cp1252_holes)
cp1252_assigned_text <- c(
  "\u20ac", "\u201a", "\u0192", "\u201e", "\u2026", "\u2020", "\u2021",
  "\u02c6", "\u2030", "\u0160", "\u2039", "\u0152", "\u017d", "\u2018",
  "\u2019", "\u201c", "\u201d", "\u2022", "\u2013", "\u2014", "\u02dc",
  "\u2122", "\u0161", "\u203a", "\u0153", "\u017e", "\u0178"
)

test_that("the session is the one its CI job says it is", {
  l10n <- l10n_info()
  icu <- stringi::stri_info()
  lines <- c(
    paste0("R: ", R.version.string),
    paste0("platform: ", R.version$platform),
    paste0("LC_CTYPE: ", Sys.getlocale("LC_CTYPE")),
    paste0("l10n_info: ", paste0(names(l10n), "=", unlist(l10n), collapse = ", ")),
    paste0("native: ", platform_native()),
    paste0("stringi: ", as.character(utils::packageVersion("stringi"))),
    paste0("ICU.version: ", icu$ICU.version),
    paste0("ICU.system: ", icu$ICU.system),
    paste0("Unicode.version: ", icu$Unicode.version),
    paste0("stringi native charset: ", icu$Charset.native$Name.friendly),
    paste0("NOT_CRAN: ", Sys.getenv("NOT_CRAN"))
  )
  # A CI job names a file, and fails afterwards if the file is not there:
  # that is its evidence that the tests ran in the session described.
  report <- Sys.getenv("FTFY_PLATFORM_REPORT")
  if (nzchar(report)) {
    writeLines(lines, report)
  }

  expected_native <- Sys.getenv("FTFY_EXPECT_NATIVE")
  expected_icu <- Sys.getenv("FTFY_EXPECT_ICU")
  expected_version <- Sys.getenv("FTFY_EXPECT_ICU_VERSION")
  if (!nzchar(expected_native) && !nzchar(expected_icu)) {
    skip("No CI job has said which session this is.")
  }
  if (nzchar(expected_native)) {
    expect_identical(platform_native(), expected_native)
    if (.Platform$OS.type == "windows") {
      expect_identical(
        l10n[["codepage"]],
        switch(expected_native, `UTF-8` = 65001L, `Latin-1` = 1252L, NA_integer_)
      )
    }
  }
  if (nzchar(expected_icu)) {
    expect_true(expected_icu %in% c("bundled", "system"))
    expect_identical(icu$ICU.system, expected_icu == "system")
  }
  if (nzchar(expected_version)) {
    expect_identical(icu$ICU.version, expected_version)
  }
})

test_that("in a UTF-8 session an unmarked string is read as UTF-8", {
  skip_if_not(platform_native() == "UTF-8", "The native encoding is not UTF-8.")
  # U+00E9; U+0080 and U+009F (C1 controls); U+20AC; U+1F600.
  x <- c(
    unmarked(0x63, 0x61, 0x66, 0xc3, 0xa9),
    unmarked(0xc2, 0x80, 0x20, 0xc2, 0x9f),
    unmarked(0xe2, 0x82, 0xac),
    unmarked(0xf0, 0x9f, 0x98, 0x80)
  )
  as_text <- c("caf\u00e9", "\u0080 \u009f", "\u20ac", "\U0001f600")
  expect_identical(Encoding(x), rep("unknown", 4L))

  runs <- platform_runs()
  for (export in names(runs)) {
    expect_identical(runs[[export]](x), runs[[export]](as_text), info = export)
  }
})

test_that("in a UTF-8 session unmarked bytes that are not UTF-8 are an error, not Latin-1", {
  skip_if_not(platform_native() == "UTF-8", "The native encoding is not UTF-8.")
  x <- c("plain", unmarked(0x63, 0x61, 0x66, 0xe9), unmarked(0x80))
  expect_identical(Encoding(x), rep("unknown", 3L))

  runs <- platform_runs()
  for (export in names(runs)) {
    expect_error(runs[[export]](x), "invalid UTF-8", info = export)
    expect_error(runs[[export]](x), "2 of 3", info = export)
  }
})

test_that("in a Latin-1 session every unmarked byte from A0 to FF is read as U+00A0 to U+00FF", {
  skip_if_not(platform_native() == "Latin-1", "The native encoding is not Latin-1.")
  bytes <- 0xa0:0xff
  x <- vapply(bytes, function(byte) unmarked(0x61, byte, 0x62), "")
  as_text <- paste0("a", intToUtf8(bytes, multiple = TRUE), "b")
  expect_identical(Encoding(x), rep("unknown", length(x)))
  expect_identical(Encoding(as_text), rep("UTF-8", length(x)))

  runs <- platform_runs()
  for (export in names(runs)) {
    expect_identical(runs[[export]](x), runs[[export]](as_text), info = export)
  }
})

test_that("in a Latin-1 session an unmarked UTF-8 sequence is read byte by byte (mojibake is made, as base R does)", {
  skip_if_not(platform_native() == "Latin-1", "The native encoding is not Latin-1.")
  x <- unmarked(0x63, 0x61, 0x66, 0xc3, 0xa9)

  runs <- platform_runs()
  for (export in names(runs)) {
    expect_identical(runs[[export]](x), runs[[export]]("caf\u00c3\u00a9"), info = export)
  }
})

test_that("measured: in a Latin-1 session unmarked bytes 80 to 9F are read as Windows-1252, unlike the latin1 mark", {
  skip_if_not(platform_native() == "Latin-1", "The native encoding is not Latin-1.")
  x <- vapply(cp1252_assigned_bytes, function(byte) unmarked(0x61, byte, 0x62), "")
  as_text <- paste0("a", cp1252_assigned_text, "b")

  runs <- platform_runs()
  for (export in names(runs)) {
    expect_identical(runs[[export]](x), runs[[export]](as_text), info = export)
  }

  # The same bytes with the latin1 mark are U+0080 to U+009F (ADR 0006).
  marked <- x
  Encoding(marked) <- "latin1"
  as_c1 <- paste0("a", intToUtf8(cp1252_assigned_bytes, multiple = TRUE), "b")
  expect_identical(fix_c1_controls(marked), fix_c1_controls(as_c1))
})

test_that("measured: in a Latin-1 session an unmarked hole of Windows-1252 becomes the text <81>, or on Windows U+0081", {
  skip_if_not(platform_native() == "Latin-1", "The native encoding is not Latin-1.")
  x <- vapply(cp1252_holes, function(byte) unmarked(0x61, byte, 0x62), "")
  # Base R differs by platform here (run 43533766534 of the check matrix).
  # With code page 1252 on Windows, `enc2utf8()` gives the C1 control of
  # the same number, as Windows' own conversion does. On Linux and macOS
  # the conversion refuses the byte and R writes it out as ASCII text.
  as_text <- if (.Platform$OS.type == "windows") {
    paste0("a", intToUtf8(cp1252_holes, multiple = TRUE), "b")
  } else {
    sprintf("a<%02x>b", cp1252_holes)
  }

  runs <- platform_runs()
  for (export in names(runs)) {
    expect_identical(runs[[export]](x), runs[[export]](as_text), info = export)
  }
})

test_that("measured: in the C locale an unmarked non-ASCII byte becomes text such as <e9>, with no error", {
  skip_if_not(platform_native() == "C", "The session is not in the C locale.")
  x <- c(unmarked(0x63, 0x61, 0x66, 0xe9), unmarked(0x80, 0x20, 0xff))
  as_text <- c("caf<e9>", "<80> <ff>")

  runs <- platform_runs()
  for (export in names(runs)) {
    expect_identical(runs[[export]](x), runs[[export]](as_text), info = export)
  }
})
