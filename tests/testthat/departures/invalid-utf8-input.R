# Matcher for the departure `invalid-utf8-input`: R raised the entry step's
# error on an input that is not valid UTF-8, whatever the reference gives.
function(difference) {
  inherits(difference$actual, "error") &&
    !stringi::stri_enc_isutf8(difference$input) &&
    grepl("invalid UTF-8", conditionMessage(difference$actual), fixed = TRUE)
}
