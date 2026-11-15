# Departure `regex-overflow` (inst/departures/regex-overflow.dcf): a regex
# that needs more backtracking stack than the limit is an error naming the
# function and the input length, where Python's `re` has no limit.
#
# At the real limit only tens of millions of characters overflow, so these
# tests lower the limit and leave everything else as it is: the exported
# function, its pattern and the path the error takes.

local_tiny_stack_limit <- function(env = parent.frame()) {
  local_mocked_bindings(
    regex_opts = function() {
      stringi::stri_opts_regex(unix_lines = TRUE, stack_limit = 1)
    },
    .env = env
  )
}

mojibake <- "caf\u00c3\u00a9 cr\u00c3\u00a8me"

test_that("a regex overflow is an error naming the function and the input length", {
  local_tiny_stack_limit()

  expect_error(
    badness(mojibake),
    "^badness\\(\\): .*ran out of stack.* 1 string, the longest of 12 characters",
    class = "ftfy_regex_overflow"
  )
  expect_error(is_bad(mojibake), "^is_bad\\(\\): ", class = "ftfy_regex_overflow")
  expect_error(fix_encoding(mojibake), "^fix_encoding\\(\\): ", class = "ftfy_regex_overflow")
})

test_that("for a vector the error gives the number of strings and the longest one's length", {
  local_tiny_stack_limit()
  x <- c("short", NA, strrep("\u00c3\u00a9", 1500L), "")

  expect_error(
    badness(x), "4 strings, the longest of 3,000 characters",
    class = "ftfy_regex_overflow"
  )
})

test_that("the error's call is the user's call to the exported function", {
  local_tiny_stack_limit()

  raised <- tryCatch(badness(mojibake), error = identity)

  expect_identical(conditionCall(raised), quote(badness(mojibake)))
})

test_that("the exported function is named however it was called", {
  local_tiny_stack_limit()

  expect_error(ftfy::is_bad(mojibake), "^is_bad\\(\\): ", class = "ftfy_regex_overflow")
  expect_error(
    lapply(list(mojibake), badness), "^badness\\(\\): ",
    class = "ftfy_regex_overflow"
  )
  expect_error(
    do.call(badness, list(mojibake)), "^badness\\(\\): ",
    class = "ftfy_regex_overflow"
  )
})

test_that("no result comes back for any element when one overflows", {
  local_tiny_stack_limit()

  expect_error(badness(c("plain", mojibake)), class = "ftfy_regex_overflow")
})

test_that("with the real limit the same calls succeed", {
  expect_identical(badness(mojibake), 2L)
  expect_true(is_bad(mojibake))
})

test_that("an error that is not an overflow passes through the guard unchanged", {
  expect_error(regex_detect("a", "(unclosed"), "U_REGEX_MISMATCHED_PAREN")
  raised <- tryCatch(regex_detect("a", "(unclosed"), error = identity)
  expect_false(inherits(raised, "ftfy_regex_overflow"))
})

test_that("the registry entry matches this difference and no other", {
  matcher <- departure_matchers()[["regex-overflow"]]
  raised <- local({
    local_tiny_stack_limit()
    tryCatch(badness(mojibake), error = identity)
  })
  other <- tryCatch(stop("another error"), error = identity)

  expect_true(matcher(list(fun = "badness", input = mojibake,
                           reference = "2", actual = raised)))
  expect_false(matcher(list(fun = "badness", input = mojibake,
                            reference = "2", actual = other)))
  expect_false(matcher(list(fun = "badness", input = mojibake,
                            reference = "2", actual = "3")))
})
