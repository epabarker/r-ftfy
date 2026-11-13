# PROTOTYPE, throwaway. Micro-probes for the sub-decisions in the ticket's
# comments: encode-table lookup, U+FEFF safety of hot-path functions, and the
# cost of locate-compute-splice. Run: Rscript probes.R <scratch dir>
args <- commandArgs(TRUE)
here <- dirname(sub("--file=", "", grep("--file=", commandArgs(FALSE), value = TRUE)))
source(file.path(here, "proto.R"))
dir <- args[1]
rd <- function(f) jsonlite::fromJSON(paste(readLines(f, warn = FALSE, encoding = "UTF-8"), collapse = "\n"))
best <- function(expr, reps = 5) {
  e <- substitute(expr); pf <- parent.frame()
  min(replicate(reps, system.time(eval(e, pf))[["elapsed"]]))
}

cat("== 1. Load-time cost of building encode tables and patterns\n")
cat(sprintf("init_proto(): %.3fs (includes reading data.json)\n", best(init_proto(dir), 3)))
cat(sprintf("encode tables only (11 chartr strings from 256-entry decode tables): %.4fs\n", best({
  for (e in names(P$tab)) { t <- P$tab[[e]]; b <- which(t >= 1) - 1L; b <- b[b >= 1]
    intToUtf8(t[b + 1L]); intToUtf8(b) }
}, 5)))

cat("\n== 2. Encode lookup: chartr vs integer lookup (sloppy-windows-1252)\n")
x <- rd(file.path(dir, "columns", "names_clean50_u20.json"))
x <- unique(x)
x <- x[det(x, P$enc_re[["sloppy-windows-1252"]]) & !stri_enc_isascii(x)]
cat(sprintf("%d strings encodable in sloppy-windows-1252\n", length(x)))
tab <- P$tab[["sloppy-windows-1252"]]
by_loop <- function(x) vapply(x, function(s) {
  cp <- utf8ToInt(s); intToUtf8(match(cp, tab) - 1L)
}, "", USE.NAMES = FALSE)
by_unlist <- function(x) {
  cps <- lapply(x, utf8ToInt) # utf8ToInt keeps U+FEFF; stri_enc_toutf32 strips it
  b <- match(unlist(cps, use.names = FALSE), tab) - 1L
  vapply(split(b, rep.int(seq_along(x), lengths(cps))), intToUtf8, "", USE.NAMES = FALSE)
}
by_chartr <- function(x) encode_chars(x, "sloppy-windows-1252")
r1 <- by_chartr(x); r2 <- by_loop(x); r3 <- by_unlist(x)
cat(sprintf("identical results: %s\n", identical(r1, r2) && identical(r1, r3)))
cat(sprintf("chartr          %.4fs  (%.2f us/value)\n", t <- best(by_chartr(x)), 1e6 * t / length(x)))
cat(sprintf("per-string int  %.4fs  (%.2f us/value)\n", t <- best(by_loop(x)), 1e6 * t / length(x)))
cat(sprintf("unlist int      %.4fs  (%.2f us/value)\n", t <- best(by_unlist(x)), 1e6 * t / length(x)))
b <- by_chartr(x)
cat(sprintf("bytes->UTF-8 (iconv to latin1, re-mark, stri_enc_isutf8): %.4fs (%.2f us/value)\n",
  t <- best(bytes_to_utf8(b)), 1e6 * t / length(x)))

cat("\n== 3. U+FEFF safety of hot-path functions\n")
s <- "﻿ab﻿cé"
n0 <- nchar(s)
chk <- function(name, ok) cat(sprintf("  %-55s %s\n", name, if (isTRUE(ok)) "keeps" else "LOSES/differs"))
chk("stri_detect_regex('^\\x{feff}')", det(s, "^\\x{feff}"))
chk("stri_replace_all_regex", identical(rep_all(s, "z", "y"), s))
chk("stri_replace_all_regex(vectorize_all = FALSE)", identical(stri_replace_all_regex(s, c("z", "q"), c("y", "w"), vectorize_all = FALSE, opts_regex = P$ro), s))
chk("stri_replace_all_fixed", identical(stri_replace_all_fixed(s, "z", "y"), s))
loc <- stri_locate_all_regex(s, "a", opts_regex = P$ro)[[1]]
chk("stri_locate_all_regex positions count U+FEFF", loc[1, 1] == 2)
chk("stri_split_regex('(?<=\\n)')", identical(paste(stri_split_regex(paste0(s, "\n", s), "(?<=\n)", opts_regex = P$ro)[[1]], collapse = ""), paste0(s, "\n", s)))
chk("stri_trans_nfc", identical(stri_trans_nfc(s), s))
chk("stri_enc_isascii (FALSE expected)", !stri_enc_isascii("﻿"))
chk("stri_enc_isutf8 on bytes EF BB BF", stri_enc_isutf8("﻿"))
chk("stri_sub(s, 1, -1)", identical(stri_sub(s, 1, -1), s))
chk("stri_join_list", identical(stri_join_list(list(c(s, s))), paste0(s, s)))
chk("base chartr", identical(chartr("z", "y", s), s))
chk("base substring", identical(substring(s, 1, n0), s))
chk("base nchar", n0 == 6)
chk("base paste0 / split+paste", identical(paste0(s, ""), s))
chk("base iconv UTF-8 -> UTF-8", identical(iconv(s, "UTF-8", "UTF-8"), s))
chk("base gsub(fixed = TRUE)", identical(gsub("z", "y", s, fixed = TRUE), s))
chk("prototype fix_text_vec keeps none (remove_control_chars drops all U+FEFF)", identical(fix_text_vec(s), "abcé"))
chk("prototype splice() with a match after U+FEFF", identical(splice(s, "b", function(m, id) toupper(m)), "﻿aB﻿cé"))

cat("\n== 4. Locate, compute, splice vs a plain regex replace (same pattern)\n")
set.seed(1)
y <- paste0("Caf", sample(c("&eacute;", "e", "&amp;", "&#233;"), 1e5, TRUE), " ", sample(c("ok", "&lt;b&gt;"), 1e5, TRUE))
cat(sprintf("splice(entity, compute)    %.4fs (%.2f us/value)\n", t <- best(unescape_html(y), 3), 1e6 * t / length(y)))
cat(sprintf("stri_replace_all_regex(..) %.4fs (%.2f us/value)  [lower bound, constant replacement]\n",
  t <- best(rep_all(y, P$entity, "X"), 3), 1e6 * t / length(y)))
z <- sample(y, 1e5, TRUE); z[sample(1e5, 9e4)] <- "nothing to do here"
cat(sprintf("splice on a 10%%-hit column  %.4fs (%.2f us/value)\n", t <- best(unescape_html(z), 3), 1e6 * t / length(z)))

cat("\n== 5. U+FEFF end to end with remove_control_chars off (prototype)\n")
saved <- FIXERS$remove_control_chars
FIXERS$remove_control_chars <- identity
for (v in c("﻿ab", "﻿ab\n﻿c", "﻿Ã©tÃ©", "x\n﻿Ã©")) {
  r <- fix_text_vec(v)
  cat(sprintf("  %-40s -> %-30s U+FEFF in %d, out %d\n", encodeString(v), encodeString(r),
    sum(utf8ToInt(v) == 0xfeff), sum(utf8ToInt(r) == 0xfeff)))
}
FIXERS$remove_control_chars <- saved
