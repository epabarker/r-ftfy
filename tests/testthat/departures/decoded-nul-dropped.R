# Matcher for the departure `decoded-nul-dropped`: the reference text holds
# U+0000, and R gave that text without it.
#
# A reference text that holds U+0000 cannot be an R string. It reaches the
# matcher still escaped, as `unescape_reference()` in
# helper-decoder-corpus.R leaves it, with each U+0000 as the six
# characters \u0000.
#
# It also matches the plan of fix_and_explain() for such a text. With
# default options the reference version's fixer remove_control_chars
# removes the decoded U+0000 and is recorded for it; in R there is nothing
# left to remove, so that one step is not in the plan. The difference is
# matched when the reference plan is R's plan with one step
# `apply remove_control_chars` more, somewhere after a step
# `decode utf-8-variants`, and one of the codecs the repair tries encodes
# the input to bytes that hold C0 80.
function(difference) {
  nul <- "\\u0000"
  actual <- difference$actual
  reference <- difference$reference
  if (!is.character(actual) || is.na(actual) ||
      !is.character(reference) || is.na(reference)) {
    return(FALSE)
  }
  if (grepl(nul, reference, fixed = TRUE)) {
    return(identical(
      actual,
      stringi::stri_unescape_unicode(gsub(nul, "", reference, fixed = TRUE))
    ))
  }
  if (!identical(difference$fun, "fix_and_explain")) {
    return(FALSE)
  }
  theirs <- strsplit(reference, " > ", fixed = TRUE)[[1L]]
  ours <- strsplit(actual, " > ", fixed = TRUE)[[1L]]
  decoded <- match("decode utf-8-variants", theirs)
  extra <- which(theirs == "apply remove_control_chars")
  extra <- extra[!is.na(decoded) & extra > decoded]
  one_step_more <- any(vapply(
    extra, function(at) identical(theirs[-at], ours), logical(1L)
  ))
  if (!one_step_more) {
    return(FALSE)
  }
  for (codec in ftfy:::charmap_codecs()) {
    bytes <- ftfy:::codec_try_encode(difference$input, codec)
    if (!is.na(bytes) && grepl("\u00c0\u0080", bytes, fixed = TRUE)) {
      return(TRUE)
    }
  }
  FALSE
}
