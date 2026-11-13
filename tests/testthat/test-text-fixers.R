internal_form <- function(fixer) {
  get(paste0("fixer_", fixer), envir = asNamespace("ftfy"), mode = "function")
}

for (fixer in text_fixer_names) {
  local({
    fixer <- fixer
    export <- get(fixer, envir = asNamespace("ftfy"), mode = "function")

    test_that(paste0(fixer, "() gives the reference version's text for every snapshot input"), {
      expect_true(fixer %in% getNamespaceExports("ftfy"))
      snapshot <- read_text_fixer_snapshot(fixer)
      expect_gt(nrow(snapshot), 200)
      # The snapshot is worth something only if the fixer acts in it.
      expect_gt(sum(snapshot$text != snapshot$fixed), 50)

      expect_text_fixer_reference(fixer, export)
    })

    test_that(paste0(fixer, "() gives for a whole vector what it gives for each string alone"), {
      snapshot <- read_text_fixer_snapshot(fixer)
      x <- c(snapshot$text, NA, snapshot$text[1:20], NA)
      whole <- export(x)

      alone <- vapply(x, export, "", USE.NAMES = FALSE)

      expect_identical(whole, alone)
      expect_identical(is.na(whole), is.na(x))
    })

    test_that(paste0("the internal form of ", fixer, " is the export without the entry step"), {
      snapshot <- read_text_fixer_snapshot(fixer)
      x <- c(NA, snapshot$text, NA)

      result <- internal_form(fixer)(x)

      expect_identical(result, export(x))
      expect_null(attributes(result))
      expect_identical(internal_form(fixer)(character()), character())
      expect_identical(internal_form(fixer)(NA_character_), NA_character_)
    })

    test_that(paste0(fixer, "() marks what it returns as UTF-8"), {
      snapshot <- read_text_fixer_snapshot(fixer)

      result <- export(snapshot$text)

      ascii <- stringi::stri_enc_isascii(result)
      expect_true(all(Encoding(result[!ascii]) == "UTF-8"))
    })
  })
}

test_that("every text fixer of this file has an internal form named after its plan name", {
  expect_true(all(text_fixer_names %in% plan_fixers))
  for (fixer in text_fixer_names) {
    expect_true(is.function(internal_form(fixer)))
  }
})

# Seam 2: the tables are the reference version's.

test_that("the HTML entity table has the reference version's 3,501 entries", {
  expect_length(html_entities, 3501L)
  expect_false(anyDuplicated(names(html_entities)) > 0L)
  expect_true(all(startsWith(names(html_entities), "&") & endsWith(names(html_entities), ";")))
  expect_true(all(stringi::stri_enc_isascii(names(html_entities))))
  expect_true(all(nchar(html_entities) %in% 1:3))
  expect_identical(html_entities[["&amp;"]], "&")
  expect_identical(html_entities[["&EURO;"]], "\u20ac")
  expect_identical(html_entities[["&NotEqualTilde;"]], "\u2242\u0338")
})

test_that("numeric HTML references are stored only where the result is not the character itself", {
  expect_true(all(html_numeric$first <= html_numeric$last))
  expect_true(all(html_numeric$first[-1L] > html_numeric$last[-nrow(html_numeric)]))
  expect_identical(html_numeric$last[[nrow(html_numeric)]], Inf)
  expect_identical(html_numeric$first[[nrow(html_numeric)]], 0x110000)

  # No stored result is the character with that number.
  one <- html_numeric[html_numeric$first == html_numeric$last, ]
  expect_false(any(one$result == intToUtf8(one$first, multiple = TRUE), na.rm = TRUE))
  # The table is ranges: far fewer rows than the 2,171 code points it covers.
  expect_lt(nrow(html_numeric), 100L)
  listed <- sum(html_numeric$last[-nrow(html_numeric)] - html_numeric$first[-nrow(html_numeric)] + 1)
  expect_identical(listed, 2171)

  # Only the semicolon is left as written.
  expect_identical(html_numeric$first[is.na(html_numeric$result)], 59)
  expect_identical(html_numeric$result[html_numeric$first == 0x80], "\u20ac")
  expect_identical(html_numeric$result[html_numeric$first == 0xD800], "\ufffd")
  expect_identical(html_numeric$last[html_numeric$first == 0xD800], 0xDFFF)
})

test_that("the ligatures, the width map and the control characters have the reference version's sizes", {
  expect_length(ligatures$code_point, 22L)
  expect_length(ligatures$replacement, 22L)
  expect_length(width_map$code_point, 226L)
  expect_length(width_map$replacement, 226L)
  expect_length(control_chars, 40L)

  expect_identical(ligatures$replacement[ligatures$code_point == 0xFB03], "ffi")
  expect_identical(width_map$replacement[width_map$code_point == 0x3000], " ")
  expect_identical(width_map$replacement[width_map$code_point == 0xFFE3], " \u0304")
  expect_true(all(c(0L, 0x7FL, 0x206AL, 0xFEFFL, 0xFFFCL) %in% control_chars))
  expect_false(any(c(0x09L, 0x0AL, 0x0CL, 0x0DL, 0x85L) %in% control_chars))
})

test_that("no replacement of a translate table holds a character of that table", {
  # One pass of chartr() and one splice then give what str.translate() gives.
  for (table in list(ligatures, width_map)) {
    replaced <- utf8ToInt(paste(table$replacement, collapse = ""))
    expect_false(any(replaced %in% table$code_point))
  }
})

# R-only behaviour of the fixers.

test_that("unescape_html() replaces a string that is one removed reference by an empty string", {
  expect_identical(unescape_html(c("&#xffff;", NA, "&#1;&#2;")), c("", NA, ""))
})

test_that("unescape_html() handles strings with different numbers of entities in one call", {
  x <- c(
    "none", "&amp;", "a&lt;b&gt;c", NA, strrep("&amp;x", 1000), "", "&amp;&amp;&amp;",
    "\ufeff&eacute;", "&bogus;&amp;"
  )

  expect_identical(
    unescape_html(x),
    c("none", "&", "a<b>c", NA, strrep("&x", 1000), "", "&&&", "\ufeff\u00e9", "&bogus;&")
  )
})

test_that("unescape_html() decodes a reference once and does not look at its result again", {
  expect_identical(unescape_html("&amp;lt; &#38;amp; &#x26;#65;"), "&lt; &amp; &#65;")
})

test_that("a leading U+FEFF reaches remove_control_chars() as data", {
  # The fixer removes U+FEFF, so its result cannot show that the entry step
  # kept the character. With the fixer replaced by one that changes
  # nothing, the text the entry step handed over comes back.
  local_mocked_bindings(fixer_remove_control_chars = function(x) x)

  expect_identical(remove_control_chars(c("\ufeffa", "b")), c("\ufeffa", "b"))
})

test_that("only remove_control_chars() takes a leading U+FEFF away", {
  x <- "\ufeff\ufeffcaf\u00e9"
  for (fixer in setdiff(text_fixer_names, "remove_control_chars")) {
    export <- get(fixer, envir = asNamespace("ftfy"), mode = "function")
    expect_identical(export(x), x)
  }
  expect_identical(remove_control_chars(x), "caf\u00e9")
})
