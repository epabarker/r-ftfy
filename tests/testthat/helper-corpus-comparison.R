# The comparison of the package with the snapshot of the larger corpus
# (ticket #44; the resolution of issue #14, "Larger corpus"). The readers
# are in helper-corpus.R; test-corpus.R uses what is here.
#
# A comparison is one result of the package for every input, set against
# one column of the snapshot. It has a `key` (the snapshot column, or a
# name made here for a result the snapshot holds under another column),
# `fun` (the exported function, as the departure matchers name it) and
# `what` ("text", "plan" or "value"). A call is one call of the package on
# the whole vector of inputs that gives one or more comparisons.

corpus_sub_options <- c(
  "restore_byte_a0", "replace_lossy_sequences", "decode_inconsistent_utf8",
  "fix_c1_controls"
)

corpus_fixers <- c(
  "unescape_html", "remove_terminal_escapes", "uncurl_quotes",
  "fix_latin_ligatures", "fix_character_width", "fix_line_breaks",
  "remove_control_chars", "decode_inconsistent_utf8", "fix_c1_controls"
)

corpus_explaining <- c("fix_and_explain", "fix_encoding_and_explain")

# The variants of fix_text(): those of every function, and the two small
# values of `max_decode_length` that only fix_text() reads.
corpus_fix_text_variants <- function() {
  c(
    corpus_variants(),
    list(
      max_decode_length_10 = list(max_decode_length = 10),
      max_decode_length_60 = list(max_decode_length = 60)
    )
  )
}

# Every call the comparison makes, by name. A call is a list of
#
# - `fun`, the exported function, and `family`, the group its results are
#   reported under;
# - `options`, the options it is called with, a list;
# - `what`, the kind of each comparison it gives, named by key;
# - `form`, by key, "keyword" for a comparison with a column of the
#   reference version's keyword form, else "";
# - `plan`, for apply_plan() only: the plan replayed on each input of the
#   corpus;
# - `run`, a function of the inputs, and of their places in the corpus,
#   that returns a named list of character vectors, one for each key.
corpus_calls <- function(snapshot, inputs) {
  calls <- list()
  add <- function(fun, family, what, run, options = list(), form = NULL, plan = NULL) {
    if (is.null(form)) {
      form <- stats::setNames(rep("", length(what)), names(what))
    }
    calls[[names(what)[[1L]]]] <<- list(
      fun = fun, family = family, options = options, what = what, form = form,
      plan = plan, run = run
    )
  }
  texts <- function(keys) stats::setNames(rep("text", length(keys)), keys)

  add("badness", "badness", c(badness = "value"), function(x, rows) {
    list(badness = as.character(ftfy::badness(x)))
  })
  add("is_bad", "badness", c(is_bad = "value"), function(x, rows) {
    list(is_bad = as.character(ftfy::is_bad(x)))
  })

  for (fixer in corpus_fixers) {
    local({
      fixer <- fixer
      key <- paste0("fixer.", fixer)
      add(fixer, "fixers", texts(key), function(x, rows) {
        stats::setNames(list(getExportedValue("ftfy", fixer)(x)), key)
      })
    })
  }

  # fix_text(): one call for each variant. The keyword column of each of
  # the four options of the encoding repair is set against the same result
  # as the variant that switches the option off: R has one form of an
  # option, and the registry entry encoding-sub-options-honoured is what
  # lies between it and the keyword form.
  fix_text_variants <- corpus_fix_text_variants()
  for (variant in names(fix_text_variants)) {
    local({
      options <- fix_text_variants[[variant]]
      keys <- paste0("fix_text.", variant)
      form <- ""
      option <- sub("^no_", "", variant)
      if (option %in% corpus_sub_options) {
        keys <- c(keys, paste0("fix_text.keyword_no_", option))
        form <- c("", "keyword")
      }
      add("fix_text", "fix_text", texts(keys), function(x, rows) {
        fixed <- do.call(ftfy::fix_text, c(list(x), options))
        stats::setNames(rep(list(fixed), length(keys)), keys)
      }, options = options, form = stats::setNames(form, keys))
    })
  }

  # The two explaining functions: the text and the plan of each variant.
  # fix_encoding_and_explain() is given every option of the variant too:
  # it reads five of them, and the snapshot's columns for the others say
  # that they change nothing.
  variants <- corpus_variants()
  for (fun in corpus_explaining) {
    for (variant in names(variants)) {
      local({
        fun <- fun
        options <- variants[[variant]]
        key <- paste0(fun, ".", variant)
        what <- stats::setNames(c("text", "plan"), c(key, paste0(key, ".plan")))
        add(fun, fun, what, function(x, rows) {
          explained <- do.call(getExportedValue("ftfy", fun), c(list(x), options))
          stats::setNames(list(explained$text, as.character(explained$plan)), names(what))
        }, options = options)
      })
    }
  }

  # fix_encoding() has no column of its own: its text is that of
  # fix_encoding_and_explain().
  for (variant in names(variants)) {
    local({
      options <- variants[[variant]]
      key <- paste0("fix_encoding.", variant)
      add("fix_encoding", "fix_encoding", texts(key), function(x, rows) {
        stats::setNames(list(do.call(ftfy::fix_encoding, c(list(x), options))), key)
      }, options = options)
    })
  }

  # Replays of the reference version's plans. `apply_plan.<fun>` is set
  # against the reference version's own replay of its default plan, which
  # raises where the plan has a `normalize` step; `replay.<fun>.<variant>`
  # is the cross-replay, set against the text the reference version's
  # function gave. A replay that fails in R is `NA`.
  for (fun in corpus_explaining) {
    for (variant in c("own", names(variants))) {
      local({
        key <- if (variant == "own") paste0("apply_plan.", fun) else paste0("replay.", fun, ".", variant)
        plan <- corpus_plan(snapshot, fun, if (variant == "own") "default" else variant)
        add("apply_plan", "apply_plan", texts(key), function(x, rows) {
          stats::setNames(list(corpus_apply_plan(x, plan[rows])), key)
        }, plan = plan)
      })
    }
  }
  calls
}

