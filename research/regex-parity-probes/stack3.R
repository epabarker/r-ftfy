library(stringi)
ansi <- "\u001b\\[((?:[0-9]|;)*)([a-zA-Z])"
try1 <- function(n, lim) { s <- paste0("\u001b[", strrep("1", n - 3), "m")
  tryCatch({stri_locate_first_regex(s, ansi, opts_regex = stri_opts_regex(stack_limit = lim)); "ok"}, error = function(e) "overflow") }
for (lim in c(1e9, 1.07e9, 1.08e9, 1.5e9, 2e9, 2147483647)) cat(sprintf("1M chars, limit %.4g: %s\n", lim, try1(1e6, lim)))
for (lim in c(2.56e8, 5.12e8, 1e9)) cat(sprintf("4M chars, limit %.4g: %s\n", lim, try1(4e6, lim)))
