# Attribution and credit (ADR 0012, resolution of #17): the copyrights
# file, the citation, the README, the README beside the upstream JSON cases,
# and the absence of a licence or notice file in what is built.

# Robyn Speer's citation, from the README of python-ftfy v6.3.1 ("Citing
# ftfy"). It is never updated here: the version and year are hers.
speer_citation <- "Robyn Speer. (2019). ftfy (Version 5.5). Zenodo. http://doi.org/10.5281/zenodo.2591652"

source_root <- function() test_path("..", "..")

# The README, .Rbuildignore and the repository's own files are only beside
# the tests in the source tree. The R CMD check workflow runs this file from
# the checkout with FTFY_SOURCE_TREE=true, where a skip would hide a failure.
skip_unless_source_tree <- function() {
  if (is_source_tree(source_root())) {
    return(invisible())
  }
  if (identical(Sys.getenv("FTFY_SOURCE_TREE"), "true")) {
    stop("FTFY_SOURCE_TREE is true, but R/ and data-raw/ are not beside the tests.")
  }
  skip("Not run from the package's source tree.")
}

read_citation <- function() {
  utils::readCitationFile(
    system.file("CITATION", package = "ftfy", mustWork = TRUE),
    meta = utils::packageDescription("ftfy")
  )
}

copyrights <- function() {
  readLines(system.file("COPYRIGHTS", package = "ftfy", mustWork = TRUE), warn = FALSE)
}

# The copyrights file.

test_that("DESCRIPTION points to the copyrights file, and credits Robyn Speer as author and copyright holder", {
  meta <- utils::packageDescription("ftfy")

  expect_identical(meta$Copyright, "See file inst/COPYRIGHTS")
  expect_identical(meta$License, "Apache License (== 2.0)")
  people <- eval(parse(text = meta[["Authors@R"]]))
  speer <- people[vapply(people, function(p) identical(p$family, "Speer"), logical(1))]
  expect_length(speer, 1L)
  expect_identical(speer$given, "Robyn")
  expect_setequal(speer$role, c("aut", "cph"))
  expect_identical(unname(speer$comment), "Author of Python ftfy, of which this package is a port")
})

test_that("the copyrights file keeps upstream's copyright line on a line of its own", {
  expect_true("Copyright 2023 Robyn Speer" %in% trimws(copyrights()))
})

test_that("the copyrights file names the source, its version and its licence", {
  text <- paste(copyrights(), collapse = "\n")

  expect_match(text, "python-ftfy v6.3.1", fixed = TRUE)
  expect_match(text, "https://github.com/rspeer/python-ftfy", fixed = TRUE)
  expect_match(text, "Apache License, Version 2.0", fixed = TRUE)
})

test_that("the copyrights file says the material was translated and modified, and points to the departure registry", {
  text <- paste(copyrights(), collapse = "\n")

  expect_match(text, "translated from Python to R and modified", fixed = TRUE)
  expect_match(text, "departure registry", fixed = TRUE)
  expect_match(text, "inst/departures/", fixed = TRUE)
  # The directory it points to is there.
  expect_true(dir.exists(system.file("departures", package = "ftfy")))
})

test_that("the copyrights file lists each group of derived files", {
  text <- paste(copyrights(), collapse = "\n")

  for (group in c("tests/testthat/upstream/test_cases.json", "R/*.R", "man/*.Rd",
                  "tests/testthat/*.R", "R/sysdata.rda", "tests/testthat/reference/*",
                  "data-raw/")) {
    expect_match(text, group, fixed = TRUE, info = group)
  }
})

test_that("CPython and Unicode data are named as sources, with no copyright line and no licence of their own", {
  lines <- copyrights()
  text <- paste(lines, collapse = "\n")

  expect_match(text, "CPython", fixed = TRUE)
  expect_match(text, "Unicode", fixed = TRUE)
  expect_match(text, "sources and not[[:space:]]+licensors")
  # The only copyright lines are upstream's and the port's.
  holders <- grep("^[[:space:]]*Copyright [0-9]{4}", lines, value = TRUE)
  expect_true(all(grepl("Robyn Speer|Ed Barker", holders)))
  expect_no_match(text, "PSF|Python Software Foundation|Unicode License|Unicode, Inc")
})

test_that("the copyrights and citation files are ASCII", {
  for (file in c("COPYRIGHTS", "CITATION")) {
    lines <- readLines(system.file(file, package = "ftfy", mustWork = TRUE), warn = FALSE)
    expect_true(all(stringi::stri_enc_isascii(lines)), info = file)
  }
})

# The citation.

test_that("the citation gives Robyn Speer's Zenodo citation first, in her wording", {
  first <- read_citation()[[1]]

  expect_identical(first$textVersion, speer_citation)
  # What a user sees printed is her sentence, not R's rendering of the fields.
  shown <- paste(format(first, style = "citation"), collapse = " ")
  expect_match(gsub("[[:space:]]+", " ", shown), speer_citation, fixed = TRUE)
})

test_that("her citation's fields are those of her BibTeX entry, version unchanged", {
  first <- read_citation()[[1]]
  fields <- unclass(first)[[1]]

  expect_identical(attr(fields, "bibtype"), "Misc")
  expect_identical(attr(fields, "key"), "speer-2019-ftfy")
  expect_identical(format(first$author), "Robyn Speer")
  expect_identical(first$title, "ftfy")
  expect_identical(first$note, "Version 5.5")
  expect_identical(first$year, "2019")
  expect_identical(first$howpublished, "Zenodo")
  expect_identical(first$doi, "10.5281/zenodo.2591652")
  expect_identical(first$url, "https://doi.org/10.5281/zenodo.2591652")
})

