# Measures the built tarball against the CRAN budgets of issue #14: the
# tests, run as CRAN runs them, take under 60 seconds, and the fixtures
# shipped in the tarball are under 3 MB. Run from the directory holding the
# tarball, with the package installed and NOT_CRAN not "true". Writes a
# table to the job summary and fails when a budget is exceeded.

time_budget <- 60
fixture_budget <- 3e6

tarball <- list.files(pattern = "^ftfy_.*[.]tar[.]gz$")
stopifnot(length(tarball) == 1L, !identical(Sys.getenv("NOT_CRAN"), "true"))
tarball_bytes <- file.size(tarball)

unpacked <- tempfile("unpacked")
dir.create(unpacked)
utils::untar(tarball, exdir = unpacked)
tests <- file.path(unpacked, "ftfy", "tests")

# A fixture is any file under tests/ that is not an R script.
files <- list.files(tests, recursive = TRUE, all.files = TRUE)
fixtures <- files[!grepl("[.][Rr]$", files)]
bytes <- file.size(file.path(tests, fixtures))
group <- ifelse(
  grepl("^testthat/[^/]+/", fixtures),
  sub("^(testthat/[^/]+)/.*$", "tests/\\1/", fixtures),
  "tests/ (other files)"
)
by_group <- tapply(bytes, group, sum)
fixture_bytes <- sum(bytes)
package_bytes <- sum(file.size(list.files(
  file.path(unpacked, "ftfy"),
  recursive = TRUE, all.files = TRUE, full.names = TRUE
)))

# CRAN's check runs tests/testthat.R with tests/ as the working directory.
log <- tempfile("testthat", fileext = ".Rout")
runner <- tempfile("run", fileext = ".R")
writeLines(c(
  sprintf("setwd(%s)", deparse(normalizePath(tests, winslash = "/"))),
  "source(\"testthat.R\")"
), runner)
elapsed <- system.time(
  status <- system2(
    file.path(R.home("bin"), "Rscript"), shQuote(runner),
    stdout = log, stderr = log
  )
)[["elapsed"]]
output <- readLines(log)
cat(utils::tail(output, 30L), sep = "\n")

verdict <- function(ok) if (ok) "within" else "**over**"
megabytes <- function(n) {
  sprintf("%s bytes (%.2f MB)", trimws(format(n, big.mark = ",")), n / 1e6)
}
time_ok <- status == 0L && elapsed < time_budget
fixtures_ok <- fixture_bytes < fixture_budget
summary <- c(
  "### CRAN budgets",
  "",
  "| measure | value | budget | |",
  "|---|---|---|---|",
  sprintf(
    "| test run time, as CRAN runs it (`NOT_CRAN` is `%s`) | %.1f s | under %d s | %s |",
    Sys.getenv("NOT_CRAN"), elapsed, time_budget, verdict(time_ok)
  ),
  sprintf(
    "| fixtures shipped in the tarball, uncompressed (%d files) | %s | under 3 MB | %s |",
    length(fixtures), megabytes(fixture_bytes), verdict(fixtures_ok)
  ),
  sprintf("| of which `%s` | %s | | |", names(by_group), megabytes(by_group)),
  sprintf("| the tarball `%s` | %s | | |", tarball, megabytes(tarball_bytes)),
  sprintf("| the whole package, unpacked | %s | | |", megabytes(package_bytes)),
  "",
  paste0(
    "Test result: `",
    utils::tail(grep("FAIL [0-9]+", output, value = TRUE), 1L), "`"
  ),
  "",
  sprintf("R %s, %s.", getRversion(), R.version$platform)
)
cat(summary, sep = "\n")
summary_file <- Sys.getenv("GITHUB_STEP_SUMMARY")
if (nzchar(summary_file)) {
  cat(summary, file = summary_file, sep = "\n", append = TRUE)
}

if (status != 0L) {
  stop("The tests failed when run as CRAN runs them.")
}
if (!time_ok) {
  stop(sprintf(
    "The tests took %.1f s; the budget is under %d s.", elapsed, time_budget
  ))
}
if (!fixtures_ok) {
  stop(
    "The shipped fixtures are ", megabytes(fixture_bytes),
    "; the budget is under 3 MB."
  )
}
