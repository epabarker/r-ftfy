# Derived from python-ftfy v6.3.1, ftfy/bad_codecs/sloppy.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# `codec_tables`: a named list with one entry for each file in
# data-raw/codecs/, named after the file (latin-1.txt gives
# codec_tables[["latin-1"]]). Each entry is an integer vector of 256 code
# points, where element b + 1 is what byte b decodes to and a hole is `NA`.
# A generator that writes a new file there needs no change here.
.files <- sort(list.files("data-raw/codecs", pattern = "[.]txt$", full.names = TRUE))
.read <- function(path) {
  table <- utils::read.delim(
    path,
    quote = "", colClasses = "character", na.strings = character(0),
    comment.char = "", stringsAsFactors = FALSE
  )
  bytes <- sprintf("%02X", 0:255)
  if (!identical(names(table), c("byte", "code_point")) ||
      !identical(table$byte, bytes)) {
    stop(path, " must hold the columns byte and code_point, with bytes 00 to FF in order")
  }
  hole <- table$code_point == "hole"
  if (!all(grepl("^[0-9A-F]{4,6}$", table$code_point[!hole]))) {
    stop(path, " holds a code point that is neither hexadecimal nor `hole`")
  }
  code_points <- rep(NA_integer_, 256L)
  code_points[!hole] <- strtoi(table$code_point[!hole], base = 16L)
  code_points
}
codec_tables <- lapply(.files, .read)
names(codec_tables) <- sub("[.]txt$", "", basename(.files))
