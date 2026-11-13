# PROTOTYPE, throwaway. A rough pure-R + stringi port of ftfy 6.3.1's default
# fix_text() path, written once over vectors. The strategies in bench.R differ
# only in how they call it. Not package code: no validation, rough edges noted.
#
# source("proto.R"); init_proto("<dir holding data.json>")

suppressPackageStartupMessages({
  library(stringi)
  library(jsonlite)
})

P <- new.env()

init_proto <- function(dir) {
  d <- fromJSON(paste(readLines(file.path(dir, "data.json"), warn = FALSE), collapse = ""), simplifyVector = TRUE)
  P$ro <- stri_opts_regex(unix_lines = TRUE, stack_limit = 1e9)
  rx <- function(p) p # patterns are already ICU-ready ASCII
  P$bad <- rx(d$badness_re)
  P$utf8det <- rx(d$utf8_detector_re)
  P$alt <- rx(d$altered_utf8_re)
  P$lossy <- rx(d$lossy_utf8_re)
  P$agrave <- rx(d$a_grave_word_re)
  P$c1 <- rx(d$c1_control_re)
  P$entity <- rx(d$html_entity_re)
  P$ansi <- rx(d$ansi_re)
  P$sq <- rx(d$single_quote_re)
  P$dq <- rx(d$double_quote_re)
  P$encs <- d$charmap_encodings
  P$enc_re <- d$encoding_regexes
  # Encode by chartr onto "byte characters" U+0001..U+00FF, built at load time
  # from the 256-entry decode tables (the shipped data). Byte 0 is skipped: no
  # R string holds U+0000.
  P$tab <- d$codec_tables
  P$enc_old <- P$enc_new <- list()
  for (e in names(P$tab)) {
    t <- P$tab[[e]]
    b <- which(t >= 1) - 1L # byte values with a decodable, non-NUL char
    b <- b[b >= 1]
    P$enc_old[[e]] <- intToUtf8(t[b + 1L])
    P$enc_new[[e]] <- intToUtf8(b)
  }
  # Lookup for the per-string integer-lookup encoder (alternative).
  P$enc_cp <- lapply(P$tab, function(t) t)
  P$ent_names <- names(d$html_entities)
  P$ent_vals <- unname(unlist(d$html_entities))
  P$lig_from <- names(d$ligatures)
  P$lig_to <- unname(unlist(d$ligatures))
  P$lig_class <- paste0("[", paste(sprintf("\\x{%x}", sapply(P$lig_from, utf8ToInt)), collapse = ""), "]")
  wm <- unlist(d$width_map)
  one <- nchar(wm) == 1
  P$width_from <- paste(names(wm)[one], collapse = "")
  P$width_to <- paste(wm[one], collapse = "")
  P$width_multi_from <- sprintf("\\x{%x}", vapply(names(wm)[!one], utf8ToInt, 1L))
  P$width_multi_to <- unname(wm[!one])
  P$width_from_all <- paste(names(wm), collapse = "")
  P$width_class <- paste0("[", paste(sprintf("\\x{%x}", utf8ToInt(P$width_from_all)), collapse = ""), "]")
  P$ctrl_class <- paste0("[", paste(sprintf("\\x{%x}", d$control_chars), collapse = ""), "]")
  # fix_c1_controls: each C1 char decoded as sloppy-windows-1252.
  s1252 <- P$tab[["sloppy-windows-1252"]]
  P$c1_from <- intToUtf8(0x80:0x9f)
  P$c1_to <- intToUtf8(s1252[0x80:0x9f + 1L])
  # Strict windows-1252 decode of bytes 80-9F (holes are -1).
  w <- P$tab[["windows-1252"]]
  P$w1252_holes <- intToUtf8(which(w[0x80:0x9f + 1L] < 0) + 0x7f)
  P$w1252_from <- intToUtf8((0x80:0x9f)[w[0x80:0x9f + 1L] >= 0])
  P$w1252_to <- intToUtf8(w[0x80:0x9f + 1L][w[0x80:0x9f + 1L] >= 0])
  invisible(TRUE)
}

det <- function(x, p) stri_detect_regex(x, p, opts_regex = P$ro)
rep_all <- function(x, p, r) stri_replace_all_regex(x, p, r, opts_regex = P$ro)
nchr <- function(x) nchar(x, type = "chars") # base R: keeps U+FEFF

