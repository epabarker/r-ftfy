# PROTOTYPE, throwaway. Rprof of the vectorised strategy, to see where time
# goes and whether any part is a candidate for compiled code.
# Run: Rscript profile.R <scratch dir> <column> [dedup: TRUE/FALSE]
args <- commandArgs(TRUE)
here <- dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(here, "proto.R"))
dir <- args[1]
init_proto(dir)
rd <- function(f) jsonlite::fromJSON(paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
x <- rd(file.path(dir, "columns", paste0(args[2], ".json")))
if (length(args) > 2 && as.logical(args[3])) x <- unique(x)
prof <- tempfile()
Rprof(prof, interval = 0.002)
for (i in 1:3) y <- fix_text_vec(x)
Rprof(NULL)
s <- summaryRprof(prof)
cat(sprintf("column %s, %d values, 3 runs\n\n== by self time\n", args[2], length(x)))
print(head(s$by.self, 15))
cat("\n== by total time (selected prototype functions)\n")
keep <- c("fix_text_vec", "fix_segments", "fix_encoding_explain", "fix_encoding_one_step", "det",
  "rep_all", "splice", "unescape_html", "encode_chars", "bytes_to_utf8", "only_if", "stri_trans_nfc",
  "vapply", "split", "substring", "stri_locate_all_regex", "chartr")
bt <- s$by.total
print(bt[rownames(bt) %in% paste0('"', keep, '"'), ])
