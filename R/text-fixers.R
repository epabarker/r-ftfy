# Derived from python-ftfy v6.3.1, ftfy/fixes.py and ftfy/chardata.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# Seven of the nine text fixers. Each has two forms:
#
# - the export, under upstream's name: the entry step, the fixer, then the
#   shape of the input put back;
# - `fixer_<name>()`: the fixer alone. It takes a bare character vector of
#   valid UTF-8 strings and `NA`s and returns one of the same length, with
#   `NA` kept, every changed string marked as UTF-8, and no entry step. The
#   fixer loop and the replay of a plan call this form, found by the name
#   the plan gives the fixer.
#
# Neither form loops over strings.

#' Apply one text fixer
#'
#' Each of these makes one kind of repair to every string of a character
#' vector and changes nothing else. They are the steps that `fix_text()`
#' combines, exported under the names Python ftfy gives them, and each
#' gives what Python ftfy 6.3.1 gives on Python 3.13. None takes an
#' option.
#'
#' * `unescape_html()` decodes HTML entities and numeric character
#'   references that end in a semicolon, such as `&amp;`, `&eacute;` and
#'   `&#8364;`. An entity without its semicolon is left alone, because
#'   informal text such as `"this&not that"` is rarely HTML. The names of
#'   Latin letters and common symbols are also decoded when written in
#'   capitals, so that `P&EACUTE;REZ` gives `"P\u00c9REZ"`. As in a web
#'   browser, a numeric reference from 128 to 159 is read as
#'   Windows-1252.
#' * `remove_terminal_escapes()` removes ANSI terminal escape sequences,
#'   such as those that colour text.
#' * `uncurl_quotes()` replaces curly quotation marks with straight ones.
#' * `fix_latin_ligatures()` replaces single-character ligatures of Latin
#'   letters, such as `"\ufb01"`, with the letters they hold. Ligatures in
#'   other scripts, and those often meant, such as `"\u00e6"`, are left
#'   alone.
#' * `fix_character_width()` replaces halfwidth and fullwidth forms of
#'   ASCII characters, katakana and Hangul with their standard forms, and
#'   the ideographic space U+3000 with a space.
#' * `fix_line_breaks()` turns CRLF, CR, LINE SEPARATOR (U+2028),
#'   PARAGRAPH SEPARATOR (U+2029) and NEXT LINE (U+0085) into `"\n"`.
#' * `remove_control_chars()` removes control characters that are almost
#'   never meant: the ASCII control characters other than tab, line feed,
#'   form feed and carriage return; the deprecated Arabic controls U+206A
#'   to U+206F; the interlinear annotation characters and the object
#'   replacement character, U+FFF9 to U+FFFC; and the byte order mark
#'   U+FEFF. C1 controls, joiners, direction marks and tag characters are
#'   kept.
#'
#' Call these on a whole vector, not once per string.
#'
#' @param x A character vector. Anything else is an error, as is a string
#'   that is not valid UTF-8 or is marked as bytes. A logical vector that
#'   is all `NA` is taken as missing strings.
#'
#' @return A character vector as long as `x`, marked as UTF-8, with the
#'   `names`, `dim` and `dimnames` of `x`. A missing string gives `NA`.
#'
#' @examples
#' unescape_html(c("&lt;tag&gt;", "P&eacute;rez", "P&EACUTE;REZ", "&#x80;5"))
#' unescape_html("&ntilde; &Ntilde; &NTILDE; &nTILDE;")
#'
#' remove_terminal_escapes("\033[36;44mI'm blue, da ba dee da ba doo...\033[0m")
#'
#' uncurl_quotes("\u201chere\u2019s a test\u201d")
#'
#' fix_latin_ligatures("\ufb02u\ufb03e\ufb06")
#'
#' fix_character_width("\uff2c\uff2f\uff35\uff24\u3000\uff2e\uff2f\uff29\uff33\uff25\uff33")
#'
#' fix_line_breaks("Content-type: text/plain\r\n\r\nHi.")
#'
#' remove_control_chars("\ufeffbad \u007fideas")
#' @name text_fixers
NULL

