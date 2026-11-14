# Derived from python-ftfy v6.3.1, ftfy/__init__.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# Upstream doctest of apply_plan(), ftfy/__init__.py:746. Upstream takes
# the plan from fix_and_explain(); here it is also written out, and taken
# from fix_encoding_and_explain(), which gives the same plan for this text.
test_that("apply_plan() replays the plan of a repair on the text it came from", {
  mojibake <- "sch\u00c3\u00b6n"

  expect_identical(apply_plan(mojibake, "encode latin-1 > decode utf-8"), "sch\u00f6n")
  explained <- fix_encoding_and_explain(mojibake)
  expect_identical(apply_plan(mojibake, explained$plan), "sch\u00f6n")
  # The doctest as upstream has it.
  explained <- fix_and_explain(mojibake)
  expect_identical(as.character(explained$plan), "encode latin-1 > decode utf-8")
  expect_identical(apply_plan(mojibake, explained$plan), "sch\u00f6n")
})

# The rest of this file tests the replay against the committed snapshots of
# reference behaviour and R-only behaviour; nothing more is ported.

# reference/fix_encoding.tsv as (text, plan, fixed) rows: the default
# columns, then the columns of each encoding option switched off. A sparse
# column is filled from the column it stands for, and a reference text that
# holds U+0000 stays escaped (see `unescape_reference()`).
replay_rows <- function() {
  raw <- read_reference_table("fix_encoding.tsv", text = "text")
  fill <- function(column, from) ifelse(raw[[column]] == "", raw[[from]], raw[[column]])
  options <- c("restore_byte_a0", "replace_lossy_sequences",
               "decode_inconsistent_utf8", "fix_c1_controls")
  rows <- lapply(c("", options), function(option) {
    if (option == "") {
      plan <- raw$plan
      fixed <- raw$fixed
    } else {
      plan <- fill(paste0("plan_no_", option), "plan")
      fixed <- fill(paste0("no_", option), "fixed")
    }
    data.frame(
      option = option, text = raw$text, plan = plan,
      fixed = unescape_reference(fixed), stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

code_points <- function(x) lapply(x, utf8ToInt)

# Length of `plan`, and missing values -------------------------------------

test_that("apply_plan() replays one plan on every string", {
  x <- c("sch\u00c3\u00b6n", "caf\u00c3\u00a9", "plain", "")

  expect_identical(
    apply_plan(x, "encode latin-1 > decode utf-8"),
    c("sch\u00f6n", "caf\u00e9", "plain", "")
  )
  expect_identical(apply_plan(x, ftfy_plan("none")), x)
  expect_identical(apply_plan(character(), "encode latin-1 > decode utf-8"), character())
})

test_that("apply_plan() replays one plan per string", {
  x <- c("sch\u00c3\u00b6n", "\u00d0\u00b6", "caf\u00e9", "e\u0301")
  plan <- ftfy_plan(c(
    "encode latin-1 > decode utf-8", "encode sloppy-windows-1252 > decode utf-8",
    "none", "normalize NFC"
  ))

  expect_identical(apply_plan(x, plan), c("sch\u00f6n", "\u0436", "caf\u00e9", "\u00e9"))
  expect_identical(apply_plan(x, as.character(plan)), apply_plan(x, plan))
  expect_identical(apply_plan(character(), ftfy_plan(character())), character())
})

test_that("a plan of any other length is an error", {
  x <- c("a", "b", "c")

  expect_error(apply_plan(x, c("none", "none")), "one plan for each element of `x` \\(3\\), not 2 plans")
  expect_error(apply_plan(x, character()), "not 0 plans")
  expect_error(apply_plan("a", c("none", "none")), "not 2 plans")
  expect_error(apply_plan(character(), c("none", "none")), "not 2 plans")
})

test_that("a missing string or a missing plan gives NA", {
  x <- c("sch\u00c3\u00b6n", NA, "caf\u00c3\u00a9", NA)
  plan <- c("encode latin-1 > decode utf-8", "encode latin-1 > decode utf-8", NA, NA)

  expect_identical(apply_plan(x, plan), c("sch\u00f6n", NA, NA, NA))
  expect_identical(apply_plan(x, "encode latin-1 > decode utf-8"), c("sch\u00f6n", NA, "caf\u00e9", NA))
  expect_identical(apply_plan(x, NA), rep(NA_character_, 4L))
  expect_identical(apply_plan(x, ftfy_plan(NA_character_)), rep(NA_character_, 4L))
  expect_identical(apply_plan(NA, "none"), NA_character_)
  # A missing string is not a failed replay, whatever the plan.
  expect_identical(apply_plan(NA_character_, "decode utf-8"), NA_character_)
})

test_that("`plan` must be plans, with accepted names only", {
  expect_error(apply_plan("a", 1), "`plan` must be a vector of plans")
  expect_error(apply_plan("a", list(c("encode", "latin-1"))), "`plan` must be a vector of plans")
  expect_error(apply_plan("a", "frobnicate latin-1"), "Unknown action in a plan: \"frobnicate\"")
  expect_error(apply_plan("a", "encode latin1"), "Unknown codec in a plan: \"latin1\"")
  expect_error(apply_plan("a", "encode latin-1 > decode UTF8"), "Unknown codec in a plan")
  expect_error(apply_plan("a", "apply fix_surrogates"), "Unknown fixer in a plan")
  expect_error(apply_plan("a", "transcode no_such_fixer"), "Unknown fixer in a plan")
  expect_error(apply_plan("a", "normalize NFX"), "Unknown normalisation form in a plan")
  expect_error(apply_plan("a", ""), "not a plan in its text form")
  # Also when there is nothing to replay it on.
  expect_error(apply_plan(character(), "encode latin1"), "Unknown codec")
  expect_error(apply_plan(NA, "encode latin1"), "Unknown codec")
})

test_that("apply_plan() keeps names, dim and dimnames of `x` and no other attribute", {
  x <- c(a = "sch\u00c3\u00b6n", b = NA, c = "plain")
  expect_identical(
    apply_plan(x, "encode latin-1 > decode utf-8"),
    c(a = "sch\u00f6n", b = NA, c = "plain")
  )

  m <- matrix(c("sch\u00c3\u00b6n", "a", "b", "caf\u00c3\u00a9"), 2L,
              dimnames = list(c("r1", "r2"), c("c1", "c2")))
  plans <- c("encode latin-1 > decode utf-8", "none", "none", "encode latin-1 > decode utf-8")
  expect_identical(
    apply_plan(m, plans),
    matrix(c("sch\u00f6n", "a", "b", "caf\u00e9"), 2L, dimnames = dimnames(m))
  )
  # Names on the plan are not carried.
  expect_identical(apply_plan(c("a", "b"), c(p = "none", q = "none")), c("a", "b"))
  expect_identical(apply_plan(structure("a", class = "thing", extra = 1), "none"), "a")
})

# The five actions -----------------------------------------------------------

test_that("each single-byte codec encodes and decodes every character of its table", {
  tables <- ftfy:::codec_tables
  expect_setequal(c(names(tables), "utf-8", "utf-8-variants"), ftfy:::plan_codecs)

  for (codec in names(tables)) {
    bytes <- 1:255
    assigned <- !is.na(tables[[codec]][bytes + 1L])
    # One string per byte the codec has, and one of all of them.
    as_bytes <- c(vapply(bytes[assigned], intToUtf8, ""), intToUtf8(bytes[assigned]))
    as_text <- c(vapply(tables[[codec]][bytes + 1L][assigned], intToUtf8, ""),
                 intToUtf8(tables[[codec]][bytes + 1L][assigned]))

    # Bytes held as the characters U+0001 to U+00FF are what latin-1 gives.
    expect_identical(
      code_points(apply_plan(as_text, paste0("encode ", codec, " > decode latin-1"))),
      code_points(as_bytes), info = codec
    )
    expect_identical(
      code_points(apply_plan(as_bytes, paste0("encode latin-1 > decode ", codec))),
      code_points(as_text), info = codec
    )
    expect_identical(
      apply_plan(as_text, paste0("encode ", codec, " > decode ", codec)), as_text,
      info = codec
    )
  }
})

test_that("the two UTF-8 codecs encode and decode", {
  text <- c("caf\u00e9", "\u20ac", "\U0001f600", "plain", "\ufeffx")
  mojibake <- c("caf\u00c3\u00a9", "\u00e2\u0082\u00ac", "\u00f0\u009f\u0098\u0080", "plain",
                "\u00ef\u00bb\u00bfx")

  for (codec in c("utf-8", "utf-8-variants")) {
    expect_identical(apply_plan(text, paste0("encode ", codec, " > decode latin-1")), mojibake)
    expect_identical(apply_plan(mojibake, paste0("encode latin-1 > decode ", codec)), text)
  }
  # CESU-8: a surrogate pair of two three-byte sequences, which only
  # `utf-8-variants` reads.
  cesu <- "\u00ed\u00a0\u00bd\u00ed\u00b8\u0080"
  expect_identical(apply_plan(cesu, "encode latin-1 > decode utf-8-variants"), "\U0001f600")
  expect_error(apply_plan(cesu, "encode latin-1 > decode utf-8"), class = "ftfy_replay_failed")
})

test_that("each text fixer replays as the reference version's fixer, under either action", {
  for (fixer in text_fixer_names) {
    for (action in c("apply", "transcode")) {
      expect_text_fixer_reference(
        fixer, function(x) apply_plan(x, paste(action, fixer))
      )
    }
  }
})

test_that("the two text fixers of the encoding repair replay as the reference version's", {
  raw <- read_reference_table("fix_encoding.tsv", text = "text")
  for (fixer in c("decode_inconsistent_utf8", "fix_c1_controls")) {
    reference <- unescape_reference(ifelse(raw[[fixer]] == "", raw$text, raw[[fixer]]))
    for (action in c("apply", "transcode")) {
      expect_reference(fixer, raw$text, apply_plan(raw$text, paste(action, fixer)), reference)
    }
  }
})

# The first text and its plan are from the upstream doctest of
# fix_encoding_and_explain(), ftfy/__init__.py:437.
test_that("the two byte fixers replay between an encode and a decode step, under either action", {
  for (action in c("apply", "transcode")) {
    expect_identical(
      apply_plan("voil\u00c3 le travail",
                 paste0("encode latin-1 > ", action, " restore_byte_a0 > decode utf-8")),
      "voil\u00e0 le travail"
    )
    expect_identical(
      apply_plan("\u00e2\u20ac\ufffdquoted\u00e2\u20ac\u009d",
                 paste0("encode sloppy-windows-1252 > ", action,
                        " replace_lossy_sequences > decode utf-8")),
      "\ufffdquoted\u201d"
    )
  }
  # Without the fixer the bytes are not UTF-8.
  expect_error(apply_plan("voil\u00c3 le travail", "encode latin-1 > decode utf-8"),
               class = "ftfy_replay_failed")
})

test_that("every fixer a plan can name has a function the replay finds", {
  for (fixer in ftfy:::plan_fixers) {
    on_bytes <- fixer %in% c("restore_byte_a0", "replace_lossy_sequences")
    for (action in c("apply", "transcode")) {
      plan <- paste(action, fixer)
      if (on_bytes) {
        plan <- paste0("encode utf-8 > ", plan, " > decode utf-8")
      }
      expect_identical(apply_plan(c("plain text", NA), plan), c("plain text", NA), info = plan)
    }
  }
})

test_that("normalize steps replay in each of the four forms", {
  x <- c("e\u0301", "\u00e9", "\ufb01", "\u212b", "plain", NA)

  expect_identical(apply_plan(x, "normalize NFC"), c("\u00e9", "\u00e9", "\ufb01", "\u00c5", "plain", NA))
  expect_identical(apply_plan(x, "normalize NFD"), c("e\u0301", "e\u0301", "\ufb01", "A\u030a", "plain", NA))
  expect_identical(apply_plan(x, "normalize NFKC"), c("\u00e9", "\u00e9", "fi", "\u00c5", "plain", NA))
  expect_identical(apply_plan(x, "normalize NFKD"), c("e\u0301", "e\u0301", "fi", "A\u030a", "plain", NA))
  # After other steps, as fix_and_explain() records it.
  expect_identical(
    apply_plan("e\u0301 \u201chi\u201d", "apply uncurl_quotes > normalize NFC"),
    "\u00e9 \"hi\""
  )
  # CC 81 is U+0301 in UTF-8.
  expect_identical(
    apply_plan("e\u00cc\u0081", "encode latin-1 > decode utf-8 > normalize NFC"),
    "\u00e9"
  )
})

test_that("a leading U+FEFF goes through every kind of step as data", {
  x <- "\ufeffe\u0301"

  for (form in c("NFC", "NFD", "NFKC", "NFKD")) {
    replayed <- apply_plan(x, paste("normalize", form))
    expect_identical(utf8ToInt(replayed)[[1L]], 0xFEFFL, info = form)
  }
  expect_identical(
    code_points(apply_plan(
      x, "encode utf-8 > decode utf-8 > apply uncurl_quotes > transcode fix_c1_controls"
    )),
    code_points(x)
  )
  expect_identical(
    code_points(apply_plan("\u00ef\u00bb\u00bfx", "encode latin-1 > decode utf-8")),
    list(c(0xFEFFL, 0x78L))
  )
  expect_identical(code_points(apply_plan(x, "apply remove_control_chars")), list(c(0x65L, 0x301L)))
})

test_that("apply_plan() gives UTF-8 marked text", {
  x <- c("sch\u00c3\u00b6n", "caf\u00c3\u00a9")
  for (plan in c("encode latin-1 > decode utf-8-variants", "encode utf-8 > decode sloppy-windows-1252",
                 "normalize NFD", "none")) {
    replayed <- apply_plan(x, plan)
    expect_identical(Encoding(replayed), c("UTF-8", "UTF-8"), info = plan)
    expect_true(all(stringi::stri_enc_isutf8(replayed)), info = plan)
  }
})

# Failed replays ----------------------------------------------------------------

test_that("a failed replay is an error naming the first element that failed", {
  x <- c("sch\u00c3\u00b6n", "5 \u20ac", NA, "caf\u00e9", "\u0100")
  plan <- "encode latin-1 > decode utf-8"

  raised <- tryCatch(apply_plan(x, plan), error = identity)
  expect_s3_class(raised, "ftfy_replay_failed")
  expect_match(conditionMessage(raised),
               "failed in 3 of 5 elements of `x` (first at: 2, 4, 5)", fixed = TRUE)
  expect_match(
    conditionMessage(raised),
    "In element 2, step 1 of the plan `encode latin-1 > decode utf-8`, `encode latin-1`, met a character that the codec cannot encode",
    fixed = TRUE
  )
  expect_identical(raised$element, c(2L, 4L, 5L))
  expect_identical(raised$step, c(1L, 2L, 1L))

  # A decode step.
  expect_error(
    apply_plan(c("plain", "caf\u00e9"), plan),
    "(first at: 2). In element 2, step 2 of the plan `encode latin-1 > decode utf-8`, `decode utf-8`, met bytes that the codec cannot decode",
    fixed = TRUE, class = "ftfy_replay_failed"
  )
  # The first failure in the order of `x`, with a plan per element.
  expect_error(
    apply_plan(c("a", "\u0081", "\u20ac"),
               c("none", "encode latin-1 > decode windows-1252", "encode latin-1 > decode utf-8")),
    "failed in 2 of 3 elements of `x` (first at: 2, 3). In element 2, step 2 of the plan `encode latin-1 > decode windows-1252`",
    fixed = TRUE, class = "ftfy_replay_failed"
  )
})

# What the reference version does with each of these was run, not read:
# the note on issue #27 has the output.
test_that("the codecs fail where the reference version's fail", {
  failing <- list(
    c("\u20ac5", "encode latin-1 > decode utf-8"),
    c("\u0100", "encode sloppy-windows-1252 > decode utf-8"),
    c("\u0081", "encode windows-1252 > decode windows-1252"),
    c("caf\u00e9", "encode latin-1 > decode utf-8"),
    c("caf\u00e9", "encode latin-1 > decode utf-8-variants"),
    c("\u0081", "encode latin-1 > decode windows-1252")
  )
  for (case in failing) {
    expect_error(apply_plan(case[[1L]], case[[2L]]), class = "ftfy_replay_failed", info = case[[2L]])
    expect_identical(ftfy:::replay_plan(case[[1L]], case[[2L]]), NA_character_, info = case[[2L]])
  }
})

test_that("a step handed bytes for text, or text for bytes, fails on every string", {
  misfits <- c(
    "decode utf-8" = "step 1 of the plan `decode utf-8`, `decode utf-8`, works on bytes and was handed text",
    "encode latin-1 > encode latin-1" = "step 2 .* works on text and was handed bytes",
    "apply restore_byte_a0" = "step 1 .* works on bytes and was handed text",
    "transcode replace_lossy_sequences" = "step 1 .* works on bytes and was handed text",
    "encode latin-1 > normalize NFC > decode utf-8" = "step 2 .*`normalize NFC`, works on text and was handed bytes",
    "encode utf-8 > decode utf-8 > decode utf-8" = "step 3 .* works on bytes and was handed text"
  )
  for (fixer in setdiff(ftfy:::plan_fixers, c("restore_byte_a0", "replace_lossy_sequences"))) {
    misfits[[paste0("encode latin-1 > transcode ", fixer, " > decode utf-8")]] <-
      "step 2 .* works on text and was handed bytes"
  }
  for (plan in names(misfits)) {
    expect_error(
      apply_plan(c(NA, "a b", ""), plan),
      paste0("first at: 2, 3\\)\\. In element 2, ", misfits[[plan]]),
      class = "ftfy_replay_failed", info = plan
    )
    expect_identical(ftfy:::replay_plan(c(NA, "a b", ""), plan), rep(NA_character_, 3L), info = plan)
  }
})

test_that("a plan that ends with bytes fails on every string", {
  expect_error(
    apply_plan("abc", "encode latin-1"),
    "In element 1, the plan `encode latin-1` ends with bytes, not text",
    class = "ftfy_replay_failed"
  )
  expect_error(apply_plan("abc", "encode utf-8 > transcode restore_byte_a0"), "ends with bytes",
               class = "ftfy_replay_failed")
  # A string that fails at a step is reported at that step.
  raised <- tryCatch(apply_plan(c("\u20ac", "a"), "encode latin-1"), error = identity)
  expect_identical(raised$step, c(1L, 2L))
  expect_match(conditionMessage(raised), "In element 1, step 1 of the plan")
})

test_that("a regex overflow inside a replayed fixer is the package's error, naming apply_plan()", {
  local_mocked_bindings(
    regex_opts = function() stringi::stri_opts_regex(unix_lines = TRUE, stack_limit = 1)
  )

  expect_error(
    apply_plan("caf\u00c3\u00a9 cr\u00c3\u00a8me", "apply decode_inconsistent_utf8"),
    "^apply_plan\\(\\): ", class = "ftfy_regex_overflow"
  )
})

# The unexported replay -----------------------------------------------------------

test_that("the unexported replay gives NA for each element that fails and raises no error", {
  x <- c("sch\u00c3\u00b6n", "5 \u20ac", NA, "caf\u00e9", "\u0100", "plain", "sch\u00c3\u00b6n")
  plan <- "encode latin-1 > decode utf-8"

  expect_identical(
    ftfy:::replay_plan(x, plan),
    c("sch\u00f6n", NA, NA, NA, NA, "plain", "sch\u00f6n")
  )
  expect_identical(ftfy:::replay_plan(x, ftfy_plan(plan)), ftfy:::replay_plan(x, plan))
  per_element <- c(plan, "none", plan, NA, "encode utf-8", "decode utf-8", "none")
  expect_identical(
    ftfy:::replay_plan(x, per_element),
    c("sch\u00f6n", "5 \u20ac", NA, NA, NA, NA, "sch\u00c3\u00b6n")
  )
  expect_identical(ftfy:::replay_plan(character(), plan), character())
  expect_identical(Encoding(ftfy:::replay_plan(x, plan))[c(1L, 7L)], c("UTF-8", "UTF-8"))
})

# Whole vectors -------------------------------------------------------------------

test_that("one call on a vector with a plan per element equals one call per element", {
  # Not among the tests issue #14 keeps on CRAN: thousands of calls on one
  # string each, the slowest kind of test here. It runs wherever NOT_CRAN
  # is "true": every check job of the R-CMD-check workflow.
  skip_on_cran()
  rows <- replay_rows()
  x <- c(rows$text[1:1500], NA, rows$text[1:200], NA, rows$text[1:3])
  plan <- c(rows$plan[1:1500], "none", rows$plan[1:200], NA, NA, "decode utf-8", "encode cp437")
  # A fixed shuffle, so that equal plans, duplicates and `NA`s are apart.
  shuffle <- order((seq_along(x) * 7919) %% 2503, seq_along(x))
  x <- x[shuffle]
  plan <- plan[shuffle]

  whole <- ftfy:::replay_plan(x, plan)
  each <- vapply(seq_along(x), function(i) ftfy:::replay_plan(x[i], plan[i]), "")

  expect_identical(whole, each)
  expect_gt(length(unique(plan)), 20L)
  expect_gt(sum(!is.na(whole)), 1500L)
})

# Snapshots of reference behaviour ---------------------------------------------------

test_that("every plan fix_encoding_and_explain() returns replays to its text", {
  rows <- replay_rows()
  text <- rows$text[rows$option == ""]

  explained <- fix_encoding_and_explain(text)
  expect_identical(apply_plan(text, explained$plan), explained$text)
  for (option in setdiff(unique(rows$option), "")) {
    explained <- do.call(
      fix_encoding_and_explain, c(list(text), stats::setNames(list(FALSE), option))
    )
    expect_identical(apply_plan(text, explained$plan), explained$text, info = option)
  }
})

test_that("the reference version's encoding plan replays to its text on every snapshot row", {
  rows <- replay_rows()
  replayed <- ftfy:::replay_plan(rows$text, rows$plan)
  # The registry is read once, not for every row.
  matchers <- departure_matchers()

  expect_reference("apply_plan", rows$text, replayed, rows$fixed, matchers)
  # The rows on which a departure applies, by registry entry.
  differs <- which((is.na(replayed) | replayed != rows$fixed) & rows$option == "")
  ids <- vapply(differs, function(i) {
    id <- departure_matching(list(fun = "apply_plan", input = rows$text[[i]],
                                  reference = rows$fixed[[i]], actual = replayed[[i]]),
                             matchers)
    if (is.null(id)) "unmatched" else id
  }, "")
  expect_identical(
    c(table(ids)),
    c("decoded-nul-dropped" = 3L, "utf8-variants-trailing-newline" = 4L)
  )
  expect_gt(length(unique(rows$plan)), 40L)
})

test_that("the reference version's plans for the JSON cases replay to its texts", {
  cases <- read_json_cases()

  expect_reference(
    "apply_plan", cases$original,
    apply_plan(cases$original, cases$reference.fix_encoding_plan),
    cases$reference.fix_encoding_text
  )
  expect_reference(
    "apply_plan", cases$original,
    apply_plan(cases$original, cases$reference.fix_and_explain_plan),
    cases$reference.fix_and_explain_text
  )
  # Plans of the fixer loop are among them.
  expect_true(any(grepl("apply ", cases$reference.fix_and_explain_plan, fixed = TRUE)))
})

test_that("for the JSON cases the plan of fix_encoding_and_explain() replays to its text", {
  cases <- read_json_cases()
  explained <- fix_encoding_and_explain(cases$original)

  expect_identical(apply_plan(cases$original, explained$plan), explained$text)
})