# --- locate, compute, splice ------------------------------------------------
# Positions come from stri_locate_all_regex (keeps a leading U+FEFF) and the
# splice uses base substring() (also keeps it), never stri_sub().
splice <- function(x, pattern, compute) {
  loc <- stri_locate_all_regex(x, pattern, opts_regex = P$ro, omit_no_match = TRUE)
  k <- vapply(loc, nrow, 1L)
  if (!any(k)) return(x)
  id <- rep.int(seq_along(x), k)
  m <- do.call(rbind, loc)
  st <- m[, 1]; en <- m[, 2]
  matched <- substring(x[id], st, en)
  repl <- compute(matched, id)
  hit <- which(k > 0)
  # gaps: before each match, plus a tail per element
  first <- !duplicated(id)
  gap_st <- ifelse(first, 1L, c(NA, en[-length(en)] + 1L))
  pre <- substring(x[id], gap_st, st - 1L)
  tail <- substring(x[hit], en[cumsum(k[hit])] + 1L, nchr(x[hit]))
  pieces <- split(c(rbind(pre, repl)), rep(id, each = 2))
  out <- x
  out[hit] <- paste0(vapply(pieces, paste, "", collapse = ""), tail)
  out
}

# --- byte-character helpers (bytes held as code points U+0001..U+00FF) -----
encode_chars <- function(x, enc) chartr(P$enc_old[[enc]], P$enc_new[[enc]], x)

bytes_to_utf8 <- function(b) {
  y <- iconv(b, "UTF-8", "latin1")
  Encoding(y) <- "UTF-8"
  ok <- stri_enc_isutf8(y)
  y[!ok] <- NA_character_
  y
}

decode_variants <- function(b) {
  # Rough utf-8-variants: C0 80 (Java NUL) is dropped (ADR 0007); CESU-8
  # surrogate pairs become the code point.
  b <- rep_all(b, "\\x{c0}\\x{80}", "")
  b <- splice(b, "\\x{ed}[\\x{a0}-\\x{af}][\\x{80}-\\x{bf}]\\x{ed}[\\x{b0}-\\x{bf}][\\x{80}-\\x{bf}]",
    function(m, id) {
      v <- lapply(m, utf8ToInt)
      hi <- vapply(v, function(z) bitwAnd(z[2], 0x0f) * 64L + bitwAnd(z[3], 0x3f), 1L)
      lo <- vapply(v, function(z) bitwAnd(z[5], 0x0f) * 64L + bitwAnd(z[6], 0x3f), 1L)
      cp <- 0x10000L + hi * 1024L + lo
      enc <- vapply(cp, function(c) {
        y <- iconv(intToUtf8(c), "UTF-8", "UTF-8"); r <- charToRaw(y)
        intToUtf8(as.integer(r))
      }, "")
      enc
    })
  bytes_to_utf8(b)
}

restore_byte_a0 <- function(b) {
  b <- rep_all(b, P$agrave, "Ã  ")
  splice(b, P$alt, function(m, id) gsub(" ", " ", m, fixed = TRUE))
}

replace_lossy <- function(b) rep_all(b, P$lossy, "ï¿½")

# --- one step of fix_encoding, vectorised over x -----------------------------
# Returns list(text, steps) where steps is "" for no change.
fix_encoding_one_step <- function(x) {
  n <- length(x)
  out <- x
  steps <- character(n)
  todo <- nzchar(x) & !stri_enc_isascii(x)
  if (any(todo)) todo[todo] <- det(x[todo], P$bad)
  poss <- matrix(FALSE, n, length(P$encs), dimnames = list(NULL, P$encs))
  for (enc in P$encs) {
    i <- which(todo)
    if (!length(i)) break
    p <- det(x[i], P$enc_re[[enc]])
    poss[i, enc] <- p
    i <- i[p]
    if (!length(i)) next
    b <- encode_chars(x[i], enc)
    st <- rep(paste0("encode ", enc), length(i))
    if (enc != "macroman") {
      a <- det(b, P$alt)
      if (any(a)) {
        r <- restore_byte_a0(b[a])
        ch <- r != b[a]
        b[a][ch] <- r[ch]
        st[a][ch] <- paste0(st[a][ch], " > transcode restore_byte_a0")
      }
    }
    if (startsWith(enc, "sloppy")) {
      r <- replace_lossy(b)
      ch <- r != b
      b[ch] <- r[ch]
      st[ch] <- paste0(st[ch], " > transcode replace_lossy_sequences")
    }
    var <- grepl("[íÀ]", b)
    dec <- rep(NA_character_, length(b))
    if (any(!var)) dec[!var] <- bytes_to_utf8(b[!var])
    if (any(var)) dec[var] <- decode_variants(b[var])
    ok <- !is.na(dec)
    j <- i[ok]
    out[j] <- dec[ok]
    steps[j] <- paste0(st[ok], ifelse(var[ok], " > decode utf-8-variants", " > decode utf-8"))
    todo[j] <- FALSE
  }
  # decode_inconsistent_utf8
  i <- which(todo)
  if (length(i)) {
    d <- det(x[i], P$utf8det)
    i <- i[d]
    if (length(i)) {
      xi <- x[i]
      len <- nchr(xi)
      f <- splice(xi, P$utf8det, function(m, id) {
        use <- nchr(m) < len[id] & det(m, P$bad)
        if (any(use)) m[use] <- fix_encoding(m[use])
        m
      })
      ch <- f != xi
      out[i[ch]] <- f[ch]
      steps[i[ch]] <- "apply decode_inconsistent_utf8"
      todo[i[ch]] <- FALSE
    }
  }
  # Latin-1 that was meant as Windows-1252 ('windows-1252' is never in the
  # possible list upstream, so this branch is always taken for latin-1).
  i <- which(todo & poss[, "latin-1"])
  if (length(i)) {
    xi <- x[i]
    fails <- grepl(paste0("[", P$w1252_holes, "]"), xi)
    f <- chartr(P$w1252_from, P$w1252_to, xi)
    ch <- !fails & f != xi
    out[i[ch]] <- f[ch]
    steps[i[ch]] <- "encode latin-1 > decode windows-1252"
    todo[i[ch]] <- FALSE # upstream returns only when the text changed
  }
  i <- which(todo)
  if (length(i)) {
    c1 <- det(x[i], P$c1)
    i <- i[c1]
    if (length(i)) {
      out[i] <- chartr(P$c1_from, P$c1_to, x[i])
      steps[i] <- "transcode fix_c1_controls"
    }
  }
  list(text = out, steps = steps)
}

