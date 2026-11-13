# The `ftfy_plan` class, seen through `ftfy_plan()`, `plan_steps()` and the
# S3 methods. Decisions: ADR 0002 and the resolution of issue #9.

# One plan per accepted action, as upstream's lists of pairs. The first three
# are plans Python ftfy 6.3.1 returns (issue #9 and issue #18).
upstream_pairs <- list(
  list(c("encode", "latin-1"), c("decode", "utf-8")),
  list(c("transcode", "fix_c1_controls")),
  list(c("normalize", "NFC")),
  list(
    c("encode", "sloppy-windows-1252"),
    c("transcode", "restore_byte_a0"),
    c("transcode", "replace_lossy_sequences"),
    c("decode", "utf-8-variants"),
    c("apply", "uncurl_quotes")
  ),
  list()
)
upstream_text <- c(
  "encode latin-1 > decode utf-8",
  "transcode fix_c1_controls",
  "normalize NFC",
  paste(
    "encode sloppy-windows-1252 > transcode restore_byte_a0 >",
    "transcode replace_lossy_sequences > decode utf-8-variants >",
    "apply uncurl_quotes"
  ),
  "none"
)

# Upstream's list of pairs for one plan, from the exported long form.
pairs_of <- function(plan) {
  steps <- plan_steps(plan)
  Map(c, steps$action, steps$parameter, USE.NAMES = FALSE)
}

test_that("as.character() gives the text form and ftfy_plan() reads it back", {
  text <- c(
    "encode latin-1 > decode utf-8",
    "none",
    NA,
    "encode sloppy-windows-1252 > transcode restore_byte_a0 > decode utf-8-variants",
    "apply uncurl_quotes > normalize NFC"
  )

  plan <- ftfy_plan(text)

  expect_s3_class(plan, "ftfy_plan")
  expect_identical(as.character(plan), text)
  expect_identical(ftfy_plan(as.character(plan)), plan)
})

test_that("a plan with no steps is `none`, a missing plan is NA, and they differ", {
  plan <- ftfy_plan(c("none", NA))

  expect_identical(as.character(plan), c("none", NA))
  expect_identical(is.na(plan), c(FALSE, TRUE))
  expect_identical(plan[1] == plan[2], NA)
  expect_identical(as.character(ftfy_plan(NA)), NA_character_)
  expect_identical(as.character(ftfy_plan(NA_character_)), NA_character_)
  expect_identical(as.character(ftfy_plan(list())), "none")
  expect_length(ftfy_plan(character()), 0L)
})

test_that("a list of action and parameter pairs gives one plan", {
  for (i in seq_along(upstream_pairs)) {
    plan <- ftfy_plan(upstream_pairs[[i]])
    expect_s3_class(plan, "ftfy_plan")
    expect_length(plan, 1L)
    expect_identical(as.character(plan), upstream_text[[i]])
  }
  # Pairs as lists, the way a JSON reader gives them.
  expect_identical(
    ftfy_plan(list(list("encode", "latin-1"), list("decode", "utf-8"))),
    ftfy_plan("encode latin-1 > decode utf-8")
  )
})

test_that("every plan converts to upstream's pairs and back without loss", {
  for (i in seq_along(upstream_pairs)) {
    plan <- ftfy_plan(upstream_text[[i]])
    expect_identical(pairs_of(plan), unname(upstream_pairs[[i]]))
    expect_identical(ftfy_plan(pairs_of(plan)), plan)
  }
})

test_that("every accepted action, codec, fixer and form is read", {
  codecs <- c(
    "latin-1", "sloppy-windows-1252", "sloppy-windows-1251",
    "sloppy-windows-1250", "sloppy-windows-1253", "sloppy-windows-1254",
    "sloppy-windows-1257", "iso-8859-2", "macroman", "cp437", "windows-1252",
    "utf-8", "utf-8-variants"
  )
  fixers <- c(
    "unescape_html", "remove_terminal_escapes", "restore_byte_a0",
    "replace_lossy_sequences", "decode_inconsistent_utf8", "fix_c1_controls",
    "fix_latin_ligatures", "fix_character_width", "uncurl_quotes",
    "fix_line_breaks", "remove_control_chars"
  )
  forms <- c("NFC", "NFD", "NFKC", "NFKD")
  text <- c(
    paste("encode", codecs), paste("decode", codecs),
    paste("transcode", fixers), paste("apply", fixers),
    paste("normalize", forms)
  )

  expect_identical(as.character(ftfy_plan(text)), text)
})

