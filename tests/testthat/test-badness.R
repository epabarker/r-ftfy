test_that("badness() gives the reference version's count for every snapshot input", {
  snapshot <- read_reference("badness.tsv")
  expect_gt(nrow(snapshot), 2000)

  result <- badness(snapshot$text)

  expect_type(result, "integer")
  expect_identical(result, as.integer(snapshot$badness))
})

test_that("is_bad() gives the reference version's answer for every snapshot input", {
  snapshot <- read_reference("badness.tsv")

  result <- is_bad(snapshot$text)

  expect_identical(result, as.logical(snapshot$is_bad))
})
