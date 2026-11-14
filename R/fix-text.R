# Derived from python-ftfy v6.3.1, ftfy/__init__.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

#' Fix text
#'
#' `fix_text()` repairs the glitches in each string of a character vector
#' and gives back the text Python ftfy 6.3.1 gives: mojibake is decoded
#' with the codec it was meant for, HTML entities become the characters
#' they stand for, and ligatures, fullwidth characters, curly quotes, odd
#' line breaks, terminal escapes and invisible control characters are
#' replaced or removed. Text that needs none of this comes back as it was.
#'
#' Each string is fixed in segments. A segment is one line with the
#' newline that ends it, or, when a line is longer than the option
#' `max_decode_length`, a piece of it of at most that many characters. Each
#' segment is fixed by itself, as [fix_and_explain()] fixes a whole
#' string, and the fixed segments are joined again. So mojibake is looked
#' for line by line, and a line mis-decoded with one codec does not keep
#' the repair from a line mis-decoded with another.
#'
#' With `unescape_html = "auto"`, the default, HTML entities are replaced
#' until a segment holds a `<`, which is taken to mean that the text is
#' HTML: in that segment and in every later segment of the same string
#' they are left alone. One string never affects another: Python ftfy's
#' `fix_file()` carries this from each line of a file to the lines after
#' it, and nothing here does the same across the elements of a vector
#' (see [ftfy][ftfy-package]).
#'
#' `fix_text()` does not say what it did. [fix_and_explain()] does, for
#' strings taken whole.
#'
#' Call it on a whole vector, not once per string: each call on text that
#' is not plain ASCII has a fixed cost of one or two milliseconds,
#' however long the vector (see [ftfy][ftfy-package] for the
#' measurements). A value that occurs many times is fixed once.
#'
#' @section Differences from Python ftfy:
#' The options `restore_byte_a0`, `replace_lossy_sequences`,
#' `decode_inconsistent_utf8` and `fix_c1_controls` are honoured. In Python
#' ftfy 6.3.1, `fix_text(text, restore_byte_a0=False)` repairs the encoding
#' as if the option had not been given; it is honoured there only when it
#' comes in a `TextFixerConfig` object.
#'
#' A line that ends just after the byte C0, or after the first five bytes
#' of a six-byte surrogate pair, is not repaired by reading its newline as
#' the missing byte, which in Python ftfy loses the newline and joins the
#' line to the next. Where the encoding repair decodes the two bytes
#' C0 80, which stand for the character U+0000, nothing is put in their
#' place. And normalisation is done by the ICU library that stringi was
#' built with, so text that holds characters newer than that library's
#' version of Unicode can be normalised differently from Python 3.13, which
#' has Unicode 15.1.
#'
#' Every departure from the reference version is listed, with examples,
#' on the page [ftfy-differences].
#'
#' @inheritParams fix_encoding
#'
#' @return A character vector as long as `x`, marked as UTF-8, with the
#'   `names`, `dim` and `dimnames` of `x`. A missing string gives `NA`.
#'
#' @examples
#' x <- c("caf\u00c3\u00a9", "&lt;3 \u201cquotes\u201d", "plain", NA)
#' fix_text(x)
#'
#' # One option changed for this call
#' fix_text(x, uncurl_quotes = FALSE)
#'
#' # Each line is fixed by itself; after a line with a "<", entities stay
#' fix_text("caf\u00c3\u00a9 &amp; \u2603\n<b>caf\u00c3\u00a9</b>\n&amp;")
#' @export
fix_text <- function(x, ..., config = ftfy_config()) {
  shape <- entry_shape(x)
  x <- entry_step(x)
  config <- resolve_config(..., config = config)
  # Each distinct value is fixed once (ADR 0008).
  distinct <- unique(x)
  fixed <- fix_text_values(distinct, config)
  exit_step(fixed[match(x, distinct)], shape)
}