#' @rdname text_fixers
#' @export
unescape_html <- function(x) {
  shape <- entry_shape(x)
  x <- entry_step(x)
  exit_step(fixer_unescape_html(x), shape)
}

#' @rdname text_fixers
#' @export
remove_terminal_escapes <- function(x) {
  shape <- entry_shape(x)
  x <- entry_step(x)
  exit_step(fixer_remove_terminal_escapes(x), shape)
}

#' @rdname text_fixers
#' @export
uncurl_quotes <- function(x) {
  shape <- entry_shape(x)
  x <- entry_step(x)
  exit_step(fixer_uncurl_quotes(x), shape)
}

#' @rdname text_fixers
#' @export
fix_latin_ligatures <- function(x) {
  shape <- entry_shape(x)
  x <- entry_step(x)
  exit_step(fixer_fix_latin_ligatures(x), shape)
}

#' @rdname text_fixers
#' @export
fix_character_width <- function(x) {
  shape <- entry_shape(x)
  x <- entry_step(x)
  exit_step(fixer_fix_character_width(x), shape)
}

#' @rdname text_fixers
#' @export
fix_line_breaks <- function(x) {
  shape <- entry_shape(x)
  x <- entry_step(x)
  exit_step(fixer_fix_line_breaks(x), shape)
}

#' @rdname text_fixers
#' @export
remove_control_chars <- function(x) {
  shape <- entry_shape(x)
  x <- entry_step(x)
  exit_step(fixer_remove_control_chars(x), shape)
}

# --- The fixers alone ------------------------------------------------------

# Upstream's `unescape_html()` (ftfy/fixes.py:94): every match of
# `HTML_ENTITY_RE` is replaced by what `unescape_entities()` makes of it.
fixer_unescape_html <- function(x) {
  # `grepl()` gives FALSE for `NA`, so a missing string is never searched.
  todo <- which(grepl("&", x, fixed = TRUE))
  x[todo] <- replace_matches(x[todo], patterns[["HTML_ENTITY_RE"]], unescape_entities)
  x
}

# Upstream's `remove_terminal_escapes()` (ftfy/fixes.py:145).
fixer_remove_terminal_escapes <- function(x) {
  regex_replace_all(x, patterns[["ANSI_RE"]], "")
}

# Upstream's `uncurl_quotes()` (ftfy/fixes.py:158).
fixer_uncurl_quotes <- function(x) {
  x <- regex_replace_all(x, patterns[["DOUBLE_QUOTE_RE"]], "\"")
  regex_replace_all(x, patterns[["SINGLE_QUOTE_RE"]], "'")
}

# Upstream's `fix_latin_ligatures()` (ftfy/fixes.py:168).
fixer_fix_latin_ligatures <- function(x) {
  translate_characters(x, ligatures)
}

# Upstream's `fix_character_width()` (ftfy/fixes.py:186).
fixer_fix_character_width <- function(x) {
  translate_characters(x, width_map)
}

# Upstream's `fix_line_breaks()` (ftfy/fixes.py:206): its five
# replacements of fixed text, in its order.
fixer_fix_line_breaks <- function(x) {
  for (line_break in c("\r\n", "\r", "\u2028", "\u2029", "\u0085")) {
    x <- gsub(line_break, "\n", x, fixed = TRUE)
  }
  x
}

# Upstream's `remove_control_chars()` (ftfy/fixes.py:297).
fixer_remove_control_chars <- function(x) {
  regex_replace_all(x, code_point_class(control_chars), "")
}

# --- What the fixers are made of -------------------------------------------

# Every match of `pattern` replaced by the text `replacement`, which holds
# neither "$" nor a backslash. `NA` stays `NA`.
regex_replace_all <- function(x, pattern, replacement) {
  regex_guard(
    stringi::stri_replace_all_regex(x, pattern, replacement, opts_regex = regex_opts()),
    x
  )
}

