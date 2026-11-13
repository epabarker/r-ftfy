# PROTOTYPE - throwaway. Not package code. For issue #8,
# "Function arguments versus a config object".
#
# Question: how should upstream's TextFixerConfig options look at an R call
# site? Three candidate designs, the same eight scenarios run through each.
# Nothing is fixed here: every fix_*() stub just reports the options it
# resolved, so you can see what each call would have done.
#
# Run:  Rscript prototype/config-api/PROTOTYPE-config-api.R

DEFAULTS <- list(
  unescape_html = "auto", remove_terminal_escapes = TRUE, fix_encoding = TRUE,
  restore_byte_a0 = TRUE, replace_lossy_sequences = TRUE,
  decode_inconsistent_utf8 = TRUE, fix_c1_controls = TRUE,
  fix_latin_ligatures = TRUE, fix_character_width = TRUE, uncurl_quotes = TRUE,
  fix_line_breaks = TRUE, remove_control_chars = TRUE, normalization = "NFC",
  max_decode_length = 1e6
)

validate <- function(opts) {
  bad <- setdiff(names(opts), names(DEFAULTS))
  if (length(bad)) {
    near <- names(DEFAULTS)[adist(bad[1], names(DEFAULTS)) <= 2]
    stop("unknown option `", bad[1], "`",
         if (length(near)) paste0("; did you mean `", near[1], "`?"), call. = FALSE)
  }
  for (n in names(opts)) {
    v <- opts[[n]]
    ok <- switch(n,
      unescape_html = identical(v, "auto") || isTRUE(v) || isFALSE(v),
      normalization = is.null(v) || (is.character(v) && length(v) == 1 &&
                                       v %in% c("NFC", "NFD", "NFKC", "NFKD")),
      max_decode_length = is.numeric(v) && length(v) == 1 && v >= 1,
      isTRUE(v) || isFALSE(v))
    if (!ok) stop("`", n, "` has an invalid value: ", deparse(v), call. = FALSE)
  }
  opts
}

report <- function(fn, opts) {
  diff <- Filter(function(n) !identical(opts[[n]], DEFAULTS[[n]]), names(DEFAULTS))
  cat("   ", fn, " ran with ",
      if (!length(diff)) "all defaults" else
        paste0(diff, " = ", vapply(opts[diff], deparse, ""), collapse = ", "),
      "\n", sep = "")
  invisible(NULL)
}

# ---- Design A: plain arguments only -----------------------------------
A <- new.env()
local({
  f <- function(name) {
    fn <- function(x) NULL
    formals(fn) <- c(alist(x = ), DEFAULTS)
    body(fn) <- bquote({
      opts <- validate(mget(names(DEFAULTS)))
      report(.(name), opts)
    })
    fn
  }
  fix_text <- f("fix_text"); fix_and_explain <- f("fix_and_explain")
}, envir = A)

# ---- Design B: config object only -------------------------------------
B <- new.env()
local({
  ftfy_config <- function(...) {
    opts <- list(...)
    if (length(opts) && (is.null(names(opts)) || any(names(opts) == "")))
      stop("options must be named", call. = FALSE)
    structure(utils::modifyList(DEFAULTS, validate(opts), keep.null = TRUE),
              class = "ftfy_config")
  }
  need <- function(config) if (!inherits(config, "ftfy_config"))
    stop("`config` must be made with ftfy_config()", call. = FALSE) else config
  fix_text <- function(x, config = ftfy_config()) report("fix_text", need(config))
  fix_and_explain <- function(x, config = ftfy_config()) report("fix_and_explain", need(config))
}, envir = B)

# ---- Design C: both; named arguments override the config --------------
C <- new.env()
local({
  ftfy_config <- B$ftfy_config
  resolve <- function(config, dots) {
    if (!inherits(config, "ftfy_config"))
      stop("`config` must be made with ftfy_config()", call. = FALSE)
    if (length(dots) && (is.null(names(dots)) || any(names(dots) == "")))
      stop("options must be named", call. = FALSE)
    utils::modifyList(config, validate(dots), keep.null = TRUE)
  }
  fix_text <- function(x, ..., config = ftfy_config())
    report("fix_text", resolve(config, list(...)))
  fix_and_explain <- function(x, ..., config = ftfy_config())
    report("fix_and_explain", resolve(config, list(...)))
}, envir = C)

