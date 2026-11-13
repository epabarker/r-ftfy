# Derived from python-ftfy v6.3.1, ftfy/__init__.py. Copyright 2023 Robyn Speer. Apache-2.0. Translated to R and modified; see inst/COPYRIGHTS.

# Options (ADR 0001). Upstream's `TextFixerConfig` (ftfy/__init__.py:91) and
# `_config_from_kwargs()` (ftfy/__init__.py:230).
#
# A core function takes `(x, ..., config = ftfy_config())` and calls
# `resolve_config(..., config = config)` once. What comes back is the one complete,
# validated config object, which internal code receives whole.

# The 14 options and their defaults, in upstream's order. Upstream's
# `explain`, `fix_surrogates` and the deprecated alias `fix_entities` have
# no counterpart. This list is the only copy of the option names.
option_defaults <- function() {
  list(
    unescape_html = "auto",
    remove_terminal_escapes = TRUE,
    fix_encoding = TRUE,
    restore_byte_a0 = TRUE,
    replace_lossy_sequences = TRUE,
    decode_inconsistent_utf8 = TRUE,
    fix_c1_controls = TRUE,
    fix_latin_ligatures = TRUE,
    fix_character_width = TRUE,
    uncurl_quotes = TRUE,
    fix_line_breaks = TRUE,
    remove_control_chars = TRUE,
    normalization = "NFC",
    max_decode_length = 1e6
  )
}

# Why each of upstream's fields without a counterpart is not an option.
options_not_ported <- c(
  explain = paste0(
    "Python ftfy's `explain` has no counterpart here: `fix_text()` never ",
    "returns a plan and `fix_and_explain()` always does."
  ),
  fix_surrogates = paste0(
    "Python ftfy's `fix_surrogates` has no counterpart here: an R string ",
    "cannot hold a surrogate."
  ),
  fix_entities = paste0(
    "Python ftfy's deprecated `fix_entities` is not accepted; the option ",
    "is `unescape_html`."
  )
)

