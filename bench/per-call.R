# The cost of one call on one string (issue #53, ADR 0008): how long one
# call of fix_text() and of fix_encoding() takes on a single string, and
# where the time goes, regex call by regex call.
#
#   Rscript bench/per-call.R [--out FILE] [--label TEXT] [--reps 301]
#     [--lib DIR]
#
# Needs no Python. Installs the package from this tree, as bench.R does,
# unless --lib names a library that has it. Prints Markdown; bench/README.md
# says what is timed. Exit status 0 when it ran.

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  source(file.path(dirname(normalizePath(sub("^--file=", "", file_arg))), "common.R"))
})

root <- dirname(script_dir())
args <- parse_args(commandArgs(TRUE), list(
  out = "",
  label = "Not the release-gate run.",
  reps = "301",
  lib = ""
))
reps <- as.integer(args$reps)
stopifnot(reps >= 1L)

lib <- if (nzchar(args$lib)) args$lib else install_tree(root)
library(ftfy, lib.loc = lib)
ns <- asNamespace("ftfy")

functions <- c("fix_text", "fix_encoding")
# One string each, written as escapes: plain ASCII, accented Latin that is
# not mojibake, Cyrillic that is not mojibake, and two kinds of mojibake.
inputs <- c(
  ascii = "plain text",
  accented = "caf\u00e9 au lait",
  cyrillic = "\u043f\u0440\u0438\u0432\u0435\u0442",
  mojibake = "caf\u00c3\u00a9",
  `mojibake quote` = "it\u00e2\u20ac\u2122s"
)

# ---------------------------------------------------------------------------
# The time of one call: the median of `reps` calls, after one untimed call.

time_calls <- function(f, x) {
  f(x)
  times <- numeric(reps)
  for (i in seq_len(reps)) {
    started <- now()
    f(x)
    times[i] <- now() - started
  }
  1000 * stats::quantile(times, c(0.1, 0.5, 0.9), names = FALSE)
}

timed <- lapply(functions, function(name) {
  f <- get(name, envir = ns)
  lapply(inputs, function(x) time_calls(f, x))
})
names(timed) <- functions

# ---------------------------------------------------------------------------
# The regex calls of one call: every call of the package's three regex
# wrappers is timed, by the name of its pattern.

# The name of each pattern the package holds, by its text: the generated
# patterns, the codecs' patterns and the hand-written ones in the namespace.
pattern_names <- local({
  texts <- character()
  found <- character()
  add <- function(text, name) {
    if (is.character(text) && length(text) == 1L && !is.na(text) && !text %in% texts) {
      texts[[length(texts) + 1L]] <<- text
      found[[length(found) + 1L]] <<- name
    }
  }
  generated <- get("patterns", envir = ns)
  for (name in names(generated)) add(generated[[name]], name)
  codec <- get("codec", envir = ns)
  for (name in get("plan_codecs", envir = ns)) {
    pair <- tryCatch(codec(name), error = function(e) NULL)
    for (field in c("cannot_encode", "cannot_decode")) add(pair[[field]], paste0(name, " ", field))
  }
  for (name in ls(ns, all.names = TRUE)) add(get(name, envir = ns), name)
  list(texts = texts, names = found)
})
# A pattern built at run time is named after the function that used it.
namespace_functions <- Filter(is.function, mget(ls(ns, all.names = TRUE), envir = ns))
name_of <- function(pattern, caller) {
  at <- match(pattern, pattern_names$texts)
  if (!is.na(at)) {
    return(pattern_names$names[[at]])
  }
  # The function is found by identity, because fixers are called through
  # get() and their calls do not name them.
  for (name in names(namespace_functions)) {
    if (identical(caller, namespace_functions[[name]])) {
      return(sprintf("built in `%s()`", name))
    }
  }
  "built at run time"
}

calls <- NULL
wrapped <- c("regex_detect", "regex_locate_all", "regex_replace_all")
originals <- mget(wrapped, envir = ns)
for (wrapper in wrapped) {
  local({
    original <- originals[[wrapper]]
    assignInNamespace(wrapper, function(x, pattern, ...) {
      started <- now()
      out <- original(x, pattern, ...)
      elapsed <- 1000 * (now() - started)
      calls[[length(calls) + 1L]] <<- list(pattern = name_of(pattern, sys.function(-1L)),
        n = length(x), ms = elapsed)
      out
    }, ns)
  })
}

