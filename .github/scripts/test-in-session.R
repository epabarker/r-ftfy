# Runs the whole test suite from the source tree in the session the
# environment describes; used by the R-CMD-check workflow for sessions that
# R CMD check itself is not run in.
#
# FTFY_SET_LC_CTYPE, when set, is the LC_CTYPE locale to switch to first
# (on Windows, where the code page cannot be chosen from outside R).
# test-platform.R then checks FTFY_EXPECT_NATIVE from inside the tests.

locale <- Sys.getenv("FTFY_SET_LC_CTYPE")
if (nzchar(locale)) {
  cat("LC_CTYPE at start:", Sys.getlocale("LC_CTYPE"), "\n")
  set <- suppressWarnings(Sys.setlocale("LC_CTYPE", locale))
  if (!nzchar(set)) {
    stop("The locale ", locale, " could not be set in this session.")
  }
}
cat("LC_CTYPE:", Sys.getlocale("LC_CTYPE"), "\n")
str(l10n_info())

pkgload::load_all(".", quiet = TRUE)
if (isTRUE(l10n_info()[["Latin-1"]])) {
  source(file.path(".github", "scripts", "native-bytes.R"))
}
testthat::test_dir(
  file.path("tests", "testthat"),
  package = "ftfy", load_package = "none", stop_on_failure = TRUE
)
