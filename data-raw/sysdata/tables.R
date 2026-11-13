# Derived from python-ftfy v6.3.1, ftfy/chardata.py and ftfy/fixes.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# The data tables of the text fixers, read from the files that the
# table_*.py generators write to data-raw/tables/:
#
# `html_entities`  what each named HTML entity becomes: a character vector
#                  named by the entity as written, "&amp;".
# `html_numeric`   what a numeric HTML reference becomes when that is not
#                  the character with its number: a data frame of ranges
#                  of numbers, `first` to `last` (doubles, both included,
#                  in order; the last range ends at `Inf`), and `result`,
#                  the text the reference becomes: "" when it is removed,
#                  `NA` when it is left as written.
# `ligatures`      what `fix_latin_ligatures()` replaces, and
# `width_map`      what `fix_character_width()` replaces: each a list of
#                  `code_point` (integers, in order) and `replacement`
#                  (the text each becomes).
# `control_chars`  the code points `remove_control_chars()` removes, in
#                  order. U+0000 is among them, as upstream has it.

.read <- function(name, columns) {
  path <- file.path("data-raw/tables", name)
  if (!all(stringi::stri_enc_isascii(readLines(path, warn = TRUE)))) {
    stop(path, " must be ASCII")
  }
  table <- utils::read.delim(
    path,
    quote = "", colClasses = "character", na.strings = character(0),
    comment.char = "", stringsAsFactors = FALSE
  )
  if (!identical(names(table), columns) || nrow(table) == 0L) {
    stop(path, " must hold the columns ", paste(columns, collapse = ", "))
  }
  table
}

.is_hex <- function(x) grepl("^[0-9A-F]{4,6}$", x)

# One code point from its hexadecimal form.
.code_point <- function(x, path) {
  if (!all(.is_hex(x))) {
    stop(path, " holds a code point that is not hexadecimal")
  }
  strtoi(x, base = 16L)
}

# Text from its code points in hexadecimal, separated by spaces.
.text <- function(x, path) {
  parts <- strsplit(x, " ", fixed = TRUE)
  if (!all(.is_hex(unlist(parts))) || any(lengths(parts) == 0L)) {
    stop(path, " holds a replacement that is not hexadecimal code points")
  }
  vapply(parts, function(hex) intToUtf8(strtoi(hex, base = 16L)), "")
}

.translate <- function(name) {
  table <- .read(name, c("code_point", "replacement"))
  code_point <- .code_point(table$code_point, name)
  if (is.unsorted(code_point, strictly = TRUE)) {
    stop(name, " must be in code point order, without repeats")
  }
  list(code_point = code_point, replacement = .text(table$replacement, name))
}

html_entities <- local({
  table <- .read("html_entities.txt", c("entity", "replacement"))
  if (anyDuplicated(table$entity) > 0L) {
    stop("html_entities.txt names an entity twice")
  }
  stats::setNames(.text(table$replacement, "html_entities.txt"), table$entity)
})

html_numeric <- local({
  name <- "html_numeric.txt"
  table <- .read(name, c("first", "last", "result"))
  n <- nrow(table)
  if (table$last[[n]] != "inf") {
    stop(name, " must end with the range that has no upper end")
  }
  first <- as.numeric(.code_point(table$first, name))
  last <- c(as.numeric(.code_point(table$last[-n], name)), Inf)
  if (any(first > last) || any(first[-1L] <= last[-n])) {
    stop(name, " must hold ranges in order that do not overlap")
  }
  result <- rep(NA_character_, n)
  result[table$result == "empty"] <- ""
  character <- !(table$result %in% c("empty", "unchanged"))
  result[character] <- .text(table$result[character], name)
  data.frame(first = first, last = last, result = result, stringsAsFactors = FALSE)
})

ligatures <- .translate("ligatures.txt")
width_map <- .translate("width_map.txt")
control_chars <- .code_point(.read("control_chars.txt", "code_point")$code_point, "control_chars.txt")
