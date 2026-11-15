# Readers for the committed snapshots of reference behaviour under
# tests/testthat/reference/, and the names of options their variants
# share. Each snapshot is written by a generator script in
# data-raw/generators/ and is never edited by hand.

# Read a tab-separated snapshot. Every column comes back as character and
# an empty field stays an empty string. The columns named in `text` are
# unescaped from the \uXXXX form the generators write; the others are left
# as the file has them (unescape them with `unescape_reference()` where
# a text may hold U+0000).
read_reference <- function(name, text = "text") {
  out <- utils::read.delim(
    test_path("reference", name),
    quote = "", colClasses = "character", na.strings = character(0),
    comment.char = "", strip.white = FALSE, encoding = "UTF-8",
    stringsAsFactors = FALSE
  )
  stopifnot(all(text %in% names(out)))
  out[text] <- lapply(out[text], stringi::stri_unescape_unicode)
  out
}

# Unescape reference texts. A text of the reference version that holds
# U+0000 cannot be an R string: it stays escaped, as the file has it, and
# is recognised by the six characters \u0000. (The generators escape a
# backslash, so an escaped text holds them for no other reason.) The
# matcher of the departure `decoded-nul-dropped` reads this form.
unescape_reference <- function(x) {
  holds_nul <- grepl("\\u0000", x, fixed = TRUE)
  x[!holds_nul] <- stringi::stri_unescape_unicode(x[!holds_nul])
  x
}

# The four options of the encoding repair. The reference version does not
# pass them on when they are given to fix_text() as keyword arguments (the
# departure `encoding-sub-options-honoured`).
encoding_sub_options <- c(
  "restore_byte_a0", "replace_lossy_sequences", "decode_inconsistent_utf8",
  "fix_c1_controls"
)

# The snapshot variants that each turn one of `options` off: a list named
# `no_<option>`, each element the options to pass.
options_off <- function(options) {
  off <- lapply(options, function(option) stats::setNames(list(FALSE), option))
  stats::setNames(off, paste0("no_", options))
}
