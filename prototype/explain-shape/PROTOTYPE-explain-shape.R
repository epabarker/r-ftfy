# PROTOTYPE - throwaway. Not package code. For issue #9,
# "Shape of the explain output".
#
# Question: what does fix_and_explain() return in R, and what does
# apply_plan() accept? Three candidate shapes for a plan, run through the
# same scenarios, then three behaviour choices that do not depend on shape.
#
# What is real and what is faked:
#  - fix_and_explain() is a LOOKUP into Python ftfy 6.3.1's captured output
#    for the 161 upstream JSON cases (python-output-all-cases.json), plus
#    two hand-entered results observed in issue #18. Nothing is detected.
#  - apply_plan() really replays these steps: encode latin-1, encode
#    sloppy-windows-1252, decode utf-8, apply uncurl_quotes, transcode
#    fix_c1_controls, normalize NFC. Any other step stops the script.
#
# Run from the repo root:
#   Rscript prototype/explain-shape/PROTOTYPE-explain-shape.R

suppressPackageStartupMessages(library(stringi))
options(width = 100)
args <- commandArgs(FALSE)
here <- dirname(sub("^--file=", "", args[grep("^--file=", args)]))
cases <- jsonlite::fromJSON(file.path(here, "python-output-all-cases.json"),
                            simplifyVector = FALSE)

# ---- shared engine ----------------------------------------------------
originals <- vapply(cases, function(c) c$original, "")
py_text   <- vapply(cases, function(c) c$fix_and_explain_text, "")
py_pairs  <- lapply(cases, function(c) lapply(c$fix_and_explain_plan, unlist))

extra <- list(   # observed on ftfy 6.3.1 in issue #18
  list("é", "é", list(c("normalize", "NFC"))),
  list("a\u0081b", "a\u0081b", list(c("transcode", "fix_c1_controls")))
)

# one string in -> list(text, pairs); pairs is upstream's [(action, parameter)]
lookup1 <- function(s) {
  if (is.na(s)) return(list(text = NA_character_, pairs = NULL))
  for (e in extra) if (identical(s, e[[1]])) return(list(text = e[[2]], pairs = e[[3]]))
  i <- match(s, originals)
  if (is.na(i)) return(list(text = s, pairs = list()))
  list(text = py_text[i], pairs = py_pairs[[i]])
}

cp1252_hi <- vapply(0x80:0x9f, function(b) {
  u <- suppressWarnings(iconv(rawToChar(as.raw(b)), "CP1252", "UTF-8"))
  if (is.na(u)) b else utf8ToInt(u)
}, 0)

fail <- function(msg) stop(structure(class = c("replay_failure", "error", "condition"),
                                     list(message = msg, call = NULL)))

run_step <- function(state, action, param, allow_normalize) {
  key <- paste(action, param)
  if (key == "encode latin-1") {
    cp <- utf8ToInt(state)
    if (any(cp > 0xff)) fail("cannot encode to latin-1")
    return(as.raw(cp))
  }
  if (key == "encode sloppy-windows-1252") {
    cp <- utf8ToInt(state)
    hi <- match(cp, cp1252_hi)
    b <- ifelse(!is.na(hi), 0x7f + hi, cp)
    if (any(b > 0xff) || any(is.na(hi) & cp >= 0x80 & cp <= 0x9f))
      fail("cannot encode to sloppy-windows-1252")
    return(as.raw(b))
  }
  if (key == "decode utf-8") {
    s <- rawToChar(state)
    if (!validUTF8(s)) fail("bytes are not valid utf-8")
    Encoding(s) <- "UTF-8"
    return(s)
  }
  if (key == "apply uncurl_quotes") {
    s <- gsub("[‘’‚‛ʼ]", "'", state)
    return(gsub("[“”„‟]", "\"", s))
  }
  if (key == "transcode fix_c1_controls") {
    cp <- utf8ToInt(state)
    c1 <- cp >= 0x80 & cp <= 0x9f
    cp[c1] <- cp1252_hi[cp[c1] - 0x7f]
    return(intToUtf8(cp))
  }
  if (action == "normalize") {
    if (!allow_normalize) stop("Unknown plan step: normalize", call. = FALSE)
    return(stri_trans_nfc(state))
  }
  stop("PROTOTYPE: step not stubbed: ", key, call. = FALSE)
}

