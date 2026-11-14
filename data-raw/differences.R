# The "differences from Python ftfy" help page, written from the departure
# registry. data-raw/build.R sources this file and writes what
# `differences_page()` returns to R/differences.R, from which roxygen2
# makes man/ftfy-differences.Rd. Nothing lists the entries: every file
# inst/departures/<id>.dcf becomes one section of the page, in id order.
#
# The page is never edited by hand. To change what it says about a
# departure, edit the registry entry and run `Rscript data-raw/build.R`.
# `Rscript data-raw/build.R --check` and tests/testthat/test-differences.R
# fail when the page and the registry disagree.
#
# This file carries no derived-file header because it holds nothing taken
# from python-ftfy.

differences_file <- "R/differences.R"

# The fields of an entry that the page shows, with the label of each.
differences_fields <- c(
  Input = "Input",
  Reference = "Reference version",
  R = "This package"
)

# Text as it must be written in an Rd file to be read back unchanged.
rd_escape <- function(text) {
  text <- gsub("\\", "\\\\", text, fixed = TRUE)
  text <- gsub("%", "\\%", text, fixed = TRUE)
  text <- gsub("{", "\\{", text, fixed = TRUE)
  gsub("}", "\\}", text, fixed = TRUE)
}

one_line <- function(text) {
  trimws(gsub("[[:space:]]+", " ", text))
}

# Where a departure was decided, as Rd: a link to the issue comment, or to
# the ADR in the repository named by the URL field of DESCRIPTION.
decided_rd <- function(decided, repository) {
  decided <- one_line(decided)
  if (grepl("^https://", decided)) {
    return(paste0("\\url{", decided, "}"))
  }
  number <- sub("^docs/adr/([0-9]{4})-.*$", "\\1", decided)
  if (identical(number, decided)) {
    stop("cannot tell where this was decided: ", decided)
  }
  paste0("ADR ", number, ", \\href{", repository, "/blob/main/", decided, "}{",
         rd_escape(decided), "}")
}

read_registry <- function(dir) {
  files <- sort(list.files(dir, pattern = "[.]dcf$", full.names = TRUE), method = "radix")
  if (length(files) == 0L) {
    stop("no registry entry found in ", dir)
  }
  lapply(files, function(path) {
    entry <- read.dcf(path, all = TRUE)
    needed <- c("Id", "Title", names(differences_fields), "Decided")
    if (nrow(entry) != 1L || !all(needed %in% names(entry))) {
      stop(path, " must hold one entry with the fields ", paste(needed, collapse = ", "))
    }
    lapply(entry[needed], function(field) one_line(as.character(field)))
  })
}

# The lines of R/differences.R: one roxygen block, holding the page.
differences_page <- function(dir = "inst/departures", description = "DESCRIPTION") {
  entries <- read_registry(dir)
  package <- read.dcf(description, fields = c("URL", "Config/ftfy/upstream"))
  repository <- package[1L, "URL"]
  upstream <- package[1L, "Config/ftfy/upstream"]
  if (anyNA(c(repository, upstream))) {
    stop(description, " must have the fields URL and Config/ftfy/upstream")
  }

  wrap <- function(text) strwrap(text, width = 72L)
  sections <- unlist(lapply(entries, function(entry) {
    fields <- unlist(lapply(names(differences_fields), function(field) {
      c(paste0("\\item{", differences_fields[[field]], "}{"),
        wrap(rd_escape(entry[[field]])),
        "}")
    }))
    c(paste0("@rawRd \\section{", rd_escape(entry$Title), "}{"),
      "\\describe{",
      fields,
      "\\item{Decided in}{",
      paste0(decided_rd(entry$Decided, repository), "."),
      "}",
      "\\item{Registry entry}{",
      paste0("\\code{", rd_escape(entry$Id), "}"),
      "}",
      "}",
      "}")
  }))

  body <- c(
    "Differences from Python ftfy",
    "",
    wrap(paste0(
      "The package aims to return what the reference version returns: ",
      "Python ftfy ", upstream, " run on Python 3.13. A departure is a ",
      "place where it deliberately does something else, because R cannot ",
      "do what the reference version does or because what the reference ",
      "version does damages text. Every departure is recorded in the ",
      "departure registry, and this page lists all ", length(entries),
      " of them. Each has the input that shows it, what the reference ",
      "version returns, and what this package returns or the error it ",
      "raises."
    )),
    "",
    "@details",
    wrap(paste0(
      "In the examples a string is written as Python and R both write it ",
      "in source: `\\u00e9` is the character U+00E9. An output of the ",
      "reference version is shown as Python prints it, so `\\xe9` is ",
      "that same character there."
    )),
    "",
    wrap(paste0(
      "A departure is on whatever the options, and no option brings the ",
      "reference version's result back. Anything else that differs from ",
      "the reference version is a bug in this package: please report it."
    )),
    "",
    wrap(paste0(
      "The registry is installed with the package, one file for each ",
      "entry, in the directory ",
      "`system.file(\"departures\", package = \"ftfy\")`. This page is ",
      "written from those files and is never edited by hand."
    )),
    "",
    wrap(paste0(
      "Parts of Python ftfy that this package does not have are not ",
      "departures and are not listed here: see [ftfy][ftfy-package] for ",
      "what is absent, [ftfy_config()] for the options that are not ",
      "taken, and [apply_plan()] for what a failed replay is."
    )),
    "",
    "@name ftfy-differences",
    "@aliases differences departures",
    sections
  )
  if (any(grepl("@", unlist(entries), fixed = TRUE))) {
    stop("a registry field holds `@`, which roxygen2 could read as a tag")
  }

  c("# Generated by data-raw/build.R from inst/departures/: do not edit by hand.",
    "# To change the page, edit a registry entry and run `Rscript data-raw/build.R`.",
    "",
    sub("[[:space:]]+$", "", paste("#'", body)),
    "NULL")
}

# Is the committed page what the registry gives?
differences_current <- function(path = differences_file, ...) {
  file.exists(path) && identical(readLines(path, warn = FALSE), differences_page(...))
}

# Written with LF line ends on every platform.
write_differences <- function(path = differences_file, ...) {
  con <- file(path, open = "wb")
  on.exit(close(con))
  writeLines(differences_page(...), con, sep = "\n")
}
