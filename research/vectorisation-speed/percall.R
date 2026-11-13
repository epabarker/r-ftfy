# PROTOTYPE, throwaway. Fixed cost per call: is it regex compilation?
# Also: pass-throughs (NA, names, dim, dimnames) through strategy D.
args <- commandArgs(TRUE)
here <- dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(here, "proto.R")); init_proto(args[1])
x1 <- "FranÃ§ois MÃ¼ller"
xs <- rep(x1, 1000)
t <- function(e) { e <- substitute(e); pf <- parent.frame(); min(replicate(3, system.time(eval(e, pf))[[3]])) }
small <- "[\\x{2bc}\\x{2018}-\\x{201f}]"
cat(sprintf("BADNESS_RE (%d chars): 1000 x length-1 calls %.3fs | 1 call on length-1000 %.4fs\n",
  nchar(P$bad), t(for (i in 1:1000) det(x1, P$bad)), t(det(xs, P$bad))))
cat(sprintf("small class pattern:        1000 x length-1 calls %.3fs | 1 call on length-1000 %.4fs\n",
  t(for (i in 1:1000) det(x1, small)), t(det(xs, small))))
enc <- P$enc_re[["sloppy-windows-1252"]]
cat(sprintf("encoding regex (%d chars):  1000 x length-1 calls %.3fs\n", nchar(enc), t(for (i in 1:1000) det(x1, enc))))
cat(sprintf("UTF8_DETECTOR (%d chars):   1000 x length-1 calls %.3fs\n", nchar(P$utf8det), t(for (i in 1:1000) det(x1, P$utf8det))))
cat(sprintf("fix_text_vec on one mojibake string: %.0f us per call\n", 1e3 * t(for (i in 1:1000) fix_text_vec(x1))))
cat(sprintf("fix_text_vec on one clean non-ASCII string: %.0f us per call\n", 1e3 * t(for (i in 1:1000) fix_text_vec("François"))))
cat(sprintf("fix_text_vec on one ASCII string (fast path): %.0f us per call\n", 1e3 * t(for (i in 1:1000) fix_text_vec("Patient 12"))))
for (n in c(1, 2, 5, 10, 20, 50, 100, 1000)) {
  v <- rep_len(c(x1, "François", "Zoë Nowak", "O’Brien"), n)
  v <- paste(v, seq_len(n)) # all unique
  reps <- max(1, 2000 %/% n)
  cat(sprintf("  n=%-5d %8.1f us per value\n", n, 1e6 * t(for (i in 1:reps) fix_text_vec(v)) / (reps * n)))
}
cat("\n== pass-throughs through strategy D\n")
D <- function(x) { u <- unique(x); out <- fix_text_vec(u)[match(x, u)]; attributes(out) <- attributes(x); out }
m <- matrix(c("cafÃ©", NA, "ok", "cafÃ©", "", "x\nÃ©"), 2,
  dimnames = list(c("r1", "r2"), c("a", "b", "c")))
r <- D(m)
print(r)
cat(sprintf("dim kept %s, dimnames kept %s, NA kept %s\n", identical(dim(r), dim(m)), identical(dimnames(r), dimnames(m)), is.na(r[2, 1])))
v <- c(a = "cafÃ©", b = NA, c = "cafÃ©")
r <- D(v); print(r); cat(sprintf("names kept %s\n", identical(names(r), names(v))))
cat(sprintf("grepl(fixed = TRUE) sees a leading U+FEFF: %s\n", grepl("﻿", "﻿ab", fixed = TRUE)))