#' Options for fixing text
#'
#' `ftfy_config()` makes a set of options to save and pass to several calls
#' as their `config` argument. Every option has a default, so name only the
#' ones to change.
#'
#' The core functions, such as [fix_encoding()], take
#' `(x, ..., config = ftfy_config())`. An option given by name in `...`
#' overrides the same option in `config` for that call:
#'
#' ```
#' fix_encoding(x, restore_byte_a0 = FALSE)                 # one call
#' cautious <- ftfy_config(restore_byte_a0 = FALSE)         # saved
#' fix_encoding(x, config = cautious)
#' fix_encoding(x, fix_c1_controls = FALSE, config = cautious)
#' ```
#'
#' An option must be given by its full name. A name that is not an option
#' is an error that suggests the nearest one, and so is an argument with no
#' name. An option holds a single value for the whole call: it is never
#' matched element by element against `x`.
#'
#' The encoding-only functions accept every option and use only
#' `fix_encoding` and the four options under it.
#'
#' @section Options:
#' The names and defaults are those of Python ftfy's `TextFixerConfig`.
#' Each is `TRUE` or `FALSE` and defaults to `TRUE`, unless it says
#' otherwise.
#'
#' \describe{
#'   \item{`unescape_html`}{`"auto"` (the default), `TRUE` or `FALSE`.
#'     Whether to replace HTML entities such as `&amp;` with the characters
#'     they stand for. `"auto"` does so unless the text holds a literal
#'     `<`, which suggests it is HTML whose entities should be kept.}
#'   \item{`remove_terminal_escapes`}{Remove ANSI terminal escapes, such as
#'     those that change the colour of text in a terminal.}
#'   \item{`fix_encoding`}{Detect mojibake and repair it by decoding the
#'     text with a different codec. The next four options adjust this
#'     repair and do nothing when `fix_encoding` is `FALSE`.}
#'   \item{`restore_byte_a0`}{Let a plain space (U+0020) be read as a
#'     no-break space (U+00A0) when that makes it part of repairable
#'     mojibake. Turning this off avoids some false repairs and misses some
#'     mojibake.}
#'   \item{`replace_lossy_sequences`}{Detect mojibake in which some
#'     characters were replaced by U+FFFD or `?`, and replace each such
#'     sequence with U+FFFD when the rest can be decoded.}
#'   \item{`decode_inconsistent_utf8`}{Where sequences plainly look like
#'     UTF-8 mojibake but the string as a whole cannot be read in another
#'     codec, repair those sequences anyway. This helps with strings joined
#'     from text in different encodings.}
#'   \item{`fix_c1_controls`}{Replace C1 control characters (U+0080 to
#'     U+009F) with the characters Windows-1252 has at those bytes, as
#'     HTML5 does, even when the whole string does not decode as Latin-1.}
#'   \item{`fix_latin_ligatures`}{Replace common Latin ligatures, such as
#'     U+FB01, with the letters they are made of.}
#'   \item{`fix_character_width`}{Replace fullwidth Latin characters and
#'     halfwidth Katakana with their standard-width forms.}
#'   \item{`uncurl_quotes`}{Replace curly quotes with straight quotes.}
#'   \item{`fix_line_breaks`}{Replace other forms of line break with
#'     `"\n"`.}
#'   \item{`remove_control_chars`}{Remove control characters that have no
#'     displayed effect.}
#'   \item{`normalization`}{`"NFC"` (the default), `"NFD"`, `"NFKC"`,
#'     `"NFKD"`, or `NULL` for no normalisation. NFKC and NFKD can change
#'     meaning: they turn a superscript three into the digit 3.}
#'   \item{`max_decode_length`}{A whole number, at least 1; the default is
#'     `1e6`. The longest segment, in characters, that is repaired in one
#'     piece.}
#' }
#'
#' @section Differences from Python ftfy:
#' Three of `TextFixerConfig`'s fields are not options here, and passing
#' one is an error: `explain`, `fix_surrogates` and the deprecated alias
#' `fix_entities` (use `unescape_html`).
#'
#' @param ... Options to change from their defaults, each given by its full
#'   name. See the section Options.
#'
#' @return An object of class `ftfy_config`: a list of all 14 options.
#'
#' @examples
#' cautious <- ftfy_config(restore_byte_a0 = FALSE)
#' cautious
#'
#' x <- c("caf\u00c3\u00a9", "plain")
#' fix_encoding(x, config = cautious)
#' @export
ftfy_config <- function(...) {
  config <- option_defaults()
  given <- check_options(given_options(list(...)))
  config[names(given)] <- given
  structure(config, class = "ftfy_config")
}

# The one function every core entry point calls: resolves the options
# given by name in `...` and the `config` argument into one complete,
# validated `ftfy_config` object. A named option overrides the config.
#
# Call it as `resolve_config(..., config = config)`. `config` comes after
# the dots so that it is matched by its full name only: were it first, an
# argument the user misnamed `conf` would be taken for it.
resolve_config <- function(..., config) {
  given <- given_options(list(...), also = "config")
  check_config(config)
  given <- check_options(given, also = "config")
  config[names(given)] <- given
  config
}

# The arguments passed as options, as a named list. An argument without a
# name, or a name given twice, is an error.
given_options <- function(given, also = character()) {
  if (length(given) == 0L) {
    return(structure(list(), names = character()))
  }
  name <- names(given)
  if (is.null(name) || any(is.na(name) | name == "")) {
    stop(
      "An argument was passed without a name. ",
      "An option must be given by name, such as `uncurl_quotes = FALSE`",
      if (length(also) > 0L) ", and a saved set of options as `config`",
      ". See `?ftfy_config`.",
      call. = FALSE
    )
  }
  repeated <- name[duplicated(name)]
  if (length(repeated) > 0L) {
    stop(
      "Option `", repeated[[1L]], "` is given more than once.",
      call. = FALSE
    )
  }
  given
}

# `config` must be what `ftfy_config()` returns: its class, all 14 options
# and a valid value for each.
check_config <- function(config) {
  if (!inherits(config, "ftfy_config")) {
    stop(
      "`config` must be a set of options made by `ftfy_config()`, not ",
      describe_option_value(config), ".",
      call. = FALSE
    )
  }
  if (!is.list(config) ||
        !identical(names(config), names(option_defaults()))) {
    stop(
      "`config` does not hold the options `ftfy_config()` gives. ",
      "Make it with `ftfy_config()` and do not change it by hand.",
      call. = FALSE
    )
  }
  check_options(unclass(config))
  invisible(config)
}