test_that("plan_steps() gives one row per step and none for `none` and NA", {
  plan <- ftfy_plan(c(
    "none",
    "encode latin-1 > decode utf-8",
    NA,
    "transcode fix_c1_controls",
    "encode latin-1 > decode utf-8"
  ))

  expect_identical(
    plan_steps(plan),
    data.frame(
      element = c(2L, 2L, 4L, 5L, 5L),
      step = c(1L, 2L, 1L, 1L, 2L),
      action = c("encode", "decode", "transcode", "encode", "decode"),
      parameter = c("latin-1", "utf-8", "fix_c1_controls", "latin-1", "utf-8")
    )
  )
})

test_that("plan_steps() gives a zero-row data frame when there are no steps", {
  empty <- data.frame(
    element = integer(), step = integer(),
    action = character(), parameter = character()
  )

  expect_identical(plan_steps(ftfy_plan(c("none", NA))), empty)
  expect_identical(plan_steps(ftfy_plan(character())), empty)
  expect_identical(plan_steps(ftfy_plan(NA)), empty)
})

test_that("plan_steps() takes plans or their text forms and nothing else", {
  expect_identical(
    plan_steps("encode latin-1 > decode utf-8"),
    plan_steps(ftfy_plan("encode latin-1 > decode utf-8"))
  )
  expect_error(plan_steps(1), "must be a vector of plans")
  expect_error(plan_steps("encode latin1"), "Unknown codec")
})

test_that("an unknown action is an error listing the accepted actions", {
  expect_error(
    ftfy_plan(c("none", "recode latin-1")),
    paste0(
      "Unknown action in a plan: \"recode\". Accepted actions: ",
      "encode, decode, transcode, apply, normalize."
    ),
    fixed = TRUE
  )
  expect_error(ftfy_plan(list(c("Encode", "latin-1"))), "Accepted actions: ")
})

test_that("an unknown codec is an error listing the 13 accepted codecs", {
  accepted <- paste0(
    "Accepted codecs: latin-1, sloppy-windows-1252, sloppy-windows-1251, ",
    "sloppy-windows-1250, sloppy-windows-1253, sloppy-windows-1254, ",
    "sloppy-windows-1257, iso-8859-2, macroman, cp437, windows-1252, utf-8, ",
    "utf-8-variants."
  )
  # Python's aliases, another case, a sloppy codec upstream never emits, and
  # a fixer where a codec belongs.
  rejected <- c(
    "latin1", "cp1252", "cesu-8", "UTF-8", "sloppy-windows-1255",
    "uncurl_quotes"
  )
  for (codec in rejected) {
    expect_error(ftfy_plan(paste("encode", codec)), accepted, fixed = TRUE)
    expect_error(
      ftfy_plan(paste("encode latin-1 > decode", codec)), accepted,
      fixed = TRUE
    )
    expect_error(ftfy_plan(list(c("decode", codec))), accepted, fixed = TRUE)
  }
  expect_error(
    ftfy_plan("decode latin1"), "Unknown codec in a plan: \"latin1\"",
    fixed = TRUE
  )
})

test_that("an unknown fixer is an error listing the accepted fixers", {
  accepted <- paste0(
    "Accepted fixers: unescape_html, remove_terminal_escapes, restore_byte_a0, ",
    "replace_lossy_sequences, decode_inconsistent_utf8, fix_c1_controls, ",
    "fix_latin_ligatures, fix_character_width, uncurl_quotes, fix_line_breaks, ",
    "remove_control_chars."
  )
  for (fixer in c("fix_surrogates", "fix_encoding", "remove_bom", "latin-1")) {
    expect_error(ftfy_plan(paste("apply", fixer)), accepted, fixed = TRUE)
    expect_error(ftfy_plan(paste("transcode", fixer)), accepted, fixed = TRUE)
    expect_error(ftfy_plan(list(c("apply", fixer))), accepted, fixed = TRUE)
  }
})

test_that("an unknown normalisation form is an error listing the accepted forms", {
  expect_error(
    ftfy_plan("normalize nfc"),
    paste0(
      "Unknown normalisation form in a plan: \"nfc\". ",
      "Accepted normalisation forms: NFC, NFD, NFKC, NFKD."
    ),
    fixed = TRUE
  )
})

test_that("text that is not in the text form is an error saying where", {
  malformed <- c(
    "", " ", "encode", "encode ", "encode  latin-1", " encode latin-1",
    "encode latin-1 ", "encode latin-1 >", "encode latin-1 > ",
    "encode latin-1>decode utf-8", "encode latin-1  >  decode utf-8",
    "none > encode latin-1", "encode latin-1 > none", "None", "NA",
    "encode latin-1 utf-8", "encode latin-1 > > decode utf-8",
    "encode latin-1\n", "encode caf\u00e9"
  )
  for (text in malformed) {
    expect_error(
      ftfy_plan(text), "Unknown|not a plan in its text form",
      info = text
    )
  }
  expect_error(
    ftfy_plan(c("none", "", NA, "")),
    "in 2 of 4 elements (first at: 2, 4): \"\"",
    fixed = TRUE
  )
  invalid <- "encode \xff"
  Encoding(invalid) <- "UTF-8"
  expect_error(ftfy_plan(invalid), "not a plan in its text form")
})

