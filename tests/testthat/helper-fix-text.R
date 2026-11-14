# Reader of the snapshot of fix_text(),
# tests/testthat/reference/fix_text.tsv, written by
# data-raw/generators/snapshot_fix_text.py.

# The four options of the encoding repair. The reference version does not
# pass them on when they are given to fix_text() as keyword arguments (the
# departure `encoding-sub-options-honoured`).
encoding_sub_options <- c(
  "restore_byte_a0", "replace_lossy_sequences", "decode_inconsistent_utf8",
  "fix_c1_controls"
)

# The variants the snapshot holds, by column name: for each, the options
# that are passed to fix_text(). "default" passes none; every other
# variant changes one option. A `config_no_<option>` variant is what the
# reference version gives when the option comes in a TextFixerConfig, and
# so is passed on to the encoding repair; in R the option is given in the
# same way for both.
fix_text_variants <- function() {
  variants <- fix_and_explain_variants()
  off <- lapply(encoding_sub_options, function(option) stats::setNames(list(FALSE), option))
  names(off) <- paste0("config_no_", encoding_sub_options)
  c(
    variants,
    list(
      max_decode_length_3 = list(max_decode_length = 3),
      max_decode_length_10 = list(max_decode_length = 10)
    ),
    off
  )
}

# The snapshot as a list with one data frame for each variant, named as
# `fix_text_variants()`: `text`, the input, and `fixed`, what the reference
# version gives for it with that variant's options. The empty fields of
# the file, which stand for "as with default options", are filled in.
read_fix_text_snapshot <- function() {
  raw <- read_reference_table("fix_text.tsv", text = "text")
  variants <- setdiff(names(fix_text_variants()), "default")
  stopifnot(identical(names(raw), c("text", "fixed", variants)))
  out <- list(default = data.frame(
    text = raw$text, fixed = unescape_reference(raw$fixed),
    stringsAsFactors = FALSE
  ))
  for (variant in variants) {
    fixed <- raw[[variant]]
    same <- fixed == ""
    fixed[same] <- raw$fixed[same]
    out[[variant]] <- data.frame(
      text = raw$text, fixed = unescape_reference(fixed),
      stringsAsFactors = FALSE
    )
  }
  out
}

# fix_text() on `x` with the options of one variant.
fix_text_variant <- function(x, variant) {
  do.call(fix_text, c(list(x), fix_text_variants()[[variant]]))
}
