# PROTOTYPE, throwaway. Correctness gate: the vectorised prototype against
# Python ftfy 6.3.1 fix_text on upstream's 161 JSON cases (from the
# research/upstream-observed-behaviour branch) and on the benchmark columns.
# Run from the scratch dir: Rscript gate.R <scratch> <python-output-all-cases.json>
args <- commandArgs(TRUE)
here <- dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(here, "proto.R"))
init_proto(args[1])
cases <- jsonlite::fromJSON(paste(readLines(args[2], warn = FALSE, encoding = "UTF-8"), collapse = "\n"), simplifyVector = FALSE)
orig <- vapply(cases, `[[`, "", "original")
want <- vapply(cases, `[[`, "", "fix_text")
expect <- vapply(cases, `[[`, "", "expect")
got <- fix_text_vec(orig)
ok <- got == want
cat(sprintf("JSON cases: %d/%d match Python fix_text (pass cases %d/%d)\n",
  sum(ok), length(ok), sum(ok & expect == "pass"), sum(expect == "pass")))
bad <- which(!ok)
for (b in head(bad, 40)) cat(sprintf("  [%d] %s\n      in : %s\n      py : %s\n      R  : %s\n", b - 1,
  cases[[b]]$label, encodeString(orig[b]), encodeString(want[b]), encodeString(got[b])))

# Plans: fix_and_explain is one segment, so feed whole strings as one segment.
pyplan <- vapply(cases, function(c) paste(vapply(c$fix_and_explain_plan, paste, "", collapse = " "), collapse = " > "), "")
pytext <- vapply(cases, `[[`, "", "fix_and_explain_text")
html <- !grepl("<", orig, fixed = TRUE)
r <- fix_segments(orig, html, record_plan = TRUE)
okp <- r$plan == pyplan & r$text == pytext
cat(sprintf("fix_and_explain: %d/%d match Python text and plan\n", sum(okp), length(okp)))
for (b in head(which(!okp), 10)) cat(sprintf("  [%d] py: %s\n       R : %s\n", b - 1, pyplan[b], r$plan[b]))
x <- jsonlite::fromJSON(paste(readLines(file.path(args[1], "columns", "names_n1e5.json"), warn = FALSE, encoding = "UTF-8"), collapse = ""))
u <- unique(x); h <- rep(TRUE, length(u))
t0 <- min(replicate(3, system.time(fix_segments(u, h, record_plan = FALSE))[[3]]))
t1 <- min(replicate(3, system.time(fix_segments(u, h, record_plan = TRUE))[[3]]))
cat(sprintf("plan recording on %d unique names: %.3fs without, %.3fs with\n", length(u), t0, t1))
