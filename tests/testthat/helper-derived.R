# The derived-file header (ADR 0012, resolution of #17), and the check that
# every script either starts with it or is listed in not-derived.txt.
#
# The rule: a script that holds anything translated, copied or adapted from
# python-ftfy starts with the header as its first line. A script that holds
# nothing from upstream is listed in tests/testthat/not-derived.txt with the
# reason. Generator scripts always carry the header and cannot be listed.

# One upstream path, relative to the root of python-ftfy: a file or a
# directory (`ftfy/badness.py`, `tests/test_characters.py`, `ftfy/`).
derived_header_pattern <- local({
  path <- "[A-Za-z0-9_][A-Za-z0-9_./-]*"
  paste0(
    "^# Derived from python-ftfy v6[.]3[.]1, ",
    path, "(?:(?:, | and )", path, ")*",
    "[.] Copyright 2023 Robyn Speer[.] Apache-2[.]0[.] ",
    "Translated to R and modified; see inst/COPYRIGHTS[.]$"
  )
})

is_derived_header <- function(line) {
  !is.na(line) & grepl(derived_header_pattern, line, perl = TRUE)
}

# Whether `root` is the package's source tree, with R/ and data-raw/. The
# tests of an installed package, and of R CMD check, have neither.
is_source_tree <- function(root) {
  all(dir.exists(file.path(root, c("R", "data-raw", "tests"))))
}

# The scripts the rule covers, as paths from the package root. `scope` is
# "all" for a source tree or "tests" for the files under tests/ only.
derived_header_files <- function(root, scope = c("all", "tests")) {
  scope <- match.arg(scope)
  under <- function(dir, pattern, recursive = TRUE) {
    found <- list.files(file.path(root, dir), pattern = pattern, recursive = recursive)
    if (length(found) > 0L) file.path(dir, found) else character()
  }
  files <- under("tests", "[.][Rr]$")
  if (scope == "all") {
    files <- c(under("R", "[.][Rr]$", recursive = FALSE), files, under("data-raw", "[.]([Rr]|py)$"))
  }
  sort(files, method = "radix")
}

# Generator scripts: these always carry the header.
is_generator_script <- function(file) {
  grepl("^data-raw/generators/[^/]+[.]py$", file) |
    file == "data-raw/regenerate.py" |
    grepl("^data-raw/sysdata/[^/]+[.][Rr]$", file)
}

# The list of scripts that are not derived: one line each, the path from the
# package root, a tab, and the reason. Blank lines and lines starting with
# `#` are skipped. The order is free, so that branches can each append.
read_not_derived <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  lines <- lines[nzchar(trimws(lines)) & !startsWith(lines, "#")]
  file <- sub("\t.*$", "", lines)
  reason <- trimws(ifelse(grepl("\t", lines, fixed = TRUE), sub("^[^\t]*\t", "", lines), ""))
  if (any(!nzchar(reason))) {
    stop("not-derived.txt: no reason given for ", paste(file[!nzchar(reason)], collapse = ", "),
         ". Each line is a path, a tab and the reason.")
  }
  if (anyDuplicated(file) > 0L) {
    stop("not-derived.txt: listed twice: ", paste(unique(file[duplicated(file)]), collapse = ", "), ".")
  }
  data.frame(file = file, reason = reason)
}

# Every breach of the rule under `root`, one string each, starting with the
# path. An empty vector when the rule holds.
derived_header_problems <- function(root, not_derived, scope = c("all", "tests")) {
  scope <- match.arg(scope)
  files <- derived_header_files(root, scope)
  first <- vapply(
    file.path(root, files),
    function(path) {
      line <- readLines(path, n = 1L, warn = FALSE)
      if (length(line) == 0L) NA_character_ else line
    },
    character(1),
    USE.NAMES = FALSE
  )
  headed <- is_derived_header(first)
  listed <- files %in% not_derived$file
  generator <- is_generator_script(files)

  # Under "tests" a listed file outside tests/ cannot be looked for.
  expected <- if (scope == "tests") {
    not_derived$file[startsWith(not_derived$file, "tests/")]
  } else {
    not_derived$file
  }
  gone <- setdiff(expected, files)

  # paste0() gives one string for an empty vector, so say() guards it.
  say <- function(file, what) if (length(file) > 0L) paste0(file, ": ", what) else character()
  c(
    say(files[generator & !headed], "a generator script must start with the derived-file header"),
    say(files[generator & listed], "a generator script cannot be listed in not-derived.txt"),
    say(
      files[!generator & !headed & !listed],
      "line 1 is not the derived-file header, and the file is not listed in not-derived.txt"
    ),
    say(
      files[!generator & headed & listed],
      "has the derived-file header and is listed in not-derived.txt, both"
    ),
    say(gone, "listed in not-derived.txt, but no such file")
  )
}
