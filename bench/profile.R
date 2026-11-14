# The Rprof breakdown of one benchmark column (issue #46, ADR 0008): how
# much of R's time is in stringi and ICU and how much in R-level code.
#
#   Rscript bench/profile.R --column notes_n1e4 [--function fix_text]
#     [--seconds 8] [--lib DIR]
#
# Prints Markdown. bench.R makes the same breakdown by itself for every
# column whose ratio is 1 or above.

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  source(file.path(dirname(normalizePath(sub("^--file=", "", file_arg))), "common.R"))
})

root <- dirname(script_dir())
args <- parse_args(commandArgs(TRUE), list(
  column = "notes_n1e4",
  `function` = "fix_text",
  seconds = "8",
  lib = ""
))
lib <- if (nzchar(args$lib)) args$lib else install_tree(root)
library(ftfy, lib.loc = lib)

writeLines(profile_markdown(
  get(args[["function"]], envir = asNamespace("ftfy")),
  read_distinct(root, args$column),
  sprintf("`%s(values)` on the distinct values of `%s`", args[["function"]], args$column),
  seconds = as.numeric(args$seconds)
))
