# Derived from python-ftfy v6.3.1, ftfy/. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# `patterns`: a named character vector of ICU patterns, one for each file in
# data-raw/patterns/, named after the file (BADNESS_RE.txt gives
# patterns[["BADNESS_RE"]]). A generator that writes a new file there needs
# no change here.
.files <- sort(list.files("data-raw/patterns", pattern = "[.]txt$", full.names = TRUE))
.read <- function(path) {
  lines <- readLines(path, encoding = "UTF-8", warn = TRUE)
  if (length(lines) != 1L || !stringi::stri_enc_isascii(lines)) {
    stop(path, " must hold one ASCII line")
  }
  lines
}
patterns <- vapply(.files, .read, "", USE.NAMES = FALSE)
names(patterns) <- sub("[.]txt$", "", basename(.files))