# on_failure: "error" (upstream), "na", or "unchanged"
replay1 <- function(s, pairs, on_failure = "error", allow_normalize = TRUE) {
  if (is.na(s) || is.null(pairs)) return(NA_character_)
  go <- function() {
    for (p in pairs) s <- run_step(s, p[1], p[2], allow_normalize)
    s
  }
  switch(on_failure,
    error = go(),
    na = tryCatch(go(), replay_failure = function(e) NA_character_),
    unchanged = tryCatch(go(), replay_failure = function(e) s))
}

# ---- Design A: bare lists (closest port of upstream) --------------------
# result: list(text = <chr>, explanation = <list of plans>)
# plan:   list of c(action, parameter), exactly upstream's shape
A <- list(
  fix_and_explain = function(x) {
    r <- lapply(x, lookup1)
    list(text = vapply(r, `[[`, "", "text"), explanation = lapply(r, `[[`, "pairs"))
  },
  # one plan, applied to every element of x
  apply_plan = function(x, plan, ...) vapply(x, replay1, "", pairs = plan, ..., USE.NAMES = FALSE),
  plans = function(res) res$explanation,
  from_pairs = function(pairs) pairs,
  to_pairs = function(plan) plan
)

# ---- Design B: one long data frame of steps -----------------------------
# result: list(text = <chr>, steps = data.frame(element, step, action, parameter))
# plan:   the rows for one element
B <- list(
  fix_and_explain = function(x) {
    r <- lapply(x, lookup1)
    steps <- do.call(rbind, c(list(B$from_pairs(list())), lapply(seq_along(r), function(i)
      cbind(element = rep(i, length(r[[i]]$pairs)), B$from_pairs(r[[i]]$pairs)))))
    list(text = vapply(r, `[[`, "", "text"),
         steps = steps[c("element", "step", "action", "parameter")][0:nrow(steps), ])
  },
  # steps without `element`: one plan for every x. With `element`: element-wise.
  apply_plan = function(x, steps, ...) {
    one <- function(s, st) replay1(s, B$to_pairs(st), ...)
    if (is.null(steps$element)) return(vapply(x, one, "", st = steps, USE.NAMES = FALSE))
    vapply(seq_along(x), function(i) one(x[i], steps[steps$element == i, ]), "")
  },
  plans = function(res) lapply(seq_along(res$text), function(i)
    res$steps[res$steps$element == i, c("step", "action", "parameter")]),
  from_pairs = function(pairs) data.frame(
    step = seq_along(pairs),
    action = vapply(pairs, `[`, "", 1), parameter = vapply(pairs, `[`, "", 2)),
  to_pairs = function(st) Map(c, st$action, st$parameter, USE.NAMES = FALSE)
)

# ---- Design C: a plan vector class ---------------------------------------
# result: data.frame(text = <chr>, plan = <ftfy_plan>), one row per input
# plan:   one element of an <ftfy_plan> vector. (Stored here as one string
#         per plan; how it is stored is an implementation detail.)
ftfy_plan <- function(list_of_pairs) structure(class = "ftfy_plan", vapply(
  list_of_pairs, function(p) if (is.null(p)) NA_character_ else
    paste(vapply(p, paste, "", collapse = " "), collapse = " > "), ""))
