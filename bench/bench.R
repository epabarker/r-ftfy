# The benchmark against the reference version (issue #46, ADR 0008).
#
#   Rscript bench/bench.R [--python PATH] [--out FILE] [--label TEXT]
#     [--columns a,b] [--reps 7] [--full-reps 3] [--profile auto|always|never]
#     [--lib DIR]
#
# Runs the package (installed from this tree) and the reference version
# (ftfy 6.3.1 on Python 3.13) on the committed benchmark columns on this
# machine, checks that both give the same text for every value, and prints
# the time per value of each and the R to Python ratio. bench/README.md
# says exactly what is timed.
#
# Exit status: 0 when the bench ran and every output was equal, whatever the
# ratio; 1 when anything failed or an output differed.

local({
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  source(file.path(dirname(normalizePath(sub("^--file=", "", file_arg))), "common.R"))
})

root <- dirname(script_dir())
args <- parse_args(commandArgs(TRUE), list(
  python = Sys.getenv("FTFY_BENCH_PYTHON", ""),
  out = "",
  label = "Not the release-gate run.",
  columns = "",
  reps = "7",
  `full-reps` = "3",
  profile = "auto",
  lib = ""
))
reps <- as.integer(args$reps)
full_reps <- as.integer(args[["full-reps"]])
stopifnot(reps >= 1L, full_reps >= 1L, args$profile %in% c("auto", "always", "never"))

# The functions timed. The speed target is read on both; fix_text is the one
# users call on a column, so the whole-column figure is taken for it alone.
functions <- c("fix_text", "fix_encoding")
full_function <- "fix_text"

# ---------------------------------------------------------------------------
# The two sides

python <- args$python
if (!nzchar(python)) {
  python <- Sys.which(c("python3", "python"))
  python <- unname(python[nzchar(python)])[1]
  if (is.na(python)) {
    stop("no Python found: pass --python or set FTFY_BENCH_PYTHON")
  }
}
bench_py <- file.path(root, "bench", "bench.py")
python_info <- system2(python, c(shQuote(bench_py), "info"), stdout = TRUE)
if (!is.null(attr(python_info, "status"))) {
  stop("the reference version did not start; is ", python, " Python 3.13 with ftfy 6.3.1?")
}
python_info <- stats::setNames(sub("^[^\t]*\t", "", python_info), sub("\t.*$", "", python_info))

lib <- if (nzchar(args$lib)) args$lib else install_tree(root)
library(ftfy, lib.loc = lib)
stopifnot(startsWith(normalizePath(find.package("ftfy")), normalizePath(lib)))

table <- read_columns_table(root)
columns <- if (nzchar(args$columns)) strsplit(args$columns, ",", fixed = TRUE)[[1]] else table$column
stopifnot(all(columns %in% table$column))

work <- tempfile("ftfy-bench-")
dir.create(work)

# One run of the reference version: its times, and what it gave for every
# distinct value.
run_python <- function(column, fun, scope, reps) {
  status <- system2(python, c(shQuote(bench_py), "run", "--column", column, "--function", fun,
    "--scope", scope, "--reps", reps, "--out", shQuote(work)))
  if (status != 0L) {
    stop("the reference version failed on ", column, " (", fun, ", ", scope, ")")
  }
  stem <- file.path(work, paste0(column, ".", fun))
  list(
    seconds = as.numeric(readLines(paste0(stem, ".", scope, ".seconds.txt"))),
    output = stringi::stri_unescape_unicode(readLines(paste0(stem, ".output.txt"), encoding = "UTF-8"))
  )
}

# The same for R: one untimed call on the distinct values (the warm-up, and
# the result that is compared), then `reps` timed calls on `values`.
run_r <- function(f, distinct, values, expected_of, reps) {
  output <- f(distinct)
  expected <- expected_of(output)
  seconds <- numeric(reps)
  for (i in seq_len(reps)) {
    gc(FALSE)
    start <- now()
    result <- f(values)
    end <- now()
    seconds[[i]] <- end - start
    if (!identical(result, expected)) {
      stop("a repetition gave another result")
    }
  }
  list(seconds = seconds, output = output)
}

# ---------------------------------------------------------------------------
# Run

results <- list()
differences <- character(0)
values_checked <- 0L

