# The entry-step test set: what every export that takes text must do with
# its input before any other work (the resolution of issue #12, ADR 0006).
#
# An export joins the set with one file of its own, found by name and
# listed nowhere:
#
#   tests/testthat/entry-step/<export>.R
#
# The value of the file is a list, its registration:
#
#   call     function(x): calls the export on the text `x`, with every
#            other argument at its default (or at a fixed valid value, if
#            it has no default).
#   returns  "character", "integer" or "logical": the type of the result
#            that runs parallel to `x`.
#   value    optional function(result): takes that parallel vector out of
#            what `call` returns. Leave it out when the export returns the
#            vector itself; an export returning a data frame gives
#            `function(result) result$text`.
#   shape    optional, default TRUE: whether `names`, `dim` and `dimnames`
#            of `x` are kept on the result. FALSE only for an export that
#            returns a data frame.
#   feff     list(x =, value =): texts, at least one with a leading U+FEFF,
#            and the parallel result that shows U+FEFF was treated as data.
#            Optional when `returns` is "character": the default expects a
#            text with a leading U+FEFF to come back unchanged. An export
#            whose defaults remove U+FEFF must give one in which it stays
#            (and may switch that fixer off in `call`).
#
# An export that takes no text to repair is exempted with a file of the
# same name whose value is `list(exempt = "<the reason>")`.
#
# test-entry.R runs the set over every registration and fails when an
# export has no file.

entry_step_dir <- function() {
  test_path("entry-step")
}

# Every registration, named by export, in name order.
entry_step_registrations <- function(dir = entry_step_dir()) {
  files <- sort(list.files(dir, pattern = "[.]R$", full.names = TRUE))
  registrations <- lapply(files, function(path) {
    source(path, local = TRUE)$value
  })
  names(registrations) <- sub("[.]R$", "", basename(files))
  registrations
}

# What is wrong with one registration, as a character vector of problems;
# empty when it is complete.
entry_step_registration_problems <- function(registration) {
  if (!is.list(registration)) {
    return("the value of the file is not a list")
  }
  if (!is.null(registration$exempt)) {
    ok <- is.character(registration$exempt) &&
      length(registration$exempt) == 1L && nzchar(registration$exempt) &&
      length(registration) == 1L
    if (ok) {
      return(character())
    }
    return("`exempt` must be the only element, a string giving the reason")
  }
  problems <- character()
  unknown <- setdiff(
    names(registration), c("call", "returns", "value", "shape", "feff")
  )
  if (length(unknown) > 0L) {
    problems <- c(problems, paste0("unknown element `", unknown, "`"))
  }
  if (!is.function(registration$call)) {
    problems <- c(problems, "`call` must be a function(x)")
  }
  returns <- registration$returns
  if (!(is.character(returns) && length(returns) == 1L &&
          returns %in% c("character", "integer", "logical"))) {
    return(c(
      problems,
      "`returns` must be \"character\", \"integer\" or \"logical\""
    ))
  }
  if (!is.null(registration$value) && !is.function(registration$value)) {
    problems <- c(problems, "`value` must be a function(result)")
  }
  if (!is.null(registration$shape) &&
        !(isTRUE(registration$shape) || isFALSE(registration$shape))) {
    problems <- c(problems, "`shape` must be TRUE or FALSE")
  }
  feff <- registration$feff
  if (is.null(feff)) {
    if (returns != "character") {
      problems <- c(
        problems, "`feff` is needed unless `returns` is \"character\""
      )
    }
  } else if (!(is.list(feff) && is.character(feff$x) &&
                 typeof(feff$value) == returns &&
                 length(feff$x) == length(feff$value) &&
                 any(startsWith(feff$x, "\ufeff"), na.rm = TRUE))) {
    problems <- c(problems, paste0(
      "`feff` must be list(x =, value =): texts, one or more starting with ",
      "U+FEFF, and the parallel result of type `returns`"
    ))
  }
  problems
}

