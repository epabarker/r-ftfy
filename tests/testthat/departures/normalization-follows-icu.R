# Matcher for the departure `normalization-follows-icu`: the text or the
# plan of fix_and_explain() or fix_text() differs from the reference
# version's because the input holds a character that has normalisation
# data in the reference version's Unicode, 15.1, and that the ICU stringi
# was built with does not know.
#
# The characters are those that Unicode 15.0 and 15.1 assigned with a
# combining class or a decomposition (listed from the reference
# interpreter's `unicodedata`); all of them came in 15.0. The matcher
# matches only where the running ICU has one of them in the input as
# unassigned, so with an ICU that knows them it matches nothing. A newer
# ICU than the reference version's Unicode needs no matching: no snapshot
# holds a character that Unicode 15.1 does not have.
function(difference) {
  new_in_unicode_15 <- c(
    0x10EFD:0x10EFF, 0x11F41:0x11F42, 0x1E030:0x1E06D, 0x1E08F,
    0x1E4EC:0x1E4EF
  )
  input <- difference$input
  actual <- difference$actual
  if (!difference$fun %in% c("fix_and_explain", "fix_text") ||
      !is.character(input) || length(input) != 1L || is.na(input) ||
      !is.character(actual) || length(actual) != 1L || is.na(actual) ||
      !is.character(difference$reference) || is.na(difference$reference)) {
    return(FALSE)
  }
  held <- intersect(utf8ToInt(input), new_in_unicode_15)
  length(held) > 0L &&
    any(stringi::stri_detect_charclass(intToUtf8(held, multiple = TRUE), "\\p{Cn}"))
}
