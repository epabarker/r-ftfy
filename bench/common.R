# What bench.R and profile.R share: finding the repository, reading the
# committed benchmark columns, installing the package from this tree, the
# clock, and the Rprof breakdown. See bench/README.md.

# The directory of the script Rscript is running.
script_dir <- function() {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_arg) != 1L) {
    stop("run this with Rscript")
  }
  dirname(normalizePath(sub("^--file=", "", file_arg)))
}

# `--key value` arguments as a named list; `defaults` names the known keys.
parse_args <- function(args, defaults) {
  out <- defaults
  i <- 1L
  while (i <= length(args)) {
    key <- sub("^--", "", args[[i]])
    if (!startsWith(args[[i]], "--") || !key %in% names(defaults) || i == length(args)) {
      stop("unknown or incomplete argument: ", args[[i]],
        "\nknown: ", paste0("--", names(defaults), collapse = " "))
    }
    out[[key]] <- args[[i + 1L]]
    i <- i + 2L
  }
  out
}

read_columns_table <- function(root) {
  utils::read.delim(file.path(root, "bench", "columns", "columns.tsv"),
    quote = "", colClasses = "character", stringsAsFactors = FALSE)
}

# The distinct values of a committed column, checked against the md5 that
# columns.tsv gives for the uncompressed text.
read_distinct <- function(root, column, table = read_columns_table(root)) {
  row <- table[table$column == column, ]
  if (nrow(row) != 1L) {
    stop("no benchmark column named ", column)
  }
  connection <- xzfile(file.path(root, "bench", "columns", paste0(column, ".txt.xz")), "rb")
  bytes <- raw(0)
  repeat {
    chunk <- readBin(connection, "raw", 2^24)
    if (length(chunk) == 0L) break
    bytes <- c(bytes, chunk)
  }
  close(connection)
  plain <- tempfile()
  on.exit(unlink(plain))
  writeBin(bytes, plain)
  found <- unname(tools::md5sum(plain))
  if (!identical(found, row$md5)) {
    stop(column, ": md5 ", found, ", columns.tsv says ", row$md5)
  }
  values <- stringi::stri_unescape_unicode(readLines(plain, encoding = "UTF-8"))
  stopifnot(length(values) == as.integer(row$distinct), !anyDuplicated(values), !anyNA(values))
  values
}

# Installs the package from this tree into a library of its own, so that
# what is timed is byte-compiled as a user's installed copy is.
install_tree <- function(root, lib = tempfile("ftfy-bench-lib-")) {
  dir.create(lib, recursive = TRUE, showWarnings = FALSE)
  log <- tempfile()
  status <- system2(file.path(R.home("bin"), "R"),
    c("CMD", "INSTALL", "--no-docs", "--no-html", paste0("--library=", shQuote(lib)), shQuote(root)),
    stdout = log, stderr = log)
  if (status != 0L) {
    writeLines(readLines(log))
    stop("R CMD INSTALL of the tree failed")
  }
  lib
}

# Seconds, with microseconds. proc.time() is rounded down to milliseconds
# on Unix, which is too coarse for the small columns.
now <- function() as.numeric(Sys.time())

# The lines of a report that say where it was run: the commit, the machine
# (its CPU model, never a host or user name), OS, R, stringi and ICU.
machine_lines <- function(root) {
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
  c(
    sprintf("- Commit: %s", commit),
    sprintf("- Machine: %s, %d cores, %s", cpu, parallel::detectCores(), R.version$platform),
    sprintf("- OS: %s", utils::sessionInfo()$running),
    sprintf("- R: %s", paste(R.version$major, R.version$minor, sep = ".")),
    sprintf("- stringi: %s, ICU %s (%s), Unicode %s", utils::packageVersion("stringi"),
      icu$ICU.version, if (isTRUE(icu$ICU.system)) "system" else "bundled", icu$Unicode.version)
  )
}

# ---------------------------------------------------------------------------
# The Rprof breakdown of ADR 0008: where the time of `f(values)` goes.

