# The departure registry, and comparison with reference behaviour.
#
# The registry is the directory inst/departures/ of the package: one file
# `<id>.dcf` per departure. Beside the tests are two more files for each
# entry, found by name and listed nowhere:
#
#   tests/testthat/test-departure-<id>.R   asserts R's behaviour
#   tests/testthat/departures/<id>.R       the matcher: an R file whose value
#       is a function(difference), saying whether one difference from
#       reference behaviour is this departure
#
# A difference is a list with the elements `fun` (the name of the function
# called), `input` (one string), `reference` (what the snapshot holds) and
# `actual` (what R gave, or the condition object if it raised an error).

departure_fields <- c("Id", "Title", "Input", "Reference", "R", "Decided")

departure_dir <- function() {
  dir <- system.file("departures", package = "ftfy")
  if (!nzchar(dir)) {
    stop("the departure registry, inst/departures/, was not found")
  }
  dir
}

# The registry as a data frame, one row per entry, in id order.
read_departures <- function(dir = departure_dir()) {
  files <- sort(list.files(dir, pattern = "[.]dcf$", full.names = TRUE))
  entries <- lapply(files, function(path) {
    entry <- read.dcf(path, all = TRUE)
    if (nrow(entry) != 1L) {
      stop(path, " must hold exactly one entry")
    }
    entry$file <- basename(path)
    entry
  })
  out <- do.call(rbind, lapply(entries, function(entry) {
    entry[setdiff(c(departure_fields, "file"), names(entry))] <- NA_character_
    entry[c(departure_fields, "file")]
  }))
  if (is.null(out)) {
    out <- as.data.frame(
      matrix(character(), 0L, length(departure_fields) + 1L,
             dimnames = list(NULL, c(departure_fields, "file")))
    )
  }
  out
}

# The matcher of every entry in a registry, named by id. `matcher_dir` is
# where the `<id>.R` files are.
departure_matchers <- function(dir = departure_dir(),
                               matcher_dir = test_path("departures")) {
  ids <- read_departures(dir)$Id
  matchers <- lapply(ids, function(id) {
    path <- file.path(matcher_dir, paste0(id, ".R"))
    if (!file.exists(path)) {
      stop("the departure `", id, "` has no matcher: ", path, " is missing")
    }
    matcher <- source(path, local = new.env(parent = globalenv()))$value
    if (!is.function(matcher)) {
      stop(path, " must end in a function(difference)")
    }
    matcher
  })
  names(matchers) <- ids
  matchers
}

# For each input, is R's result reference behaviour, or a difference that a
# registry entry matches? `actual` and `reference` are character vectors as
# long as `input`; where R raised an error, pass the condition through
# `matchers` yourself with `departure_matching()`.
agrees_with_reference <- function(fun, input, actual, reference,
                                  matchers = departure_matchers()) {
  stopifnot(length(actual) == length(input), length(reference) == length(input))
  agrees <- (is.na(actual) & is.na(reference)) |
    (!is.na(actual) & !is.na(reference) & actual == reference)
  for (i in which(!agrees)) {
    difference <- list(
      fun = fun, input = input[[i]],
      reference = reference[[i]], actual = actual[[i]]
    )
    agrees[[i]] <- !is.null(departure_matching(difference, matchers))
  }
  agrees
}

# The id of the first registry entry that matches a difference, or NULL.
departure_matching <- function(difference, matchers = departure_matchers()) {
  for (id in names(matchers)) {
    if (isTRUE(matchers[[id]](difference))) {
      return(id)
    }
  }
  NULL
}

# An expectation: R's results equal the snapshot's, apart from differences
# that a registry entry matches.
expect_reference <- function(fun, input, actual, reference,
                             matchers = departure_matchers()) {
  agrees <- agrees_with_reference(fun, input, actual, reference, matchers)
  bad <- which(!agrees)
  if (length(bad) == 0L) {
    return(invisible(testthat::succeed()))
  }
  shown <- utils::head(bad, 5L)
  show <- function(x) ifelse(is.na(x), "NA", stringi::stri_escape_unicode(x))
  testthat::fail(paste0(
    fun, "() differs from reference behaviour on ", length(bad), " of ",
    length(input), " inputs, and no departure registry entry matches.\n",
    paste0(
      "  [", shown, "] input:     ", show(input[shown]), "\n",
      "       reference: ", show(reference[shown]), "\n",
      "       actual:    ", show(actual[shown]),
      collapse = "\n"
    )
  ))
}