# Upstream's `fix_text()` (ftfy/__init__.py:290) over a vector: `x` is a
# bare character vector of valid UTF-8 strings and `NA`s, `config` the
# resolved options. Every string is cut into its segments, the segments of
# the whole vector are fixed together by `fix_segments()`, each distinct
# one once, and the fixed segments of a string are pasted together again.
# Nothing here loops over strings.
fix_text_values <- function(x, config) {
  # The screen of ADR 0008: a value no fixer can change is not even cut.
  todo <- which(could_change(x))
  if (length(todo) == 0L) {
    return(x)
  }
  text <- x[todo]
  # A string that is one line of no more than `max_decode_length`
  # characters is its own single segment and is not cut. A newline at its
  # end keeps it one segment too, but such a string is rare enough to go
  # the long way with the others.
  cut <- grepl("\n", text, fixed = TRUE) |
    nchar(text, type = "chars") > config$max_decode_length
  whole <- which(!cut)
  cut <- which(cut)
  pieces <- cut_segments(text[cut], config$max_decode_length)

  segment <- c(text[whole], pieces$segment)
  override <- NULL
  if (identical(config$unescape_html, "auto")) {
    # A segment that holds "<" switches `unescape_html` off for itself and
    # for every later segment of its string (ftfy/__init__.py:356): the
    # fixer runs on a segment while no segment of its string up to and
    # including it has held one.
    holds <- grepl("<", segment, fixed = TRUE)
    held <- cumsum(holds[length(whole) + seq_along(pieces$segment)])
    first <- which(!duplicated(pieces$owner))
    before <- (held - holds[length(whole) + seq_along(pieces$segment)])[first]
    override <- c(!holds[seq_along(whole)], held - before[pieces$owner] == 0)
    # Each distinct pair of a segment and its switch is fixed once.
    distinct_text <- unique(segment)
    pair <- 2 * match(segment, distinct_text) + override
    distinct <- unique(pair)
    fixed <- fix_segments(
      distinct_text[distinct %/% 2], config,
      unescape_html = distinct %% 2 == 1
    )$text[match(pair, distinct)]
  } else {
    distinct <- unique(segment)
    fixed <- fix_segments(distinct, config)$text[match(segment, distinct)]
  }

  text[whole] <- fixed[seq_along(whole)]
  if (length(cut) > 0L) {
    text[cut] <- paste_runs(fixed[length(whole) + seq_along(pieces$segment)], pieces$owner)
  }
  x[todo] <- text
  x
}

# The most bytes of text whose code points `cut_segments()` holds at once.
segment_batch_bytes <- function() 2^26

# Cut each string of `x` into its segments (ftfy/__init__.py:346): a line
# with its newline, or, where a line is longer than `max_length`
# characters, pieces of `max_length` characters counted from the start of
# the line, the last one shorter and holding the newline. `x` has no `NA`
# and no empty string. Returns `segment`, every segment of every string in
# order, and `owner`, the position in `x` of the string each is cut from.
#
# The cuts are located from where the newlines are among the code points
# of the strings joined into one, and the pieces are cut by
# `character_cutter()` (R/encoding-fixers.R), whose time does not grow with
# the square of the number of lines in one string.
#
# The strings are taken in batches of about `segment_batch_bytes()` bytes
# so that the code points of a large vector are never all held at once and
# the joined string stays below R's limit on one string. The loop is over
# batches, not strings; a vector below that size is one batch.
cut_segments <- function(x, max_length) {
  if (length(x) == 0L) {
    return(list(segment = character(), owner = integer()))
  }
  batch <- cumsum(nchar(x, type = "bytes")) %/% segment_batch_bytes()
  batches <- unname(split(seq_along(x), batch))
  cut <- lapply(batches, function(at) {
    pieces <- cut_segments_batch(x[at], max_length)
    pieces$owner <- at[pieces$owner]
    pieces
  })
  list(
    segment = unlist(lapply(cut, `[[`, "segment"), use.names = FALSE),
    owner = unlist(lapply(cut, `[[`, "owner"), use.names = FALSE)
  )
}

cut_segments_batch <- function(x, max_length) {
  cutter <- character_cutter(x)
  # Positions are counted in characters of the joined strings, as doubles.
  # A line ends at each newline and at the end of each string.
  string_end <- cumsum(as.numeric(cutter$characters))
  line_end <- sort(unique(c(which(cutter$code_points == 10L), string_end)))
  line_start <- c(1, line_end[-length(line_end)] + 1)
  # A line longer than `max_length` is cut every `max_length` characters.
  count <- ceiling((line_end - line_start + 1) / max_length)
  line <- rep.int(seq_along(count), count)
  start <- line_start[line] + (sequence(count) - 1) * max_length
  end <- pmin(start + max_length - 1, line_end[line])
  owner <- findInterval(start, string_end, left.open = TRUE) + 1L
  before <- string_end[owner] - cutter$characters[owner]
  list(segment = cutter$cut(owner, start - before, end - before), owner = owner)
}