compare <- function(column, fun, r_output, python_output, distinct) {
  if (length(r_output) != length(python_output)) {
    stop(column, ": ", length(python_output), " reference outputs for ", length(r_output), " values")
  }
  differing <- which(is.na(r_output) | r_output != python_output)
  values_checked <<- values_checked + length(r_output)
  if (length(differing) > 0L) {
    shown <- utils::head(differing, 5L)
    differences <<- c(differences, sprintf(
      "- `%s`, `%s`: %d of %d values differ. The first:\n%s", column, fun,
      length(differing), length(r_output),
      paste0(sprintf("  - value %d, input `%s`: R `%s`, reference `%s`", shown,
        stringi::stri_escape_unicode(distinct[shown]),
        stringi::stri_escape_unicode(r_output[shown]),
        stringi::stri_escape_unicode(python_output[shown])), collapse = "\n")))
  }
}

for (column in columns) {
  distinct <- read_distinct(root, column, table)
  n <- as.integer(table$n[table$column == column])
  message(sprintf("%s: %d values, %d distinct", column, n, length(distinct)))
  for (fun in functions) {
    f <- get(fun, envir = asNamespace("ftfy"))
    # The reference version and R back to back, so that both meet the same
    # state of the machine.
    py <- run_python(column, fun, "distinct", reps)
    r <- run_r(f, distinct, distinct, identity, reps)
    compare(column, fun, r$output, py$output, distinct)
    results[[length(results) + 1L]] <- list(column = column, fun = fun, scope = "distinct",
      count = length(distinct), python = py$seconds, r = r$seconds)
  }
  f <- get(full_function, envir = asNamespace("ftfy"))
  whole <- rep_len(distinct, n)
  py <- run_python(column, full_function, "full", full_reps)
  r <- run_r(f, distinct, whole, function(output) rep_len(output, n), full_reps)
  compare(column, full_function, r$output, py$output, distinct)
  results[[length(results) + 1L]] <- list(column = column, fun = full_function, scope = "full",
    count = n, python = py$seconds, r = r$seconds)
}

# ---------------------------------------------------------------------------
# Report

per_value <- function(seconds, count) {
  us <- 1e6 * seconds / count
  sprintf("%.2f (%.2f to %.2f)", stats::median(us), min(us), max(us))
}
ratio_of <- function(result) stats::median(result$r) / stats::median(result$python)
rows_of <- function(fun, scope) {
  Filter(function(result) result$fun == fun && result$scope == scope, results)
}
table_of <- function(fun, scope, counted) {
  rows <- rows_of(fun, scope)
  c(
    sprintf("| Column | %s | Python, us per value | R, us per value | R / Python | Range of the ratio | |",
      counted),
    "|---|---|---|---|---|---|---|",
    vapply(rows, function(result) {
      ratio <- ratio_of(result)
      sprintf("| `%s` | %s | %s | %s | **%.2f** | %.2f to %.2f | %s |", result$column,
        format(result$count, big.mark = ","), per_value(result$python, result$count),
        per_value(result$r, result$count), ratio,
        min(result$r) / max(result$python), max(result$r) / min(result$python),
        if (scope == "full") "" else if (ratio >= 1) "**AT OR ABOVE 1**" else "below 1")
    }, "")
  )
}

target_rows <- Filter(function(result) result$scope == "distinct", results)
over <- Filter(function(result) ratio_of(result) >= 1, target_rows)
over_text <- vapply(over, function(result) {
  sprintf("`%s` with `%s()` (%.2f)", result$column, result$fun, ratio_of(result))
}, "")

git <- function(...) {
  out <- tryCatch(suppressWarnings(system2("git", c("-C", shQuote(root), ...), stdout = TRUE,
    stderr = FALSE)), error = function(e) character(0))
  if (is.null(attr(out, "status"))) out else character(0)
}
commit <- git("rev-parse", "HEAD")
commit <- if (length(commit) == 1L) {
  paste0(commit, if (length(git("status", "--porcelain")) > 0L) " (with uncommitted changes)" else "")
} else {
  "unknown"
}
cpu <- tryCatch(
  if (Sys.info()[["sysname"]] == "Darwin") {
    system2("sysctl", c("-n", "machdep.cpu.brand_string"), stdout = TRUE)
  } else {
    sub("^[^:]*:\\s*", "", grep("^model name", readLines("/proc/cpuinfo"), value = TRUE)[1])
  },
  error = function(e) NA_character_, warning = function(w) NA_character_)