`[.ftfy_plan` <- function(x, i) structure(unclass(x)[i], class = "ftfy_plan")
format.ftfy_plan <- function(x, ...) {
  s <- unclass(x); s[!is.na(s) & s == ""] <- "<no steps>"; format(s, ...)
}
print.ftfy_plan <- function(x, ...) {
  cat("<ftfy_plan[", length(x), "]>\n", sep = "")
  print(format(x), quote = FALSE)
  invisible(x)
}
as.data.frame.ftfy_plan <- as.data.frame.vector
plan_steps <- function(plan) {   # long form, same as design B
  p <- C$to_pairs_all(plan)
  do.call(rbind, lapply(seq_along(p), function(i)
    cbind(element = rep(i, length(p[[i]])), B$from_pairs(p[[i]]))))
}
C <- list(
  fix_and_explain = function(x) {
    r <- lapply(x, lookup1)
    out <- data.frame(text = vapply(r, `[[`, "", "text"))
    out$plan <- ftfy_plan(lapply(r, `[[`, "pairs"))
    out
  },
  # plan of length 1 is recycled; otherwise element-wise
  apply_plan = function(x, plan, ...) {
    stopifnot(length(plan) %in% c(1L, length(x)))
    p <- rep_len(C$to_pairs_all(plan), length(x))
    vapply(seq_along(x), function(i) replay1(x[i], p[[i]], ...), "")
  },
  plans = function(res) res$plan,
  from_pairs = function(pairs) ftfy_plan(list(pairs)),
  to_pairs = function(plan) C$to_pairs_all(plan)[[1]],
  to_pairs_all = function(plan) lapply(unclass(plan), function(s)
    if (is.na(s)) NULL else lapply(strsplit(s, " > ", fixed = TRUE)[[1]],
                                   function(st) strsplit(st, " ", fixed = TRUE)[[1]]))
)

designs <- list("A  bare lists (closest port)" = A,
                "B  long data frame of steps" = B,
                "C  plan vector class" = C)

# ---- transcript helpers ---------------------------------------------------
rule <- function(title) cat("\n", strrep("=", 70), "\n", title, "\n", strrep("=", 70), "\n", sep = "")
esc <- function(x) ifelse(is.na(x), "NA", stri_escape_unicode(x))
run <- function(code, env) {
  for (e in as.list(substitute(code))[-1]) {
    cat("> ", paste(deparse(e, width.cutoff = 500), collapse = "\n  "), "\n", sep = "")
    r <- withVisible(tryCatch(eval(e, env), error = function(err) {
      cat("   Error: ", conditionMessage(err), "\n", sep = ""); invisible(NULL)
    }))
    if (r$visible) print(r$value)
  }
}
each_design <- function(code) {
  code <- substitute(code)
  for (n in names(designs)) {
    cat("\n[", n, "]\n", sep = "")
    env <- list2env(designs[[n]], parent = globalenv())
    eval(bquote(run(.(code), env)))
  }
}
pick <- function(...) originals[match(list(list(...)), lapply(py_pairs, as.list))]
with_plan <- function(...) {
  want <- list(...)
  originals[which(vapply(py_pairs, identical, NA, want))[1]]
}

enc  <- function(codec) c("encode", codec)
utf8 <- c("decode", "utf-8")
x_latin1 <- with_plan(enc("latin-1"), utf8)
x_cp1252 <- with_plan(enc("sloppy-windows-1252"), utf8)
x_two    <- with_plan(enc("sloppy-windows-1252"), utf8, enc("latin-1"), utf8)
x_quotes <- with_plan(enc("latin-1"), utf8, c("apply", "uncurl_quotes"))

# ---- 1. a vector, mostly clean, with an NA -------------------------------
rule("1. A vector: mostly clean, one NA, two broken")
x <- c("plain ascii", x_latin1, NA, "café", x_cp1252)
cat("x <- ", paste(deparse(esc(x)), collapse = "\n     "), "\n", sep = "")
each_design({
  res <- fix_and_explain(x)
  res
})

# ---- 2. several steps ----------------------------------------------------
rule("2. One string, two layers of mojibake (upstream case 34)")
cat("y <- ", deparse(esc(x_two)), "\n", sep = "")
y <- x_two
each_design({
  res <- fix_and_explain(y)
  res
})

