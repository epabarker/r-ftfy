# Runs the corpus comparison, tests/testthat/test-corpus.R, from the source
# tree (ticket #44; the corpus is not in the tarball R CMD check runs on).
# Used by the corpus jobs of the R-CMD-check workflow, in the session the
# job sets up; run from the package root.
#
# FTFY_CORPUS_MISMATCHES names the CSV the mismatches are written to; the
# job uploads it. The script fails when a test fails, when the CSV was not
# written, or when any test skipped other than the one that says how many
# rows are newer than the running ICU: FTFY_CORPUS_COMPARISON is set to
# "required" here, so a missing corpus is a failure too.

Sys.setenv(FTFY_CORPUS_COMPARISON = "required")
mismatches <- Sys.getenv("FTFY_CORPUS_MISMATCHES")
if (!nzchar(mismatches)) {
  stop("FTFY_CORPUS_MISMATCHES must name the CSV file to write.")
}
unlink(mismatches)

cat("LC_CTYPE:", Sys.getlocale("LC_CTYPE"), "\n")
str(l10n_info())
str(stringi::stri_info()[c("ICU.version", "ICU.system", "Unicode.version")])

started <- Sys.time()
pkgload::load_all(".", quiet = TRUE)
results <- as.data.frame(testthat::test_file(
  file.path("tests", "testthat", "test-corpus.R"),
  package = "ftfy", load_package = "none", stop_on_failure = FALSE
))
minutes <- as.numeric(difftime(Sys.time(), started, units = "mins"))

unicode_test <- "rows tagged with a Unicode version newer than the running ICU's are not compared"
skipped <- results$test[results$skipped & results$test != unicode_test]
failed <- results$test[results$failed > 0L | results$error]
written <- file.exists(mismatches)
lines <- if (written) length(readLines(mismatches, warn = FALSE)) - 1L else NA_integer_

info <- stringi::stri_info()
# The rows compared and not compared, from the Unicode tags of the snapshot.
tags <- unlist(lapply(
  sort(list.files(file.path("tests", "corpus", "snapshot"), pattern = "[.]tsv[.]xz$", full.names = TRUE)),
  function(path) {
    utils::read.delim(
      xzfile(path), quote = "", colClasses = "character", na.strings = character(0),
      comment.char = "", check.names = FALSE
    )$unicode
  }
))
unassigned <- tags == "unassigned"
newer <- !unassigned
newer[newer] <- numeric_version(tags[newer]) > numeric_version(info$Unicode.version)
summary <- c(
  "### Corpus comparison",
  "",
  "| measure | value |",
  "|---|---|",
  sprintf("| session | %s, %s |", Sys.getlocale("LC_CTYPE"), l10n_info()$codeset),
  sprintf("| ICU | %s (Unicode %s) |", info$ICU.version, info$Unicode.version),
  sprintf("| rows compared | %d of %d |", sum(!unassigned & !newer), length(tags)),
  sprintf("| rows not compared: tagged newer than this ICU's Unicode | %d |", sum(newer)),
  sprintf("| rows not compared: a result holds a code point Unicode 15.1 has not assigned | %d |", sum(unassigned)),
  sprintf("| tests | %d, of which %d failed and %d skipped |", nrow(results), length(failed), sum(results$skipped)),
  sprintf("| mismatches written to the CSV | %s |", if (written) lines else "**no CSV**"),
  sprintf("| minutes, from loading the package to the end | %.1f |", minutes),
  ""
)
cat(summary, sep = "\n")
step_summary <- Sys.getenv("GITHUB_STEP_SUMMARY")
if (nzchar(step_summary)) {
  cat(summary, sep = "\n", file = step_summary, append = TRUE)
}

problems <- c(
  if (length(failed) > 0L) paste("failed:", paste(failed, collapse = "; ")),
  if (length(skipped) > 0L) paste("skipped:", paste(skipped, collapse = "; ")),
  if (!written) paste("the CSV", mismatches, "was not written")
)
if (length(problems) > 0L) {
  stop("The corpus comparison did not pass.\n", paste(problems, collapse = "\n"))
}