test_that("ftfy_plan() rejects what is neither text forms nor pairs", {
  rejected <- list(
    1, TRUE, c(NA, TRUE), factor("none"), NULL, as.Date("2024-01-01")
  )
  for (x in rejected) {
    expect_error(ftfy_plan(x), "must be a character vector of plans")
  }
  not_pairs <- list(
    list("encode latin-1"), list(c("encode", "latin-1", "x")),
    list(c("encode", NA)), list(1:2), list(list("encode", 1)),
    list(c("encode", "latin-1"), "decode")
  )
  for (x in not_pairs) {
    expect_error(ftfy_plan(x), "pairs")
  }
})

test_that("ftfy_plan() drops names and other attributes of its input", {
  x <- c(a = "none", b = "encode latin-1 > decode utf-8")

  expect_identical(ftfy_plan(x), ftfy_plan(unname(x)))
  expect_identical(ftfy_plan(ftfy_plan(x)), ftfy_plan(x))
})

test_that("plans print one per line, with `none` and <NA>", {
  plan <- ftfy_plan(c("none", "encode latin-1 > decode utf-8", NA))

  expect_identical(
    capture.output(print(plan)),
    c(
      "<ftfy_plan[3]>",
      "[1] none",
      "[2] encode latin-1 > decode utf-8",
      "[3] <NA>"
    )
  )
  expect_identical(
    capture.output(print(ftfy_plan(character()))),
    "<ftfy_plan[0]>"
  )
  capture.output(returned <- withVisible(print(plan)))
  expect_false(returned$visible)
  expect_identical(returned$value, plan)
  expect_identical(format(plan), c("none", "encode latin-1 > decode utf-8", NA))
})

test_that("subsetting, combining and repeating keep the class", {
  plan <- ftfy_plan(c("none", "encode latin-1 > decode utf-8", NA))

  expect_identical(plan[2:3], ftfy_plan(c("encode latin-1 > decode utf-8", NA)))
  expect_identical(plan[c(TRUE, FALSE, FALSE)], ftfy_plan("none"))
  expect_identical(plan[-1], plan[2:3])
  expect_identical(plan[5], ftfy_plan(NA))
  expect_identical(plan[[2]], ftfy_plan("encode latin-1 > decode utf-8"))
  expect_error(plan[[4]])
  expect_identical(rev(plan), plan[3:1])
  expect_identical(head(plan, 1), ftfy_plan("none"))

  expect_identical(c(plan[1], plan[2:3]), plan)
  expect_identical(c(plan[1:2], NA), plan)
  expect_identical(
    c(plan[1], "encode latin-1 > decode utf-8", NA_character_),
    plan
  )
  expect_error(c(plan, "encode latin1"), "Unknown codec")
  expect_error(c(plan, 1), "must be a vector of plans")

  expect_identical(
    rep(plan[1:2], times = 2),
    ftfy_plan(rep(c("none", "encode latin-1 > decode utf-8"), 2))
  )
  expect_identical(rep(plan[1:2], each = 2), plan[c(1, 1, 2, 2)])
  expect_identical(rep(plan[1], length.out = 3), plan[c(1, 1, 1)])

  expect_identical(length(plan), 3L)
  expect_identical(length(ftfy_plan(character())), 0L)
})

test_that("assigning into a plan vector checks what is assigned", {
  plan <- ftfy_plan(c("none", "none", "none"))

  plan[2] <- "encode latin-1 > decode utf-8"
  plan[[3]] <- NA
  expect_identical(
    plan,
    ftfy_plan(c("none", "encode latin-1 > decode utf-8", NA))
  )
  plan[1] <- ftfy_plan("normalize NFC")
  expect_identical(as.character(plan[1]), "normalize NFC")
  expect_error(plan[1] <- "", "not a plan in its text form")
  expect_error(plan[[1]] <- "encode latin1", "Unknown codec")
  expect_error(plan[1] <- 1, "must be a vector of plans")
})

test_that("plans compare with == and !=, with NA for a missing plan", {
  plan <- ftfy_plan(c("none", "encode latin-1 > decode utf-8", NA, "none"))

  expect_identical(plan == plan[1], c(TRUE, FALSE, NA, TRUE))
  expect_identical(plan != plan[1], c(FALSE, TRUE, NA, FALSE))
  expect_identical(plan == rev(plan), c(TRUE, NA, NA, TRUE))
  expect_identical(plan == "none", c(TRUE, FALSE, NA, TRUE))
  expect_identical(
    "encode latin-1 > decode utf-8" == plan,
    c(FALSE, TRUE, NA, FALSE)
  )
  expect_identical(
    ftfy_plan(list(c("encode", "latin-1"), c("decode", "utf-8"))) == plan[2],
    TRUE
  )
  expect_error(plan == "nothing", "Unknown|not a plan in its text form")
  expect_error(plan == 1, "must be a vector of plans")
  expect_error(plan < plan, "not defined for plans")
  expect_error(plan + 1, "not defined for plans")
  expect_error(-plan, "not defined for plans")
})