# ---- Scenarios: the same intent written for each design ---------------
scenarios <- list(
  "1. Defaults" = c(
    A = 'fix_text(x)', B = 'fix_text(x)', C = 'fix_text(x)'),
  "2. Keep curly quotes" = c(
    A = 'fix_text(x, uncurl_quotes = FALSE)',
    B = 'fix_text(x, ftfy_config(uncurl_quotes = FALSE))',
    C = 'fix_text(x, uncurl_quotes = FALSE)'),
  "3. Same cautious settings for two calls" = c(
    A = 'fix_text(x, uncurl_quotes = FALSE, fix_character_width = FALSE, normalization = NULL)
fix_and_explain(y, uncurl_quotes = FALSE, fix_character_width = FALSE, normalization = NULL)',
    B = 'cautious <- ftfy_config(uncurl_quotes = FALSE, fix_character_width = FALSE, normalization = NULL)
fix_text(x, cautious)
fix_and_explain(y, cautious)',
    C = 'cautious <- ftfy_config(uncurl_quotes = FALSE, fix_character_width = FALSE, normalization = NULL)
fix_text(x, config = cautious)
fix_and_explain(y, config = cautious)'),
  "4. Saved settings, one change for one call" = c(
    A = '# no saved settings to start from; spell everything out again
fix_text(x, uncurl_quotes = FALSE, fix_character_width = FALSE, unescape_html = FALSE)',
    B = 'cautious <- ftfy_config(uncurl_quotes = FALSE, fix_character_width = FALSE)
# no way to tweak a config; build a second one
fix_text(x, ftfy_config(uncurl_quotes = FALSE, fix_character_width = FALSE, unescape_html = FALSE))',
    C = 'cautious <- ftfy_config(uncurl_quotes = FALSE, fix_character_width = FALSE)
fix_text(x, unescape_html = FALSE, config = cautious)'),
  "5. Typo in an option name" = c(
    A = 'fix_text(x, uncurl_quote = FALSE)',
    B = 'fix_text(x, ftfy_config(uncurl_quote = FALSE))',
    C = 'fix_text(x, uncurl_quote = FALSE)'),
  "6. Wrong value" = c(
    A = 'fix_text(x, normalization = "nfc")',
    B = 'fix_text(x, ftfy_config(normalization = "nfc"))',
    C = 'fix_text(x, normalization = "nfc")'),
  "7. Second argument passed by position" = c(
    A = 'fix_text(x, FALSE)   # silently means unescape_html = FALSE',
    B = 'fix_text(x, FALSE)',
    C = 'fix_text(x, FALSE)'),
  "8. What the signature shows (args / autocomplete)" = c(
    A = 'cat("   ", length(formals(fix_text)), "arguments:", paste(names(formals(fix_text)), collapse = ", "), "\\n")',
    B = 'cat("   ", length(formals(fix_text)), "arguments:", paste(names(formals(fix_text)), collapse = ", "), "\\n")',
    C = 'cat("   ", length(formals(fix_text)), "arguments:", paste(names(formals(fix_text)), collapse = ", "), "\\n")')
)

titles <- c(A = "A  plain arguments only",
            B = "B  config object only",
            C = "C  both: named arguments override a config")
envs <- list(A = A, B = B, C = C)
x <- "text"; y <- "text"
for (s in names(scenarios)) {
  cat("\n", strrep("=", 70), "\n", s, "\n", strrep("=", 70), "\n", sep = "")
  for (d in names(envs)) {
    cat("\n[", titles[[d]], "]\n", sep = "")
    e <- new.env(parent = envs[[d]]); e$x <- x; e$y <- y
    for (line in strsplit(scenarios[[s]][[d]], "\n")[[1]]) {
      cat("> ", line, "\n", sep = "")
      tryCatch(eval(parse(text = line), e),
               error = function(err) cat("    Error: ", conditionMessage(err), "\n", sep = ""))
    }
  }
}
