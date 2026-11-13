source("wt/research/vectorisation-speed/proto.R"); init_proto(".")
x <- jsonlite::fromJSON(paste(readLines("columns/notes_n1e4.json", encoding = "UTF-8", warn = FALSE), collapse = ""))
s <- unlist(strsplit(x, "\n")); s <- s[!stri_enc_isascii(s)]
cat("pattern chars:", nchar(P$bad), "\n")
# the frozen \w set is the longest bracket run; find it
m <- regmatches(P$bad, gregexpr("\\\\x\\{30\\}-\\\\x\\{39\\}[^]]*", P$bad))[[1]]
cat("frozen-set runs starting at 0-9:", length(m), "lengths", nchar(m), "\n")
p2 <- P$bad; for (r in m) p2 <- sub(r, "\\w", p2, fixed = TRUE)
a <- det(s, P$bad); t1 <- min(replicate(3, system.time(det(s, P$bad))[[3]]))
b <- det(s, p2); t2 <- min(replicate(3, system.time(det(s, p2))[[3]]))
cat(sprintf("frozen \\w: %.3fs  ICU \\w: %.3fs  same result: %s  (%d segments)\n", t1, t2, identical(a, b), length(s)))
writeLines(s, "notes_segments.txt", useBytes = TRUE)