test_that("unique(), duplicated(), match() and sort() work on plans", {
  plan <- ftfy_plan(c("none", "encode latin-1 > decode utf-8", NA, "none", NA))

  expect_identical(unique(plan), plan[1:3])
  expect_identical(duplicated(plan), c(FALSE, FALSE, FALSE, TRUE, TRUE))
  expect_identical(match(plan, unique(plan)), c(1L, 2L, 3L, 1L, 3L))
  expect_identical(
    plan %in% ftfy_plan("none"),
    c(TRUE, FALSE, FALSE, TRUE, FALSE)
  )
  expect_identical(sort(plan), plan[c(2, 1, 4)])
})

test_that("table() counts plans, with `none` as a level and NA left out", {
  plan <- ftfy_plan(c(
    "none", "encode latin-1 > decode utf-8", NA, "none",
    "encode sloppy-windows-1252 > decode utf-8", "none"
  ))

  counts <- table(plan)

  expect_identical(
    names(counts),
    c(
      "encode latin-1 > decode utf-8",
      "encode sloppy-windows-1252 > decode utf-8",
      "none"
    )
  )
  expect_identical(as.vector(counts), c(1L, 1L, 3L))
  expect_identical(as.vector(table(plan, useNA = "ifany")), c(1L, 1L, 3L, 1L))
  # The commonest plan is itself a plan that can be used again.
  expect_identical(ftfy_plan(names(which.max(counts))), plan[1])
})

test_that("plans are a column of a data frame", {
  plan <- ftfy_plan(c("none", "encode latin-1 > decode utf-8", NA))

  expect_no_warning(frame <- data.frame(text = c("a", "b", NA), plan = plan))

  expect_identical(names(frame), c("text", "plan"))
  expect_identical(dim(frame), c(3L, 2L))
  expect_identical(frame$plan, plan)
  expect_identical(frame[2:3, ]$plan, plan[2:3])
  expect_identical(frame[which(frame$plan == "none"), "text"], "a")
  expect_identical(
    capture.output(print(frame)),
    c(
      "  text                          plan",
      "1    a                          none",
      "2    b encode latin-1 > decode utf-8",
      "3 <NA>                          <NA>"
    )
  )

  expect_identical(rbind(frame, frame)$plan, c(plan, plan))
  expect_identical(names(data.frame(plan)), "plan")
  expect_identical(as.data.frame(plan)$plan, plan)
  frame$again <- plan
  expect_identical(frame$again, plan)
  merged <- merge(frame["plan"], data.frame(plan = plan[2], n = 1L))
  expect_identical(merged$plan, plan[2])
})

test_that("`none` and NA plans survive a CSV round trip unconfused", {
  path <- tempfile(fileext = ".csv")
  on.exit(unlink(path))
  round_trip <- function(plan) {
    utils::write.csv(
      data.frame(id = seq_along(plan), plan = plan), path,
      row.names = FALSE
    )
    ftfy_plan(utils::read.csv(path)$plan)
  }

  mixed <- ftfy_plan(c("none", NA, "encode latin-1 > decode utf-8", "none", NA))
  expect_identical(round_trip(mixed), mixed)
  expect_identical(
    round_trip(ftfy_plan(c("none", "none"))),
    ftfy_plan(c("none", "none"))
  )
  # read.csv() gives an all-NA column back as logical.
  expect_identical(round_trip(ftfy_plan(c(NA, NA))), ftfy_plan(c(NA, NA)))
  expect_identical(round_trip(ftfy_plan(c("none", NA))), ftfy_plan(c("none", NA)))
  # The empty string is never a plan, so a reader cannot mistake one.
  expect_false(any(as.character(mixed) %in% ""))
})

test_that("a long vector of plans is expanded as each plan alone would be", {
  distinct <- c(upstream_text, NA)
  text <- rep(distinct, times = 500)
  text <- text[order(rep(c(3, 1, 4, 1, 5, 9), 500), seq_len(3000))]
  plan <- ftfy_plan(text)

  whole <- plan_steps(plan)
  one_by_one <- do.call(rbind, lapply(seq_along(plan), function(i) {
    steps <- plan_steps(plan[i])
    steps$element <- rep(i, nrow(steps))
    steps
  }))
  rownames(one_by_one) <- NULL

  expect_identical(whole, one_by_one)
})
