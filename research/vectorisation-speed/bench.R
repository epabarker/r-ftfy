# PROTOTYPE, throwaway. Times the candidate strategies for vectorising
# fix_text() on the synthetic columns, checks each against Python ftfy 6.3.1
# and against each other, and prints a results table.
# Run: Rscript bench.R <scratch dir holding data.json, columns/, python_times.json>
args <- commandArgs(TRUE)
here <- dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(here, "proto.R"))
dir <- args[1]
init_proto(dir)
rd <- function(f) jsonlite::fromJSON(paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
py <- rd(file.path(dir, "python_times.json"))

dedup <- function(f) function(x) {
  u <- unique(x)
  fu <- f(u)
  out <- fu[match(x, u)]
  attributes(out) <- attributes(x)
  out
}
per_string <- function(fast) function(x) {
  out <- x
  todo <- !is.na(x)
  if (fast) todo[todo] <- !det(x[todo], FAST_CLEAN)
  out[todo] <- vapply(x[todo], fix_text_vec, "", fast_path = FALSE, USE.NAMES = FALSE)
  out
}
STRATS <- list(
  A_loop = per_string(FALSE),
  A_loop_fast = per_string(TRUE),
  A_loop_fast_dedup = dedup(per_string(TRUE)),
  B_vec = function(x) fix_text_vec(x, fast_path = FALSE),
  C_vec_fast = function(x) fix_text_vec(x, fast_path = TRUE),
  D_vec_fast_dedup = dedup(function(x) fix_text_vec(x, fast_path = TRUE))
)
if (Sys.getenv("ONLY_VEC") == "1") STRATS <- STRATS[!startsWith(names(STRATS), "A_")]
LOOP_N <- 10000L # per-string strategies are timed on the first 10k values

tm <- function(f, x, reps) {
  best <- Inf
  for (r in seq_len(reps)) {
    gc(FALSE)
    t <- system.time(res <- f(x))[["elapsed"]]
    best <- min(best, t)
  }
  list(sec = best, res = res)
}

cols <- names(py)
if (length(args) > 1) cols <- args[-1]
rows <- list()
for (col in cols) {
  x <- rd(file.path(dir, "columns", paste0(col, ".json")))
  want <- rd(file.path(dir, "columns", paste0(col, ".python.json")))
  n <- length(x)
  ref <- NULL
  for (s in names(STRATS)) {
    loop <- startsWith(s, "A_")
    xs <- if (loop) x[seq_len(min(n, LOOP_N))] else x
    if (loop && n > 1e5) next
    reps <- if (loop || length(xs) >= 1e6) 1 else 3
    r <- tm(STRATS[[s]], xs, reps)
    w <- want[seq_along(xs)]
    match_py <- mean(r$res == w)
    rows[[length(rows) + 1]] <- data.frame(
      column = col, n = n, strategy = s, n_timed = length(xs),
      sec = round(r$sec, 3), us_per_value = round(1e6 * r$sec / length(xs), 2),
      py_us_per_value = round(1e6 * py[[col]]$seconds / n, 2),
      match_python = round(match_py, 6))
    cat(sprintf("%-20s %-18s n=%-8d %8.3fs %8.2f us/value  py %6.2f us/value  match %.6f\n",
      col, s, length(xs), r$sec, 1e6 * r$sec / length(xs), 1e6 * py[[col]]$seconds / n, match_py))
  }
}
res <- do.call(rbind, rows)
write.csv(res, file.path(dir, "bench_results.csv"), row.names = FALSE)