fix_encoding_explain <- function(x) {
  plan <- character(length(x))
  active <- seq_along(x)
  while (length(active)) {
    r <- fix_encoding_one_step(x[active])
    ch <- r$text != x[active]
    hasstep <- nzchar(r$steps)
    plan[active[hasstep]] <- ifelse(nzchar(plan[active[hasstep]]),
      paste(plan[active[hasstep]], r$steps[hasstep], sep = " > "), r$steps[hasstep])
    x[active] <- r$text
    active <- active[ch]
  }
  list(text = x, plan = plan)
}
fix_encoding <- function(x) fix_encoding_explain(x)$text

# --- the other fixers -------------------------------------------------------
html_numeric <- function(m) {
  hex <- grepl("^&#[xX]", m)
  num <- sub(";$", "", sub("^&#[xX]?", "", m))
  cp <- suppressWarnings(ifelse(hex, strtoi(num, 16L), strtoi(num, 10L)))
  cp[is.na(cp)] <- -1L
  w <- P$tab[["windows-1252"]]
  c1 <- cp >= 0x80 & cp <= 0x9f
  cp[c1] <- ifelse(w[cp[c1] + 1L] >= 0, w[cp[c1] + 1L], cp[c1])
  bad <- cp <= 0 | cp > 0x10ffff | (cp >= 0xd800 & cp <= 0xdfff)
  cp[bad] <- 0xfffd
  out <- vapply(cp, intToUtf8, "")
  out[!grepl("^[0-9a-fA-F]+$", num) | (!hex & !grepl("^[0-9]+$", num))] <- m[!grepl("^[0-9a-fA-F]+$", num) | (!hex & !grepl("^[0-9]+$", num))]
  out
}

unescape_html <- function(x) {
  i <- which(grepl("&", x, fixed = TRUE))
  if (!length(i)) return(x)
  x[i] <- splice(x[i], P$entity, function(m, id) {
    out <- m
    k <- match(m, P$ent_names)
    out[!is.na(k)] <- P$ent_vals[k[!is.na(k)]]
    num <- is.na(k) & startsWith(m, "&#")
    if (any(num)) {
      u <- html_numeric(m[num])
      u[grepl(";", u, fixed = TRUE)] <- m[num][grepl(";", u, fixed = TRUE)]
      out[num] <- u
    }
    out
  })
  x
}

only_if <- function(x, screen, f) {
  i <- which(screen(x))
  if (length(i)) x[i] <- f(x[i])
  x
}

FIXERS <- list(
  fix_c1_controls = function(x) only_if(x, function(s) det(s, P$c1), function(s) chartr(P$c1_from, P$c1_to, s)),
  fix_latin_ligatures = function(x) only_if(x, function(s) det(s, P$lig_class), function(s)
    stri_replace_all_regex(s, sprintf("\\x{%x}", sapply(P$lig_from, utf8ToInt)), P$lig_to,
      vectorize_all = FALSE, opts_regex = P$ro)),
  fix_character_width = function(x) only_if(x, function(s) det(s, P$width_class), function(s) {
    s <- chartr(P$width_from, P$width_to, s)
    if (length(P$width_multi_from)) s <- stri_replace_all_regex(s, P$width_multi_from, P$width_multi_to,
      vectorize_all = FALSE, opts_regex = P$ro)
    s
  }),
  uncurl_quotes = function(x) only_if(x, function(s) det(s, "[\\x{2bc}\\x{2018}-\\x{201f}]"),
    function(s) rep_all(rep_all(s, P$dq, '"'), P$sq, "'")),
  fix_line_breaks = function(x) only_if(x, function(s) det(s, "[\\r\\x{2028}\\x{2029}\\x{85}]"),
    function(s) rep_all(s, "\\r\\n|[\\r\\x{2028}\\x{2029}\\x{85}]", "\n")),
  remove_terminal_escapes = function(x) only_if(x, function(s) grepl("\033", s, fixed = TRUE), function(s) rep_all(s, P$ansi, "")),
  remove_control_chars = function(x) only_if(x, function(s) det(s, P$ctrl_class), function(s) rep_all(s, P$ctrl_class, ""))
)

