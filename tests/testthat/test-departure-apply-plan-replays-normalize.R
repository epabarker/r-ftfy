# Departure `apply-plan-replays-normalize`
# (inst/departures/apply-plan-replays-normalize.dcf, ADR 0002): apply_plan()
# replays `normalize` steps, where the reference version's apply_plan()
# raises `ValueError: Unknown plan step: normalize` for the plans its own
# fix_and_explain() returns.

# What the reference version raises (run on ftfy 6.3.1 with Python 3.13).
reference_error <- "ValueError: Unknown plan step: normalize"

test_that("apply_plan() replays the plan the reference version records and cannot replay", {
  # fix_and_explain('e\u0301') gives '\xe9' with the plan [('normalize', 'NFC')].
  expect_identical(apply_plan("e\u0301", "normalize NFC"), "\u00e9")
  expect_identical(apply_plan("e\u0301", ftfy_plan(list(c("normalize", "NFC")))), "\u00e9")
})

test_that("the plan fix_and_explain() gives for such a text replays to its text", {
  x <- c("e\u0301", "e\u00cc\u0081 \u201chi\u201d", "\ufb01e\u0301", "\u00e9", NA)
  explained <- fix_and_explain(x)

  expect_identical(
    as.character(explained$plan),
    c("normalize NFC",
      "apply decode_inconsistent_utf8 > apply uncurl_quotes > normalize NFC",
      "apply fix_latin_ligatures > normalize NFC", "none", NA)
  )
  expect_identical(explained$text, c("\u00e9", "\u00e9 \"hi\"", "fi\u00e9", "\u00e9", NA))
  expect_identical(apply_plan(x, explained$plan), explained$text)
  for (form in c("NFD", "NFKC", "NFKD")) {
    explained <- fix_and_explain(x, normalization = form)
    expect_true(any(grepl(paste("normalize", form), as.character(explained$plan), fixed = TRUE)))
    expect_identical(apply_plan(x, explained$plan), explained$text, info = form)
  }
})

test_that("each normalisation form is replayed, alone and after other steps", {
  x <- c("\ufb01e\u0301", "\u212b", NA)

  expect_identical(apply_plan(x, "normalize NFC"), c("\ufb01\u00e9", "\u00c5", NA))
  expect_identical(apply_plan(x, "normalize NFD"), c("\ufb01e\u0301", "A\u030a", NA))
  expect_identical(apply_plan(x, "normalize NFKC"), c("fi\u00e9", "\u00c5", NA))
  expect_identical(apply_plan(x, "normalize NFKD"), c("fie\u0301", "A\u030a", NA))
  expect_identical(
    apply_plan("e\u00cc\u0081 'hi'",
               "encode latin-1 > decode utf-8 > apply uncurl_quotes > normalize NFC"),
    "\u00e9 'hi'"
  )
})

test_that("a normalize step is one of the steps a plan can hold and names a form", {
  expect_identical(
    plan_steps("normalize NFC")[c("action", "parameter")],
    data.frame(action = "normalize", parameter = "NFC", stringsAsFactors = FALSE)
  )
  expect_error(apply_plan("a", "normalize nfc"), "Unknown normalisation form in a plan")
})

test_that("the unexported replay replays it too", {
  expect_identical(ftfy:::replay_plan(c("e\u0301", NA), "normalize NFC"), c("\u00e9", NA))
})

test_that("the registry entry matches this difference and no other", {
  matcher <- departure_matchers()[["apply-plan-replays-normalize"]]
  difference <- function(...) {
    utils::modifyList(
      list(fun = "apply_plan", input = "e\u0301", reference = reference_error,
           actual = apply_plan("e\u0301", "normalize NFC")),
      list(...)
    )
  }

  expect_true(matcher(difference()))
  # Not this departure: another function, another error of the reference
  # version, a reference text, or no text from R.
  expect_false(matcher(difference(fun = "fix_text")))
  expect_false(matcher(difference(reference = "ValueError: Unknown plan step: frobnicate")))
  expect_false(matcher(difference(reference = "ValueError: Unknown function to apply: x")))
  expect_false(matcher(difference(reference = "\u00e9", actual = "e\u0301")))
  expect_false(matcher(difference(actual = NA_character_)))
  expect_false(matcher(difference(actual = simpleError("failed"))))
})