test_that("an entry for the R package follows, and nothing else", {
  citation <- read_citation()
  meta <- utils::packageDescription("ftfy")

  expect_length(citation, 2L)
  second <- citation[[2]]
  expect_match(second$title, "ftfy", fixed = TRUE)
  expect_match(second$note, paste("R package version", meta$Version), fixed = TRUE)
  expect_match(second$note, meta[["Config/ftfy/upstream"]], fixed = TRUE)
  expect_match(second$year, "^[0-9]{4}$")
  expect_true("Robyn Speer" %in% format(second$author))
})

test_that("the citation file can be read from a DESCRIPTION with no date at all", {
  meta <- utils::packageDescription("ftfy")
  meta$Date <- NULL
  meta$Packaged <- NULL
  meta[["Date/Publication"]] <- NULL

  citation <- utils::readCitationFile(system.file("CITATION", package = "ftfy"), meta = meta)

  expect_length(citation, 2L)
  expect_match(citation[[2]]$year, "^[0-9]{4}$")
})

# The README beside the upstream JSON cases. That the JSON file itself is
# byte for byte is pinned by its md5 in test-json-cases.R.

test_that("a README beside the upstream JSON cases says where they came from", {
  path <- test_path("upstream", "README")
  expect_true(file.exists(path))
  text <- paste(readLines(path, warn = FALSE), collapse = " ")

  expect_match(text, "tests/test_cases.json", fixed = TRUE)
  expect_match(text, "python-ftfy v6.3.1", fixed = TRUE)
  expect_match(text, "https://github.com/rspeer/python-ftfy", fixed = TRUE)
  expect_match(text, "byte for byte", fixed = TRUE)
  expect_match(text, "Copyright 2023 Robyn Speer", fixed = TRUE)
  expect_match(text, "Apache-2.0", fixed = TRUE)
})

# No licence file and no notice file.

licence_like <- function(names) {
  grep("^(licen[sc]e|notice|copying)([.].*)?$", names, ignore.case = TRUE, value = TRUE)
}

test_that("the installed package has no licence file and no notice file", {
  shipped <- list.files(system.file(package = "ftfy"), recursive = TRUE)

  expect_identical(licence_like(basename(shipped)), character())
})

test_that("every licence or notice file in the repository is kept out of the build", {
  skip_unless_source_tree()
  root <- source_root()
  ignore <- readLines(file.path(root, ".Rbuildignore"), warn = FALSE)
  ignore <- ignore[nzchar(ignore)]
  # R CMD build matches each line against the path from the package root,
  # as a Perl regex, ignoring case. A file is out when it, or a directory
  # above it, matches.
  ignored <- function(path) {
    parts <- strsplit(path, "/", fixed = TRUE)[[1]]
    prefixes <- vapply(seq_along(parts), function(i) paste(parts[seq_len(i)], collapse = "/"), character(1))
    any(vapply(ignore, function(p) any(grepl(p, prefixes, perl = TRUE, ignore.case = TRUE)), logical(1)))
  }

  expect_true(ignored("LICENSE"))
  expect_false(ignored("inst/COPYRIGHTS"))
  files <- list.files(root, recursive = TRUE, all.files = TRUE)
  files <- files[!startsWith(files, ".git/")]
  found <- files[basename(files) %in% licence_like(basename(files))]
  kept <- found[!vapply(found, ignored, logical(1))]
  expect_identical(unname(kept), character())
  # Upstream has no notice file, so there is none anywhere.
  expect_false(any(grepl("^notice", basename(files), ignore.case = TRUE)))
})

# The README.

readme <- function() readLines(file.path(source_root(), "README.md"), warn = FALSE, encoding = "UTF-8")

test_that("the README opens with the sentence of #27", {
  skip_unless_source_tree()
  lines <- readme()
  prose <- lines[nzchar(trimws(lines)) & !startsWith(lines, "#")]

  expect_identical(
    prose[1],
    paste(
      "ftfy for R is a port of [ftfy](https://github.com/rspeer/python-ftfy) by Robyn Speer.",
      "The heuristic, its test cases and most of its data are her work."
    )
  )
  # Nothing but the title comes before it.
  before <- lines[seq_len(match(prose[1], lines) - 1L)]
  expect_true(all(!nzchar(trimws(before)) | startsWith(before, "# ftfy")))
})

test_that("the README says plainly that the port was written with AI assistance", {
  skip_unless_source_tree()

  expect_true(any(grepl("The port was written with AI assistance.", readme(), fixed = TRUE)))
})

test_that("the README names the reference version recorded in DESCRIPTION", {
  skip_unless_source_tree()
  upstream <- utils::packageDescription("ftfy")[["Config/ftfy/upstream"]]

  expect_identical(upstream, "6.3.1")
  expect_true(any(grepl(paste("reference version is ftfy", upstream), readme(), fixed = TRUE)))
})

test_that("the README has a Citing section with her citation unchanged", {
  skip_unless_source_tree()
  lines <- readme()

  start <- match("## Citing", lines)
  expect_false(is.na(start))
  rest <- lines[-seq_len(start)]
  next_section <- match(TRUE, startsWith(rest, "## "), nomatch = length(rest) + 1L)
  section <- gsub("[[:space:]]+", " ", paste(trimws(rest[seq_len(next_section - 1L)]), collapse = " "))
  expect_match(section, speer_citation, fixed = TRUE)
  expect_match(section, "note = {Version 5.5},", fixed = TRUE)
  expect_match(section, "doi = {10.5281/zenodo.2591652},", fixed = TRUE)
})
