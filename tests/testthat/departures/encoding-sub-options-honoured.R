# Matcher for the departure `encoding-sub-options-honoured`: fix_text() was
# called with one of the four options of the encoding repair set to FALSE
# by name. The reference version did not pass the option on and gave what
# it gives with default options; R honoured it.
#
# A difference does not say which options the call had, so it is matched
# by what the two results are: `fun` is "fix_text", the reference text is
# what R's fix_text() gives for the input with default options, and R's
# text is what R's fix_text() gives with one of the four options off and
# every other option at its default. So it matches only a call that
# changed one of these four options and nothing else, and only where the
# reference version's result with default options is also R's.
function(difference) {
  input <- difference$input
  reference <- difference$reference
  actual <- difference$actual
  if (!identical(difference$fun, "fix_text") ||
      !is.character(input) || is.na(input) ||
      !is.character(reference) || is.na(reference) ||
      !is.character(actual) || is.na(actual)) {
    return(FALSE)
  }
  if (!identical(reference, ftfy::fix_text(input))) {
    return(FALSE)
  }
  options <- c(
    "restore_byte_a0", "replace_lossy_sequences", "decode_inconsistent_utf8",
    "fix_c1_controls"
  )
  for (option in options) {
    off <- stats::setNames(list(FALSE), option)
    if (identical(actual, do.call(ftfy::fix_text, c(list(input), off)))) {
      return(TRUE)
    }
  }
  FALSE
}
