# Readers of the larger corpus under tests/corpus/, which is kept out of
# the built package: tests/corpus/inputs/<slice>.tsv.xz, written by
# data-raw/generators/corpus_inputs.py (the slice "own"), and
# tests/corpus/snapshot/<slice>.tsv.xz, written by
# data-raw/generators/corpus_snapshot.py, whose docstring says what every
# column is and how a cell is written. Base R and stringi only.

corpus_dir <- function() {
  test_path("..", "corpus")
}

# The corpus is absent from a built package, and so on CRAN.
corpus_present <- function() {
  dir.exists(file.path(corpus_dir(), "inputs")) &&
    dir.exists(file.path(corpus_dir(), "snapshot"))
}

corpus_slices <- function() {
  sub("[.]tsv[.]xz$", "", sort(list.files(file.path(corpus_dir(), "inputs"), pattern = "[.]tsv[.]xz$")))
}

# One compressed table, every column character, nothing unescaped.
read_corpus_table <- function(kind, slice) {
  connection <- xzfile(file.path(corpus_dir(), kind, paste0(slice, ".tsv.xz")), open = "rt")
  on.exit(close(connection))
  utils::read.delim(
    connection,
    quote = "", colClasses = "character", na.strings = character(0),
    comment.char = "", strip.white = FALSE, check.names = FALSE,
    encoding = "UTF-8", stringsAsFactors = FALSE
  )
}

# The inputs of the slices asked for, one row each: `id`, `slice`,
# `variant`, `detail`, `unicode` (of the input alone) and `text`, unescaped.
read_corpus_inputs <- function(slices = corpus_slices()) {
  out <- do.call(rbind, lapply(slices, function(slice) read_corpus_table("inputs", slice)))
  out$text <- stringi::stri_unescape_unicode(out$text)
  out
}

# The snapshot of the same slices, row for row with the inputs, as it is
# in the files: resolve a column with corpus_text() or corpus_plan().
read_corpus_snapshot <- function(slices = corpus_slices()) {
  do.call(rbind, lapply(slices, function(slice) read_corpus_table("snapshot", slice)))
}

# The name of the column that is the base of a text column: "" for the
# input itself.
corpus_base_column <- function(column) {
  fun <- sub("[.].*$", "", column)
  if (fun == "fixer" || grepl("[.]default$", column)) {
    ""
  } else if (fun == "apply_plan") {
    paste0(sub("^apply_plan[.]", "", column), ".default")
  } else {
    paste0(fun, ".default")
  }
}

# What the reference version gave in one text column, as a data frame with
# a row for each input: `text`, and `error`, the "<type>: <message>" of the
# exception the reference version raised, or NA. Where it raised, `text` is
# NA. A text that holds U+0000 stays escaped, as unescape_reference()
# leaves it.
corpus_text <- function(snapshot, inputs, column) {
  stopifnot(column %in% names(snapshot), nrow(snapshot) == nrow(inputs))
  cell <- snapshot[[column]]
  base_column <- corpus_base_column(column)
  if (base_column == "") {
    base <- data.frame(text = inputs$text, error = NA_character_, stringsAsFactors = FALSE)
  } else {
    base <- corpus_text(snapshot, inputs, base_column)
  }
  raised <- startsWith(cell, "!")
  written <- startsWith(cell, "=")
  stopifnot(all(raised | written | cell == ""), all(is.na(base$error[cell == ""])))
  text <- base$text
  text[written] <- unescape_reference(substring(cell[written], 2L))
  text[raised] <- NA_character_
  error <- rep(NA_character_, length(cell))
  error[raised] <- stringi::stri_unescape_unicode(substring(cell[raised], 2L))
  data.frame(text = text, error = error, stringsAsFactors = FALSE)
}

# The plans of one explaining function under one variant, in their text
# form; NA where the reference version raised.
corpus_plan <- function(snapshot, fun, variant = "default") {
  default <- snapshot[[paste0(fun, ".default.plan")]]
  plan <- snapshot[[paste0(fun, ".", variant, ".plan")]]
  stopifnot(!is.null(default), !is.null(plan), all(default != ""))
  same <- plan == ""
  plan[same] <- default[same]
  plan[startsWith(plan, "!")] <- NA_character_
  plan
}

# Whether the running ICU knows every character of a row: its Unicode
# version is at least the row's tag. Never for the tag "unassigned".
corpus_comparable <- function(tag, icu = stringi::stri_info()$Unicode.version) {
  out <- tag != "unassigned"
  out[out] <- numeric_version(tag[out]) <= numeric_version(icu)
  out
}

# The variants of the snapshot, by the name in its columns: the options
# that give each in R.
corpus_variants <- function() {
  booleans <- c(
    "unescape_html", "remove_terminal_escapes", "fix_encoding", "restore_byte_a0",
    "replace_lossy_sequences", "decode_inconsistent_utf8", "fix_c1_controls",
    "fix_latin_ligatures", "fix_character_width", "uncurl_quotes", "fix_line_breaks",
    "remove_control_chars"
  )
  all_off <- c(stats::setNames(rep(list(FALSE), length(booleans)), booleans), list(normalization = NULL))
  c(
    list(default = list()),
    options_off(booleans),
    list(normalization_NULL = list(normalization = NULL), all_off = all_off)
  )
}