# --- fix_and_explain over a vector of segments --------------------------------
# `html` is a logical per segment: whether unescape_html is still "auto"-on.
fix_segments <- function(x, html, record_plan = TRUE) {
  plan <- character(length(x))
  add <- function(idx, step) {
    if (!record_plan || !length(idx)) return()
    plan[idx] <<- ifelse(nzchar(plan[idx]), paste(plan[idx], step, sep = " > "), step)
  }
  active <- seq_along(x)
  while (length(active)) {
    orig <- t <- x[active]
    h <- html[active]
    if (any(h)) {
      f <- unescape_html(t[h]); ch <- f != t[h]
      add(active[h][ch], "apply unescape_html"); t[h] <- f
    }
    e <- fix_encoding_explain(t)
    ch <- nzchar(e$plan)
    add(active[ch], e$plan[ch])
    t <- e$text
    for (nm in names(FIXERS)) {
      f <- FIXERS[[nm]](t); ch <- f != t
      add(active[ch], paste0("apply ", nm)); t <- f
    }
    na <- which(!stri_enc_isascii(t))
    if (length(na)) {
      f <- stri_trans_nfc(t[na]); ch <- f != t[na]
      add(active[na][ch], "normalize NFC"); t[na] <- f
    }
    x[active] <- t
    active <- active[t != orig]
  }
  list(text = x, plan = plan)
}

# Fast path: a segment that is printable ASCII (plus tab and newline) with no
# '&' cannot be changed by any default fixer.
FAST_CLEAN <- "^[\\x{20}-\\x{25}\\x{27}-\\x{7e}\\t\\n]*$"

# --- fix_text over a character vector ----------------------------------------
# Splits each element into line segments (each keeps its '\n'), flattens them,
# fixes all segments together and re-joins. max_decode_length is ignored here.
fix_text_vec <- function(x, fast_path = TRUE) {
  out <- x
  ok <- !is.na(x)
  xx <- x[ok]
  if (fast_path) {
    clean <- det(xx, FAST_CLEAN)
  } else {
    clean <- rep(FALSE, length(xx))
  }
  w <- which(!clean)
  if (length(w)) {
    # stri_split_regex() strips a U+FEFF at the start of its input, so split
    # with locate + base substring(), which both keep it.
    xw <- xx[w]
    len <- nchr(xw)
    loc <- stri_locate_all_regex(xw, "\n", opts_regex = P$ro, omit_no_match = TRUE)
    nl <- vapply(loc, nrow, 1L)
    nlid <- rep.int(seq_along(w), nl)
    nlend <- unlist(lapply(loc, function(m) m[, 2]), use.names = FALSE)
    # segment ends: each newline, plus the string end when it isn't a newline
    tail_needed <- len > 0 & (nl == 0 | vapply(loc, function(m) if (nrow(m)) m[nrow(m), 2] else 0L, 1L) < len)
    id <- c(nlid, which(tail_needed))
    en <- c(nlend, len[tail_needed])
    o <- order(id, en)
    id <- id[o]; en <- en[o]
    st <- ifelse(!duplicated(id), 1L, c(NA, en[-length(en)]) + 1L)
    k <- tabulate(id, length(w))
    s <- substring(xw[id], st, en)
    # unescape_html "auto": off for a segment containing '<' and every later one
    lt <- grepl("<", s, fixed = TRUE)
    html <- ave(as.integer(lt), id, FUN = cumsum) == 0
    if (length(s)) {
      if (fast_path) {
        need <- !det(s, FAST_CLEAN)
      } else {
        need <- rep(TRUE, length(s))
      }
      if (any(need)) s[need] <- fix_segments(s[need], html[need], record_plan = FALSE)$text
    }
    joined <- rep("", length(w))
    if (length(s)) {
      jj <- vapply(split(s, factor(id, levels = seq_along(w))), paste, "", collapse = "")
      joined <- unname(jj)
    }
    xx[w] <- joined
  }
  out[ok] <- xx
  out
}
