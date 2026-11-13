# Readers for the committed snapshots of reference behaviour under
# tests/testthat/reference/. Each snapshot is written by a generator script
# in data-raw/generators/ and is never edited by hand.

# Read a tab-separated snapshot. Every column comes back as character, an
# empty field stays an empty string, and the `text` column is unescaped
# from the \uXXXX form the generators write.
read_reference <- function(name) {
  path <- test_path("reference", name)
  out <- utils::read.delim(
    path,
    quote = "", colClasses = "character", na.strings = character(0),
    comment.char = "", strip.white = FALSE, encoding = "UTF-8",
    stringsAsFactors = FALSE
  )
  out$text <- stringi::stri_unescape_unicode(out$text)
  out
}
