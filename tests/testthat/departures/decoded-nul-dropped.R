# Matcher for the departure `decoded-nul-dropped`: the reference text holds
# U+0000, and R gave that text without it.
#
# A reference text that holds U+0000 cannot be an R string. It reaches the
# matcher still escaped, as `unescape_reference()` in
# helper-decoder-corpus.R leaves it, with each U+0000 as the six
# characters \u0000.
function(difference) {
  nul <- "\\u0000"
  is.character(difference$actual) &&
    !is.na(difference$actual) &&
    is.character(difference$reference) &&
    !is.na(difference$reference) &&
    grepl(nul, difference$reference, fixed = TRUE) &&
    identical(
      difference$actual,
      stringi::stri_unescape_unicode(gsub(nul, "", difference$reference, fixed = TRUE))
    )
}