if (length(cpu) != 1L || is.na(cpu)) cpu <- "unknown"
icu <- stringi::stri_info()

headline <- if (length(differences) > 0L) {
  "**FAILED: R's output differs from the reference version's. The times below mean nothing.**"
} else if (length(over) > 0L) {
  paste0("**WARNING: the ratio is at or above 1 on ", paste(over_text, collapse = ", "),
    ".** The speed target of ADR 0008 is a ratio below 1 on every column.")
} else {
  "**The ratio is below 1 on every column, for both functions.**"
}

report <- c(
  "# Benchmark against the reference version",
  "",
  args$label,
  "",
  headline,
  "",
  sprintf("- Date: %s", format(Sys.time(), "%Y-%m-%d %H:%M UTC", tz = "UTC")),
  sprintf("- Commit: %s", commit),
  sprintf("- Machine: %s, %d cores, %s", cpu, parallel::detectCores(), R.version$platform),
  sprintf("- OS: %s", utils::sessionInfo()$running),
  sprintf("- R: %s", paste(R.version$major, R.version$minor, sep = ".")),
  sprintf("- stringi: %s, ICU %s (%s), Unicode %s", utils::packageVersion("stringi"),
    icu$ICU.version, if (isTRUE(icu$ICU.system)) "system" else "bundled", icu$Unicode.version),
  sprintf("- Python: %s (%s), ftfy %s, Unicode %s", python_info[["python"]],
    python_info[["implementation"]], python_info[["ftfy"]], python_info[["unicode"]]),
  sprintf("- Repetitions: %d (whole column: %d), after one untimed call. Each cell is the median, with the lowest and highest in brackets.",
    reps, full_reps),
  sprintf("- Outputs: %s", if (length(differences) > 0L) {
    "DIFFERENT, see below"
  } else {
    sprintf("R equals the reference version on all %s results compared",
      format(values_checked, big.mark = ","))
  }),
  "",
  if (length(differences) > 0L) c("## Outputs that differ", "", differences, ""),
  "## The speed target: time per distinct value, deduplication not counted",
  "",
  "Each distinct value of the column once. R: one call `f(values)`. Python: `[ftfy.f(v) for v in values]`.",
  "The ratio is R's median over Python's; its range is R's lowest over Python's highest to R's highest over Python's lowest.",
  "",
  unlist(lapply(functions, function(fun) {
    c(sprintf("### `%s()`", fun), "", table_of(fun, "distinct", "Distinct values"), "")
  })),
  "## As users call it: the whole column, repeats included",
  "",
  sprintf("A separate figure, not the speed target. The whole column of n values, the distinct values recycled. R: one call `%s(column)`, which fixes each distinct value once. Python: `[ftfy.%s(v) for v in column]`, which fixes every value.",
    full_function, full_function),
  "",
  table_of(full_function, "full", "Values (n)"),
  ""
)

to_profile <- switch(args$profile,
  never = list(),
  always = target_rows,
  auto = over)
if (length(differences) == 0L && length(to_profile) > 0L) {
  report <- c(report, "## Where R's time goes", "")
  for (result in to_profile) {
    message(sprintf("profiling %s on %s", result$fun, result$column))
    report <- c(report, profile_markdown(get(result$fun, envir = asNamespace("ftfy")),
      read_distinct(root, result$column, table),
      sprintf("`%s(values)` on the distinct values of `%s` (ratio %.2f)", result$fun,
        result$column, ratio_of(result))))
  }
}

writeLines(report)
if (nzchar(args$out)) {
  dir.create(dirname(args$out), recursive = TRUE, showWarnings = FALSE)
  writeLines(report, args$out)
  message("wrote ", args$out)
}
if (identical(Sys.getenv("GITHUB_ACTIONS"), "true")) {
  if (length(differences) > 0L) {
    cat("::error title=Benchmark::R's output differs from the reference version's\n")
  } else if (length(over) > 0L) {
    cat(sprintf("::warning title=Benchmark ratio at or above 1::%s\n",
      paste(gsub("`", "", over_text, fixed = TRUE), collapse = ", ")))
  }
}
if (length(differences) > 0L) {
  quit(status = 1L)
}
