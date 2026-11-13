library(stringi)
ansi <- "\u001b\\[((?:[0-9]|;)*)([a-zA-Z])"
for (n in c(1e6, 4e6)) {
  s <- paste0("\u001b[", strrep("1", n - 3), "m")
  r <- tryCatch({t <- system.time(m <- stri_locate_first_regex(s, ansi, opts_regex = stri_opts_regex(stack_limit = .Machine$integer.max, unix_lines = TRUE)))[["elapsed"]]; sprintf("ok, match end %d, %.2fs", m[1, 2], t)}, error = function(e) conditionMessage(e))
  cat(sprintf("n=%g, stack_limit=integer max: %s\n", n, r))
}
s <- paste0("\u001b[", strrep("1", 1e6 - 3), "m")
cat("stack_limit=0L:", tryCatch({stri_locate_first_regex(s, ansi, opts_regex = stri_opts_regex(stack_limit = 0L)); "ok"}, error = function(e) conditionMessage(e)), "\n")