# ---- 3. replay -----------------------------------------------------------
rule("3. Replay: one plan on other strings, then a vector of plans element-wise")
others <- c("dÃ©jÃ  vu", "naÃ¯ve", "plain ascii")
cat("x_latin1 <- ", deparse(esc(x_latin1)), "\nothers <- ", deparse(esc(others)), "\n", sep = "")
cat("\n[A  bare lists (closest port)]\n")
run({
  plan <- fix_and_explain(x_latin1)$explanation[[1]]
  apply_plan(others, plan)
  res <- fix_and_explain(x[-3])
  mapply(function(s, p) apply_plan(s, p), x[-3], res$explanation, USE.NAMES = FALSE)
}, list2env(A, parent = globalenv()))
cat("\n[B  long data frame of steps]\n")
run({
  res1 <- fix_and_explain(x_latin1)
  plan <- res1$steps[c("step", "action", "parameter")]
  apply_plan(others, plan)
  res <- fix_and_explain(x[-3])
  apply_plan(x[-3], res$steps)
}, list2env(B, parent = globalenv()))
cat("\n[C  plan vector class]\n")
run({
  plan <- fix_and_explain(x_latin1)$plan
  apply_plan(others, plan)
  res <- fix_and_explain(x[-3])
  apply_plan(x[-3], res$plan)
}, list2env(C, parent = globalenv()))

# ---- 4. plan identity: the seam for column-aware repair -------------------
rule("4. Plan identity: tabulate the plans of a 161-value column (all upstream originals)")
column <- originals
cat("\n[A  bare lists (closest port)]\n")
run({
  res <- fix_and_explain(column)
  key <- vapply(res$explanation, function(p) paste(vapply(p, paste, "", collapse = " "), collapse = " > "), "")
  head(sort(table(key), decreasing = TRUE), 4)
  identical(res$explanation[[1]], res$explanation[[2]])
}, list2env(A, parent = globalenv()))
cat("\n[B  long data frame of steps]\n")
run({
  res <- fix_and_explain(column)
  key <- tapply(paste(res$steps$action, res$steps$parameter), factor(res$steps$element, seq_along(column)), paste, collapse = " > ")
  key[is.na(key)] <- ""
  head(sort(table(key), decreasing = TRUE), 4)
}, list2env(B, parent = globalenv()))
cat("\n[C  plan vector class]\n")
run({
  res <- fix_and_explain(column)
  head(sort(table(res$plan), decreasing = TRUE), 4)
  res$plan[1] == res$plan[2]
  dominant <- res$plan[match("encode latin-1 > decode utf-8", res$plan)]
  fits <- apply_plan(column, dominant, on_failure = "na")
  table(dominant_plan_replays = !is.na(fits))
  head(plan_steps(res$plan[1:3]), 5)
}, list2env(C, parent = globalenv()))

# ---- 5. round trip to upstream's pair lists ---------------------------------
rule("5. Round trip: upstream pairs -> R plan -> upstream pairs, all 161 captured plans")
for (n in names(designs)) {
  d <- designs[[n]]
  ok <- vapply(py_pairs, function(p) identical(unname(d$to_pairs(d$from_pairs(p))), p), NA)
  cat(sprintf("[%s]  %d of %d identical\n", n, sum(ok), length(ok)))
}

# ---- behaviour choices, independent of shape (shown with design C) ----------
attach(C)

rule("6. Replay failure: the plan does not fit the string")
cat("Upstream: apply_plan calls str.encode / bytes.decode with strict errors, so it\n",
    "raises UnicodeEncodeError or UnicodeDecodeError (read from the source, not run here).\n", sep = "")
z <- c(x_latin1, "café", "price €5", "plain ascii")
cat("z <- ", deparse(esc(z)), "\nplan <- ", format(dominant <- C$from_pairs(list(enc("latin-1"), utf8))), "\n", sep = "")
plan <- dominant
run({
  apply_plan(z, plan, on_failure = "error")
  apply_plan(z, plan, on_failure = "na")
  apply_plan(z, plan, on_failure = "unchanged")
}, globalenv())

rule("7. The normalize step: upstream emits it, upstream's apply_plan rejects it")
run({
  res <- fix_and_explain("é")
  res
  apply_plan("é", res$plan, allow_normalize = FALSE)   # copy upstream
  esc(apply_plan("é", res$plan, allow_normalize = TRUE))    # depart: replayable
}, globalenv())

rule("8. A step that changes nothing: 'a\\u0081b'")
cat("Upstream returns the text unchanged with a one-step plan. Keep it, or drop it?\n")
run({
  res <- fix_and_explain("a\u0081b")
  identical(res$text, "a\u0081b")
  res$plan                                   # keep: plan is not empty, text unchanged
  ftfy_plan(list(list()))                    # drop: what the plan would be instead
}, globalenv())
