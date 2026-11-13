library(stringi)
out <- commandArgs(TRUE)[1]
cat("stringi", as.character(packageVersion("stringi")), "ICU", stri_info()$ICU.version, "\n")
con <- file(out, "wb")
emit <- function(m) { # m: integer matrix, one sequence per row
  l <- lapply(seq_len(nrow(m)), function(i) as.raw(m[i, ]))
  writeBin(as.raw(stri_enc_isutf8(l)), con)
}
# 1-byte
emit(matrix(0:255, ncol = 1))
# 2-byte: b1 80..FF, b2 all
emit(as.matrix(expand.grid(b2 = 0:255, b1 = 128:255)[, 2:1]))
# 3-byte: b1 C0..FF
for (b1 in 192:255) emit(cbind(b1, as.matrix(expand.grid(b3 = 0:255, b2 = 0:255)[, 2:1])))
# 4-byte: b1 F0..FF, b2 all, b3/b4 boundary set
bs <- c(0x00, 0x7F, 0x80, 0x8F, 0x90, 0x9F, 0xA0, 0xBF, 0xC0, 0xFF)
for (b1 in 240:255) emit(cbind(b1, as.matrix(expand.grid(b4 = bs, b3 = bs, b2 = 0:255)[, 3:1])))
close(con)
