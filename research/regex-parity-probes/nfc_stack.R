library(stringi)
a <- commandArgs(TRUE)
x <- jsonlite::fromJSON(a[1])
cat("NFC differences stringi vs Python:", sum(stri_trans_nfc(x$s) != x$nfc), "of", nrow(x), "\n")
ansi <- "\u001b\\[((?:[0-9]|;)*)([a-zA-Z])"
s <- paste0("\u001b[", strrep("1", 1e6 - 3), "m")
for (lim in c(8e6, 3.2e7, 6.4e7, 1.28e8, 2.56e8, 5.12e8)) {
  r <- tryCatch({t <- system.time(stri_locate_first_regex(s, ansi, opts_regex = stri_opts_regex(stack_limit = lim, unix_lines = TRUE)))[["elapsed"]]; sprintf("ok %.2fs", t)}, error = function(e) "overflow")
  cat(sprintf("ANSI_RE, 1,000,000 chars, stack_limit %4.0f MB: %s\n", lim / 1e6, r))
}