# The pattern that matches one character out of a table of code points.
code_point_class <- function(code_points) {
  paste0("[", paste(sprintf("\\x{%X}", code_points), collapse = ""), "]")
}

# Python's `str.translate()` with a table that maps a character to text:
# a list of `code_point` and `replacement`. The characters that become one
# character are translated in one pass, and the others are spliced in.
# That gives what a single pass gives because no replacement holds a
# character of the table, which the generators check.
translate_characters <- function(x, table) {
  single <- nchar(table$replacement, type = "chars") == 1L
  if (any(single)) {
    x <- translate(
      intToUtf8(table$code_point[single]),
      paste(table$replacement[single], collapse = ""),
      x
    )
  }
  if (!all(single)) {
    from <- intToUtf8(table$code_point[!single], multiple = TRUE)
    to <- table$replacement[!single]
    x <- replace_matches(
      x, code_point_class(table$code_point[!single]),
      function(matched) to[match(matched, from)]
    )
  }
  x
}

# "Locate, compute, splice" (ADR 0008): Python's `pattern.sub(function,
# text)` over a whole vector. Every match of `pattern` in `x` is replaced
# by what `compute` gives for it. `compute` takes the distinct matched
# texts as a character vector and returns the replacement of each, marked
# as UTF-8 where it is not ASCII. `NA` stays `NA`. The splicing is
# `splice_matches()` (R/encoding-fixers.R), so no loop runs over strings
# and the work grows in proportion to the text.
replace_matches <- function(x, pattern, compute) {
  splice_matches(x, pattern, function(matched, whole_length) {
    distinct <- unique(matched)
    compute(distinct)[match(matched, distinct)]
  })
}

# What each matched HTML entity or numeric reference becomes: upstream's
# `_unescape_fixup()` (ftfy/fixes.py:73).
unescape_entities <- function(entity) {
  out <- entity
  named <- match(entity, names(html_entities))
  is_named <- !is.na(named)
  out[is_named] <- html_entities[named[is_named]]
  numeric <- which(!is_named & startsWith(entity, "&#"))
  out[numeric] <- unescape_numeric_references(entity[numeric])
  out
}

# What each text of the form "&#...;" becomes. Upstream passes it to
# Python's `html.unescape()` and keeps the result unless a semicolon is
# left in it. That decodes the reference only when everything between
# "&#" and ";" is decimal digits, or "x" or "X" and then hexadecimal
# digits, and the character it stands for is not the semicolon itself.
# The table `html_numeric`, found by probing the reference version, holds
# every number that does not give the character with that number.
unescape_numeric_references <- function(reference) {
  body <- substring(reference, 3L, nchar(reference) - 1L)
  hex <- startsWith(body, "x") | startsWith(body, "X")
  digits <- substring(body, ifelse(hex, 2L, 1L))
  # Checked without a regex: the digits all become "0".
  zeros <- strrep("0", nchar(digits))
  valid <- nzchar(digits) & ifelse(
    hex,
    chartr("0123456789abcdefABCDEF", "0000000000000000000000", digits) == zeros,
    chartr("0123456789", "0000000000", digits) == zeros
  )

  out <- reference
  # As doubles: up to 24 digits are allowed, and anything above the last
  # code point has one result whatever its exact value.
  number <- as.numeric(paste0(ifelse(hex, "0x", ""), digits)[valid])
  row <- findInterval(number, html_numeric$first)
  listed <- row > 0L
  listed[listed] <- number[listed] <= html_numeric$last[row[listed]]
  decoded <- character(length(number))
  decoded[listed] <- html_numeric$result[row[listed]]
  decoded[!listed] <- intToUtf8(number[!listed], multiple = TRUE)
  # A missing result means the reference is left as it was written.
  kept <- is.na(decoded)
  decoded[kept] <- reference[valid][kept]
  out[valid] <- decoded
  out
}