# apply_plan() on each string with its own plan, with `NA` where the
# replay failed: the error it raises says which elements failed, and the
# others are replayed again without them.
corpus_apply_plan <- function(x, plan) {
  out <- rep(NA_character_, length(x))
  todo <- which(!is.na(plan))
  failed <- tryCatch(
    {
      out[todo] <- ftfy::apply_plan(x[todo], plan[todo])
      integer()
    },
    ftfy_replay_failed = function(e) e$element
  )
  if (length(failed) > 0L) {
    rest <- todo[-failed]
    out[rest] <- ftfy::apply_plan(x[rest], plan[rest])
  }
  out
}

# What the snapshot holds for a comparison: a data frame of `text` and
# `error`, as corpus_text() gives it.
corpus_reference <- function(snapshot, inputs, key) {
  value <- function(text) data.frame(text = text, error = NA_character_, stringsAsFactors = FALSE)
  if (key %in% c("badness", "is_bad")) {
    return(value(snapshot[[key]]))
  }
  if (endsWith(key, ".plan")) {
    parts <- regmatches(key, regexec("^([a-z_]+)[.](.*)[.]plan$", key))[[1L]]
    return(value(corpus_plan(snapshot, parts[[2L]], parts[[3L]])))
  }
  if (startsWith(key, "replay.")) {
    return(corpus_text(snapshot, inputs, sub("^replay[.]", "", key)))
  }
  if (startsWith(key, "fix_encoding.")) {
    return(corpus_text(snapshot, inputs, sub("^fix_encoding[.]", "fix_encoding_and_explain.", key)))
  }
  corpus_text(snapshot, inputs, key)
}

