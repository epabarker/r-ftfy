# Prints what base R's enc2utf8() makes of unmarked bytes in this session:
# every byte from 80 to 9F, and A0, E9 and FF. This is the data behind the
# tests named "measured" in tests/testthat/test-platform.R.

cat("LC_CTYPE:", Sys.getlocale("LC_CTYPE"), "\n")
cat(
  "l10n_info:",
  paste0(names(l10n_info()), "=", unlist(l10n_info()), collapse = ", "), "\n"
)
for (byte in c(0x80:0xa0, 0xe9, 0xff)) {
  x <- rawToChar(as.raw(byte))
  converted <- tryCatch(enc2utf8(x), error = function(e) NA_character_)
  cat(sprintf(
    "%02x -> %s (marked %s)\n", byte,
    if (is.na(converted)) "error" else paste(charToRaw(converted), collapse = " "),
    Encoding(converted)
  ))
}