# The same text under each mark. `utf8` is the text every other element
# must be read as. `native` is an unmarked string in the session's native
# encoding, or NULL when that is neither UTF-8 nor Latin-1.
entry_step_marked <- function() {
  utf8 <- "caf\u00e9 \u00a3 \u00c3\u00a9"
  latin1 <- iconv(utf8, from = "UTF-8", to = "ISO-8859-1")
  Encoding(latin1) <- "latin1"
  native <- NULL
  if (l10n_info()[["UTF-8"]]) {
    native <- utf8
    Encoding(native) <- "unknown"
  } else if (l10n_info()[["Latin-1"]]) {
    native <- latin1
    Encoding(native) <- "unknown"
  }
  list(utf8 = utf8, latin1 = latin1, native = native)
}

entry_step_invalid <- function() {
  x <- c("fine", "caf\xe9", NA, "\xc3\x28", "plain")
  Encoding(x) <- "UTF-8"
  x
}

# Runs the whole set on one export. `name` is the export's name and
# `registration` its registration (not an exemption).
test_entry_step <- function(name, registration) {
  call <- registration$call
  type <- registration$returns
  take <- if (is.null(registration$value)) identity else registration$value
  keeps_shape <- !isFALSE(registration$shape)
  run <- function(x) take(call(x))
  missing_value <- vector(type, 1L)
  missing_value[] <- NA
  label <- function(what) paste0(name, "(): ", what)

  test_that(label("a missing string gives NA of the result's type, with no warning"), {
    expect_no_warning(result <- run(c("plain", NA, "caf\u00e9", NA)))
    expect_type(result, type)
    expect_length(result, 4L)
    expect_identical(is.na(as.vector(result)), c(FALSE, TRUE, FALSE, TRUE))
    expect_identical(
      as.vector(result)[c(1L, 3L)], as.vector(run(c("plain", "caf\u00e9")))
    )
    expect_identical(as.vector(run(NA_character_)), missing_value)
  })

  test_that(label("an all-NA logical vector is treated as character NA"), {
    expect_no_warning(result <- run(NA))
    expect_identical(result, run(NA_character_))
    expect_identical(run(c(NA, NA, NA)), run(rep(NA_character_, 3L)))
    if (keeps_shape) {
      expect_identical(
        run(c(a = NA, b = NA)), run(c(a = NA_character_, b = NA_character_))
      )
    }
  })

  test_that(label("a zero-length input gives a zero-length result"), {
    expect_identical(as.vector(run(character())), vector(type, 0L))
    expect_identical(as.vector(run(logical())), vector(type, 0L))
  })

  test_that(label("a leading U+FEFF is data, not something to strip"), {
    feff <- registration$feff
    if (is.null(feff)) {
      x <- c("\ufeffplain", "\ufeffcaf\u00e9", "\ufeff", "plain")
      feff <- list(x = x, value = x)
    }
    expect_identical(as.vector(run(feff$x)), feff$value)
  })

  test_that(label("ASCII and UTF-8-marked strings are taken as they are"), {
    marked <- entry_step_marked()
    expect_identical(Encoding(marked$utf8), "UTF-8")
    expect_no_error(run(c("plain", marked$utf8)))
  })

  test_that(label("a latin1-marked string is read as its text"), {
    marked <- entry_step_marked()
    expect_identical(Encoding(marked$latin1), "latin1")
    expect_identical(run(marked$latin1), run(marked$utf8))
  })

  test_that(label("a latin1 mark is read as ISO 8859-1, not Windows-1252"), {
    # Bytes 80 to 9F enter as U+0080 to U+009F (ADR 0006). `enc2utf8()`
    # would read 80 as U+20AC and the hole 81 as the four characters "<81>".
    x <- c("\x80 x", "\x81 x", "\x9f x", "a\x85b\x91c\xa0\xff")
    Encoding(x) <- "latin1"
    as_text <- c(
      "\u0080 x", "\u0081 x", "\u009f x", "a\u0085b\u0091c\u00a0\u00ff"
    )
    expect_identical(run(x), run(as_text))

    hole <- "\x81\x81\x81 \x81\x81\x81"
    Encoding(hole) <- "latin1"
    expect_false(identical(run(hole), run("<81><81><81> <81><81><81>")))
  })

  test_that(label("an unmarked non-ASCII string is read in the native encoding"), {
    marked <- entry_step_marked()
    if (is.null(marked$native)) {
      skip("the native encoding of this session is neither UTF-8 nor Latin-1")
    }
    expect_identical(Encoding(marked$native), "unknown")
    expect_identical(run(marked$native), run(marked$utf8))
  })

  test_that(label("strings of every mark may be mixed in one vector"), {
    marked <- entry_step_marked()
    x <- c(marked$utf8, marked$latin1, marked$native, "plain", NA)
    expected <- c(
      rep(as.vector(run(marked$utf8)), length(x) - 2L),
      as.vector(run("plain")), missing_value
    )
    result <- run(x)
    expect_identical(as.vector(result), expected)
    if (type == "character") {
      # All text output is marked UTF-8; ASCII carries no mark.
      expect_identical(
        Encoding(result),
        ifelse(
          is.na(result) | stringi::stri_enc_isascii(result), "unknown", "UTF-8"
        )
      )
      expect_true(all(stringi::stri_enc_isutf8(result[!is.na(result)])))
    }
  })

  test_that(label("a bytes-marked string is an error pointing to Encoding<- and iconv()"), {
    x <- c("fine", "caf\xe9", NA, "abc\xff")
    Encoding(x) <- c("unknown", "bytes", "unknown", "bytes")
    expect_identical(Encoding(x), c("unknown", "bytes", "unknown", "bytes"))

    expect_error(call(x), "marked as bytes in 2 of 4 elements.*first at: 2, 4")
    expect_error(call(x), "Encoding<-", fixed = TRUE)
    expect_error(call(x), "iconv()", fixed = TRUE)
  })

  test_that(label("invalid UTF-8 is an error naming the first offending elements"), {
    x <- entry_step_invalid()
    expect_error(
      call(x),
      "invalid UTF-8 in 2 of 5 elements.*first at: 2, 4.*wrong codec"
    )
    # No more than the first five are named.
    many <- rep(x[[2L]], 8L)
    expect_error(call(many), "in 8 of 8 elements.*first at: 1, 2, 3, 4, 5[)]")
  })

  test_that(label("anything but a character vector is an error suggesting as.character()"), {
    rejected <- list(
      factor = factor("caf\u00c3\u00a9"), double = 1, integer = 1L,
      logical = TRUE, `logical with an NA` = c(NA, TRUE), list = list("a"),
      `NULL` = NULL, raw = as.raw(1), date = as.Date("2024-01-01"),
      `data frame` = data.frame(a = "a"), `function` = identity
    )
    for (what in names(rejected)) {
      expect_error(
        call(rejected[[what]]), "as.character()", fixed = TRUE, label = what
      )
    }
  })

  test_that(label("names, dim and dimnames are kept and every other attribute dropped"), {
    values <- c(
      "caf\u00c3\u00a9", NA, "plain", "\u00e2\u0080\u0099", "", "caf\u00e9"
    )
    plain <- as.vector(run(values))
    expect_null(attributes(run(values)))

    if (!keeps_shape) {
      # A data frame carries no names: the texts are the same, no more.
      expect_identical(
        as.vector(run(stats::setNames(values, letters[1:6]))), plain
      )
      expect_identical(as.vector(run(matrix(values, 2L))), plain)
      return(invisible())
    }

    named <- stats::setNames(values, c("a", "b", "", NA, "e", "\u00e9"))
    expect_identical(run(named), stats::setNames(plain, names(named)))

    grid <- matrix(
      values, nrow = 2L, dimnames = list(c("r1", "r2"), c("x", "y", "z"))
    )
    expected <- plain
    attributes(expected) <- attributes(grid)
    expect_identical(run(grid), expected)

    bare_grid <- array(values, dim = c(1L, 3L, 2L))
    expect_identical(dim(run(bare_grid)), c(1L, 3L, 2L))
    expect_identical(as.vector(run(bare_grid)), plain)

    empty <- matrix(
      character(), nrow = 0L, ncol = 3L, dimnames = list(NULL, c("x", "y", "z"))
    )
    expect_identical(attributes(run(empty)), attributes(empty))

    dressed <- structure(named, class = "some_class", note = "dropped")
    expect_identical(run(dressed), stats::setNames(plain, names(named)))
  })
}