# One call on the whole vector. When it raises an error, each element is
# called alone, so that the error is laid at the elements that raise it:
# `raised` holds the message there, and every result of that element is
# `NA`.
corpus_run <- function(call, x, rows) {
  keys <- names(call$what)
  whole <- tryCatch(call$run(x, rows), error = function(e) e)
  if (!inherits(whole, "error")) {
    stopifnot(identical(names(whole), keys), all(lengths(whole) == length(x)))
    return(list(values = lapply(whole, as.character), raised = rep(NA_character_, length(x))))
  }
  values <- stats::setNames(rep(list(rep(NA_character_, length(x))), length(keys)), keys)
  raised <- rep(NA_character_, length(x))
  for (i in seq_along(x)) {
    one <- tryCatch(call$run(x[[i]], rows[[i]]), error = function(e) e)
    if (inherits(one, "error")) {
      raised[[i]] <- conditionMessage(one)
    } else {
      for (key in keys) {
        values[[key]][[i]] <- as.character(one[[key]])
      }
    }
  }
  if (all(is.na(raised))) {
    # Only the whole vector raises: no element is to blame, so all are.
    raised[] <- paste("on the whole vector only:", conditionMessage(whole))
  }
  list(values = values, raised = raised)
}

# The differences of one comparison from the snapshot: a data frame with a
# row for each input whose result is not the snapshot's, of `row` (the
# place in `x`), `key`, `fun`, `what`, `reference`, `actual` and
# `departure`, the id of the registry entry that matches the difference,
# or `NA` when none does.
#
# The two sides agree where both give the same text, and where both raise:
# a failed replay (`NA` from corpus_apply_plan()) is R's error for
# apply_plan(). Where the reference version raised, `reference` is its
# "<type>: <message>"; where R raised, `actual` is "!" and the message, and
# the matchers are handed the condition.
#
# A matcher is handed, beside the four elements of every difference,
# `what`, `options`, `form` and `plan` of the call (see corpus_calls()).
# `seen` remembers the differences already matched: the same one comes
# back in many columns.
corpus_differences <- function(key, call, x, plan, reference, actual, raised, matchers, seen) {
  fun <- call$fun
  what <- call$what[[key]]
  form <- call$form[[key]]
  r_failed <- !is.na(raised) | (fun == "apply_plan" & is.na(actual))
  agrees <- ifelse(
    is.na(reference$error),
    !r_failed & !is.na(actual) & !is.na(reference$text) & actual == reference$text,
    r_failed
  )
  rows <- which(!agrees)
  if (length(rows) == 0L) {
    none <- character()
    return(data.frame(
      row = integer(), key = none, fun = none, what = none, reference = none,
      actual = none, departure = none, stringsAsFactors = FALSE
    ))
  }
  reference_shown <- ifelse(is.na(reference$error), reference$text, reference$error)[rows]
  actual_shown <- ifelse(is.na(raised), actual, paste0("!", raised))[rows]
  separator <- intToUtf8(1L)
  memo <- paste(
    fun, what, form, paste(deparse(call$options), collapse = " "),
    if (is.null(plan)) "" else plan[rows], x[rows], reference_shown, actual_shown,
    sep = separator
  )
  for (j in which(!memo %in% seen$memo)) {
    i <- rows[[j]]
    if (memo[[j]] %in% seen$memo) {
      next
    }
    difference <- list(
      fun = fun, input = x[[i]], reference = reference_shown[[j]],
      actual = if (is.na(raised[[i]])) actual[[i]] else simpleError(raised[[i]]),
      what = what, options = call$options, form = form,
      plan = if (is.null(plan)) NULL else plan[[i]]
    )
    id <- departure_matching(difference, matchers)
    seen$memo <- c(seen$memo, memo[[j]])
    seen$id <- c(seen$id, if (is.null(id)) NA_character_ else id)
  }
  data.frame(
    row = rows, key = rep(key, length(rows)), fun = rep(fun, length(rows)),
    what = rep(what, length(rows)), reference = reference_shown, actual = actual_shown,
    departure = seen$id[match(memo, seen$memo)], stringsAsFactors = FALSE
  )
}

# Every difference of the calls given, over the rows of the corpus given:
# the data frames of corpus_differences() bound together, with `row` the
# place in the corpus.
corpus_compare <- function(calls, snapshot, inputs, rows, matchers, seen = new.env()) {
  x <- inputs$text[rows]
  out <- list()
  for (call in calls) {
    result <- corpus_run(call, x, rows)
    for (key in names(call$what)) {
      reference <- corpus_reference(snapshot, inputs, key)[rows, ]
      out[[key]] <- corpus_differences(
        key, call, x, if (is.null(call$plan)) NULL else call$plan[rows], reference,
        result$values[[key]], result$raised, matchers, seen
      )
    }
  }
  out <- do.call(rbind, unname(out))
  out$row <- rows[out$row]
  out
}

