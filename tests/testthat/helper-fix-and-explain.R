# Reader of the snapshot of fix_and_explain(),
# tests/testthat/reference/fix_and_explain.tsv, written by
# data-raw/generators/snapshot_fix_and_explain.py.

# The variants the snapshot holds, by column name: for each, the options
# that are passed to fix_and_explain(). "default" passes none; every other
# variant changes one option.
fix_and_explain_variants <- function() {
  booleans <- c(
    "remove_terminal_escapes", "fix_encoding", "restore_byte_a0",
    "replace_lossy_sequences", "decode_inconsistent_utf8", "fix_c1_controls",
    "fix_latin_ligatures", "fix_character_width", "uncurl_quotes",
    "fix_line_breaks", "remove_control_chars"
  )
  c(
    list(default = list()),
    options_off(booleans),
    list(
      normalization_NFD = list(normalization = "NFD"),
      normalization_NFKC = list(normalization = "NFKC"),
      normalization_NFKD = list(normalization = "NFKD"),
      normalization_NULL = list(normalization = NULL),
      unescape_html_TRUE = list(unescape_html = TRUE),
      unescape_html_FALSE = list(unescape_html = FALSE)
    )
  )
}

# The snapshot as a list with one data frame for each variant, named as
# `fix_and_explain_variants()`: `text`, the input; `fixed` and `plan`, what
# the reference version gives for it with that variant's options. The
# empty fields of the file, which stand for "as with default options", are
# filled in. A reference text that holds U+0000 stays escaped (see
# `unescape_reference()`).
read_fix_and_explain_snapshot <- function() {
  raw <- read_reference("fix_and_explain.tsv", text = "text")
  variants <- setdiff(names(fix_and_explain_variants()), "default")
  stopifnot(identical(
    names(raw),
    c("text", "fixed", "plan", as.vector(rbind(variants, paste0("plan.", variants))))
  ))
  stopifnot(all(raw$plan != ""))
  out <- list(default = data.frame(
    text = raw$text, fixed = unescape_reference(raw$fixed), plan = raw$plan,
    stringsAsFactors = FALSE
  ))
  for (variant in variants) {
    fixed <- raw[[variant]]
    plan <- raw[[paste0("plan.", variant)]]
    same <- plan == ""
    stopifnot(all(fixed[same] == ""))
    fixed[same] <- raw$fixed[same]
    plan[same] <- raw$plan[same]
    out[[variant]] <- data.frame(
      text = raw$text, fixed = unescape_reference(fixed), plan = plan,
      stringsAsFactors = FALSE
    )
  }
  out
}

# fix_and_explain() on `x` with the options of one variant.
fix_and_explain_variant <- function(x, variant) {
  do.call(fix_and_explain, c(list(x), fix_and_explain_variants()[[variant]]))
}