# Checks a named list of options and returns it with each value in its one
# stored form. `also` holds other argument names to consider when
# suggesting a name.
check_options <- function(given, also = character()) {
  accepted <- names(option_defaults())
  unknown <- setdiff(names(given), accepted)
  if (length(unknown) > 0L) {
    stop(unknown_option_message(unknown[[1L]], c(accepted, also)),
         call. = FALSE)
  }
  for (name in names(given)) {
    given[name] <- list(check_option_value(name, given[[name]]))
  }
  given
}

unknown_option_message <- function(name, candidates) {
  if (name %in% names(options_not_ported)) {
    hint <- options_not_ported[[name]]
  } else {
    # The nearest name is the one option this abbreviates, or else the one
    # the fewest edits away, when that is few enough to be a slip.
    distance <- drop(utils::adist(name, candidates))
    abbreviated <- which(startsWith(candidates, name))
    if (length(abbreviated) == 1L) {
      distance[[abbreviated]] <- 0
    }
    nearest <- which.min(distance)
    if (distance[[nearest]] <= max(2, nchar(name) %/% 3L)) {
      hint <- paste0("Did you mean `", candidates[[nearest]], "`?")
    } else {
      hint <- paste0(
        "The options are: ",
        paste(names(option_defaults()), collapse = ", "), "."
      )
    }
  }
  paste0("Unknown option `", name, "`. ", hint, " See `?ftfy_config`.")
}

# One option's value, checked and in its stored form: `TRUE`, `FALSE`,
# `"auto"`, a normalisation form, `NULL`, or a double.
check_option_value <- function(name, value) {
  single <- is.atomic(value) && length(value) == 1L && !is.na(value)
  flag <- single && is.logical(value)
  if (name == "unescape_html") {
    if (flag) {
      return(isTRUE(value))
    }
    if (single && is.character(value) && value == "auto") {
      return("auto")
    }
    wanted <- "`\"auto\"`, `TRUE` or `FALSE`"
  } else if (name == "normalization") {
    if (is.null(value)) {
      return(NULL)
    }
    if (single && is.character(value) && value %in% plan_normalizations) {
      return(as.vector(value))
    }
    wanted <- paste0(
      paste0("`\"", plan_normalizations, "\"`", collapse = ", "),
      " or `NULL`"
    )
  } else if (name == "max_decode_length") {
    if (single && is.numeric(value) && is.finite(value) && value >= 1 &&
          value == trunc(value)) {
      return(as.double(value))
    }
    wanted <- "a single whole number, at least 1"
  } else {
    if (flag) {
      return(isTRUE(value))
    }
    wanted <- "`TRUE` or `FALSE`"
  }
  stop(
    "Option `", name, "` must be ", wanted, ", not ",
    describe_option_value(value), ".",
    if (length(value) > 1L) {
      paste0(
        " An option holds one value for the whole call and is not ",
        "matched against the elements of `x`."
      )
    },
    call. = FALSE
  )
}

describe_option_value <- function(value) {
  if (is.null(value)) {
    return("`NULL`")
  }
  if (is.function(value)) {
    return("a function")
  }
  if (is.object(value)) {
    return(paste0("an object of class <", class(value)[[1L]], ">"))
  }
  if (!is.atomic(value) || length(value) != 1L) {
    return(paste0("a <", typeof(value), "> of length ", length(value)))
  }
  if (is.na(value)) {
    return("`NA`")
  }
  if (is.character(value)) {
    return(paste0("the string ", encodeString(value, quote = "\"")))
  }
  paste0("`", format(value), "`")
}

#' @export
print.ftfy_config <- function(x, ...) {
  cat("<ftfy_config>\n")
  values <- unclass(x)
  shown <- vapply(
    values,
    function(value) paste(deparse(value), collapse = " "),
    character(1)
  )
  cat(paste0("  ", format(names(values)), " = ", shown, "\n"), sep = "")
  invisible(x)
}