# --- The file of mismatches ------------------------------------------------

# Where the mismatches are written: the file the environment names (the
# corpus jobs upload it), or a temporary one.
corpus_mismatch_file <- function() {
  path <- Sys.getenv("FTFY_CORPUS_MISMATCHES")
  if (nzchar(path)) path else file.path(tempdir(), "ftfy-corpus-mismatches.csv")
}

corpus_mismatch_columns <- c(
  "slice", "id", "variant", "detail", "check", "fun", "what", "input", "reference", "actual"
)

# Start the file: the header alone, which is all it holds when nothing
# differs.
start_corpus_mismatches <- function(path = corpus_mismatch_file()) {
  writeLines(paste(corpus_mismatch_columns, collapse = ","), path, useBytes = TRUE)
  invisible(path)
}

# Append the differences that no registry entry matches. Every field is
# ASCII: texts are escaped as stringi escapes them.
write_corpus_mismatches <- function(differences, inputs, path = corpus_mismatch_file()) {
  bad <- differences[is.na(differences$departure), , drop = FALSE]
  if (nrow(bad) == 0L) {
    return(invisible(0L))
  }
  escape <- function(text) ifelse(is.na(text), "NA", stringi::stri_escape_unicode(text))
  at <- bad$row
  out <- data.frame(
    slice = inputs$slice[at], id = inputs$id[at], variant = inputs$variant[at],
    detail = inputs$detail[at], check = bad$key, fun = bad$fun, what = bad$what,
    input = escape(inputs$text[at]), reference = escape(bad$reference),
    actual = escape(bad$actual), stringsAsFactors = FALSE
  )
  stopifnot(identical(names(out), corpus_mismatch_columns))
  utils::write.table(
    out, path, append = TRUE, sep = ",", qmethod = "double",
    row.names = FALSE, col.names = FALSE, fileEncoding = "UTF-8"
  )
  invisible(nrow(out))
}

# An expectation: no difference is left unmatched. The failure shows the
# first few and says where all of them are.
expect_no_corpus_mismatch <- function(differences, inputs, label) {
  bad <- differences[is.na(differences$departure), , drop = FALSE]
  if (nrow(bad) == 0L) {
    return(invisible(testthat::succeed()))
  }
  shown <- utils::head(bad, 5L)
  show <- function(text) ifelse(is.na(text), "NA", stringi::stri_escape_unicode(text))
  testthat::fail(paste0(
    label, ": ", nrow(bad), " differences from the corpus snapshot in ",
    length(unique(bad$row)), " inputs that no departure registry entry matches (",
    paste(utils::head(unique(bad$key), 8L), collapse = ", "),
    if (length(unique(bad$key)) > 8L) ", ..." else "", "). All of them are in ",
    corpus_mismatch_file(), ".\n",
    paste0(
      "  [", inputs$slice[shown$row], " ", inputs$id[shown$row], ", ",
      inputs$variant[shown$row], "] ", shown$key, "\n",
      "       input:     ", show(inputs$text[shown$row]), "\n",
      "       reference: ", show(shown$reference), "\n",
      "       actual:    ", show(shown$actual),
      collapse = "\n"
    )
  ))
}

# How many differences each registry entry matched, by comparison: a data
# frame of `key`, `departure` and `n`, in that order.
corpus_departure_counts <- function(differences) {
  matched <- differences[!is.na(differences$departure), , drop = FALSE]
  if (nrow(matched) == 0L) {
    return(data.frame(key = character(), departure = character(), n = integer(), stringsAsFactors = FALSE))
  }
  counts <- as.data.frame(table(key = matched$key, departure = matched$departure), stringsAsFactors = FALSE)
  counts <- counts[counts$Freq > 0L, ]
  counts <- counts[order(counts$key, counts$departure, method = "radix"), ]
  data.frame(key = counts$key, departure = counts$departure, n = counts$Freq, stringsAsFactors = FALSE)
}