profile_buckets <- c(
  stringi = "stringi: its C code and ICU",
  base = "base R functions (compiled: chartr, iconv, substring, match, unique, ...)",
  package = "the package's own R code (interpreted)",
  gc = "R's garbage collector",
  other = "other (anonymous functions, other packages)"
)

bucket_of <- function(names, ftfy_namespace) {
  vapply(sub("^[A-Za-z0-9.]+:::?", "", names), function(name) {
    if (identical(name, "<GC>")) {
      "gc"
    } else if (exists(name, envir = asNamespace("stringi"), inherits = FALSE)) {
      "stringi"
    } else if (exists(name, envir = ftfy_namespace, inherits = FALSE)) {
      "package"
    } else if (exists(name, envir = baseenv(), inherits = FALSE)) {
      "base"
    } else {
      "other"
    }
  }, "", USE.NAMES = FALSE)
}

# Profiles repeated calls of `f(values)` for about `seconds` and returns the
# breakdown as Markdown lines.
profile_markdown <- function(f, values, title, seconds = 8, interval = 0.01) {
  ftfy_namespace <- environment(f)
  invisible(f(values))
  log <- tempfile()
  on.exit(unlink(log))
  gc(FALSE)
  calls <- 0L
  started <- now()
  Rprof(log, interval = interval, gc.profiling = TRUE)
  while (now() - started < seconds || calls < 3L) {
    invisible(f(values))
    calls <- calls + 1L
  }
  Rprof(NULL)
  elapsed <- now() - started
  summary <- summaryRprof(log)
  self <- summary$by.self
  names_self <- gsub("^\"|\"$", "", rownames(self))
  total_time <- summary$sampling.time
  bucket <- bucket_of(names_self, ftfy_namespace)
  share <- function(time) sprintf("%.1f%%", 100 * time / total_time)

  by_bucket <- tapply(self$self.time, factor(bucket, names(profile_buckets)), sum)
  by_bucket[is.na(by_bucket)] <- 0
  icu <- by_bucket[["stringi"]]
  regex <- sum(self$self.time[bucket == "stringi" & grepl("_regex$", names_self)])

  lines <- c(
    sprintf("#### `Rprof` breakdown: %s", title),
    "",
    sprintf(paste0("%d calls in %.1f s (%.1f ms per call), sampled every %g ms: %d samples, ",
      "%.2f s of sampled time. Shares are of self time: the time spent in a ",
      "function itself and not in what it calls."),
      calls, elapsed, 1000 * elapsed / calls, 1000 * interval,
      as.integer(round(total_time / summary$sample.interval)), total_time),
    "",
    "| Where | Share of run time |",
    "|---|---|",
    sprintf("| %s | %s |", profile_buckets, share(by_bucket[names(profile_buckets)])),
    "",
    sprintf(paste0("**ICU side (stringi): %s. R side (everything else): %s.** ",
      "Of the stringi time, the regex functions (`stri_*_regex`) are %s of run time. ",
      "ADR 0008's condition for compiled code is R-level code above 50%%."),
      share(icu), share(total_time - icu), share(regex)),
    "",
    "Self time by function, the 12 largest:",
    "",
    "| Function | Where | Self time | Share |",
    "|---|---|---|---|"
  )
  top <- utils::head(order(-self$self.time), 12L)
  lines <- c(lines, sprintf("| `%s` | %s | %.2f s | %s |", names_self[top], bucket[top],
    self$self.time[top], share(self$self.time[top])))

  total <- summary$by.total
  names_total <- gsub("^\"|\"$", "", rownames(total))
  own <- which(bucket_of(names_total, ftfy_namespace) == "package")
  own <- utils::head(own[order(-total$total.time[own])], 15L)
  c(lines, "",
    "Total time (the function and everything it calls) of the package's own functions, the 15 largest:",
    "",
    "| Function | Total time | Share |",
    "|---|---|---|",
    sprintf("| `%s` | %.2f s | %s |", names_total[own], total$total.time[own],
      share(total$total.time[own])),
    "")
}