broken_down <- lapply(functions, function(name) {
  f <- get(name, envir = ns)
  lapply(inputs, function(x) {
    f(x)
    runs <- 51L
    calls <<- NULL
    for (i in seq_len(runs)) f(x)
    data.frame(
      pattern = vapply(calls, `[[`, "", "pattern"),
      empty = vapply(calls, function(call) call$n == 0L, TRUE),
      ms = vapply(calls, `[[`, 0, "ms") / runs
    )
  })
})
names(broken_down) <- functions
for (wrapper in wrapped) assignInNamespace(wrapper, originals[[wrapper]], ns)

# ---------------------------------------------------------------------------
# The report

ms <- function(x) sprintf("%.3f", x)
input_header <- paste0("`", names(inputs), "`")

report <- c(
  "# The cost of one call on one string",
  "",
  args$label,
  "",
  sprintf("- Date: %s", format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC")),
  machine_lines(root),
  sprintf("- Repetitions: %d calls on each string, after one untimed call.", reps),
  "",
  "ADR 0008 accepts 0.6 to 1.6 ms for a call on one string that is not plain ASCII.",
  "",
  "| String | Written as |",
  "|---|---|",
  sprintf("| `%s` | `\"%s\"` |", names(inputs), stringi::stri_escape_unicode(inputs)),
  "",
  "## Time of one call, ms",
  "",
  "The median, with the 10th and 90th percentiles in brackets.",
  "",
  paste0("| Function | ", paste(input_header, collapse = " | "), " |"),
  paste0("|---|", strrep("---|", length(inputs)))
)
for (name in functions) {
  cells <- vapply(timed[[name]], function(t) sprintf("%s (%s to %s)", ms(t[2]), ms(t[1]), ms(t[3])), "")
  report <- c(report, sprintf("| `%s()` | %s |", name, paste(cells, collapse = " | ")))
}

report <- c(report, "",
  "## Where the time goes: regex calls by pattern",
  "",
  paste0("Each cell is the time in that pattern's calls per call of the function, in ms, with the number of ",
    "calls in brackets; a call on no strings at all is not counted, and compiles nothing. The time is ",
    "taken with every regex call timed, so the totals run a little above the times above. ",
    "\"Outside regex calls\" is the rest of the call."),
  "")
for (name in functions) {
  rows <- broken_down[[name]]
  totals <- vapply(timed[[name]], function(t) t[2], 0)
  patterns_seen <- sort(unique(unlist(lapply(rows, function(r) r$pattern[!r$empty]))))
  report <- c(report, sprintf("### `%s()`", name), "",
    paste0("| Pattern | ", paste(input_header, collapse = " | "), " |"),
    paste0("|---|", strrep("---|", length(inputs))))
  for (pattern in patterns_seen) {
    cells <- vapply(rows, function(r) {
      hit <- r$pattern == pattern & !r$empty
      if (!any(hit)) "" else sprintf("%s (%d)", ms(sum(r$ms[hit])), sum(hit) %/% 51L)
    }, "")
    label <- if (startsWith(pattern, "built in")) pattern else sprintf("`%s`", pattern)
    report <- c(report, sprintf("| %s | %s |", label, paste(cells, collapse = " | ")))
  }
  all_regex <- vapply(rows, function(r) sum(r$ms[!r$empty]), 0)
  counted <- vapply(rows, function(r) sum(!r$empty) %/% 51L, 0L)
  empty <- vapply(rows, function(r) sum(r$empty) %/% 51L, 0L)
  report <- c(report,
    sprintf("| **All regex calls** | %s |", paste(sprintf("**%s (%d)**", ms(all_regex), counted), collapse = " | ")),
    sprintf("| Calls on no strings, not counted | %s |", paste(empty, collapse = " | ")),
    sprintf("| Outside regex calls | %s |", paste(ms(pmax(totals - all_regex, 0)), collapse = " | ")),
    "")
}

writeLines(report)
if (nzchar(args$out)) {
  writeLines(report, args$out)
}
