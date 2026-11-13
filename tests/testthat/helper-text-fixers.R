# The snapshot of the text fixers, tests/testthat/reference/text_fixers.tsv,
# written by data-raw/generators/snapshot_text_fixers.py.

text_fixer_names <- c(
  "unescape_html", "remove_terminal_escapes", "uncurl_quotes",
  "fix_latin_ligatures", "fix_character_width", "fix_line_breaks",
  "remove_control_chars"
)

# The rows of one fixer: a data frame of `text`, the input, and `fixed`,
# what the reference version's fixer of that name gives for it.
read_text_fixer_snapshot <- function(fixer) {
  snapshot <- read_reference_table("text_fixers.tsv", text = c("text", "fixed"))
  stopifnot(fixer %in% snapshot$fixer)
  snapshot[snapshot$fixer == fixer, c("text", "fixed")]
}

# An expectation: the function `fix`, which takes and returns a character
# vector, gives reference behaviour for every snapshot input of `fixer`.
# `fix` may be the export, its internal form, or a part of the fixer loop
# that applies that fixer alone.
expect_text_fixer_reference <- function(fixer, fix) {
  snapshot <- read_text_fixer_snapshot(fixer)
  expect_reference(fixer, snapshot$text, fix(snapshot$text), snapshot$fixed)
}
