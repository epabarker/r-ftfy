#' ftfy: fixes text for you
#'
#' ftfy repairs mojibake, text that was decoded with the wrong codec, and
#' related damage in character vectors. It is a port to R of the Python
#' package ftfy by Robyn Speer: the heuristic, its test cases and most of
#' its data are her work.
#'
#' [fix_text()] is the function most users want. [fix_and_explain()] also
#' returns the plan that produced each text, which [apply_plan()] can
#' replay. [fix_encoding()] and [fix_encoding_and_explain()] repair
#' mojibake and nothing else. [badness()] and [is_bad()] say whether text
#' looks like mojibake. Each fixer can be called by itself (see
#' [text_fixers], [fix_c1_controls()] and [decode_inconsistent_utf8()]),
#' and [ftfy_config()] describes the options.
#'
#' @section Reference version:
#' The reference version is Python ftfy 6.3.1 on Python 3.13. The package
#' aims to return what that version returns, and its tests compare it
#' with committed snapshots of that version's output. The ftfy half of
#' the reference version is recorded in the package's `DESCRIPTION` file:
#' `utils::packageDescription("ftfy")[["Config/ftfy/upstream"]]`.
#'
#' Where the package deliberately does something else, that is a
#' departure. Every departure is listed, with the reference version's
#' output beside this package's, on the page [ftfy-differences].
#'
#' The package has its own version numbers, which say nothing about the
#' version of Python ftfy. Moving to a new reference version is a
#' decision of its own, made in a minor release. The output of
#' [fix_text()] with default options never changes in a patch release,
#' and `news(package = "ftfy")` lists every changed default output with
#' an example.
#'
#' @section Call on whole vectors:
#' Give every function the whole vector, or the whole column of a data
#' frame, in one call: `fix_text(x)`, never `sapply(x, fix_text)`, a loop
#' over the elements or a call for each row. Nothing inside the package
#' loops over strings, and a value that occurs many times is fixed once.
#'
#' Each call has a fixed cost, whatever the length of the vector, because
#' stringi compiles a regular expression every time it is used and the
#' pattern that detects mojibake takes about half a millisecond to
#' compile. The cost that was accepted when this design was chosen is 0.6
#' to 1.6 milliseconds for a call on one string that is not plain ASCII,
#' where Python ftfy takes 6 to 16 microseconds on such a string. Those
#' figures are from the record of that decision (ADR 0008 in the
#' package's repository), measured on an Apple silicon Mac. Measured
#' again on the functions as they are now, on such a machine with R 4.6.2
#' and stringi 1.8.7, one call of [fix_text()] on one string took 0.8 to
#' 2.1 milliseconds when the string was not plain ASCII, the higher
#' figure for mojibake, and 0.06 milliseconds when it was plain ASCII.
#' One call of [fix_encoding()] took 0.6 to 1.2 milliseconds.
#'
#' So a call for each row of a data frame pays that cost for each row,
#' and one call on the column pays it once.
#'
#' @section Each element is fixed by itself:
#' No element of a vector affects the result for another. This matters
#' in one place for users of Python ftfy. Its `fix_file()` reads a file
#' line by line, and with the option `unescape_html` at `"auto"` it stops
#' replacing HTML entities for the rest of the file once a line holds a
#' `<`. This package has no file handling, and that state carried from
#' one line of a file to the next has no counterpart: in a file read with
#' [readLines()] each line is an element, and a `<` in one element does
#' nothing to the elements after it.
#'
#' Within one string [fix_text()] does carry it: from the first segment
#' that holds a `<`, entities are left alone in that segment and in every
#' later segment of the same string. To leave entities alone in every
#' element, pass `unescape_html = FALSE`.
#'
#' @section What is not in the package:
#' These parts of Python ftfy are not ported: file handling (`fix_file`),
#' the command line, the display-width functions of `ftfy.formatting`,
#' `fix_surrogates`, `remove_bom`, `convert_surrogate_pair`,
#' `guess_bytes`, `decode_escapes` and `explain_unicode`. Text is always
#' a character vector: bytes, as a raw vector, are not accepted. A codec
#' has one name, with no aliases (see [ftfy_plan()]).
#'
#' @author
#' Robyn Speer, author of Python ftfy, of which this package is a port
#' (author and copyright holder).
#'
#' Ed Barker \email{epabarker@@pm.me} (author, maintainer and copyright
#' holder). The port was written with AI assistance, under the
#' maintainer's direction: any errors in the translation are this
#' package's and not Robyn Speer's.
#'
#' @seealso
#' [ftfy-differences] for every departure from the reference version.
#'
#' Python ftfy: <https://github.com/rspeer/python-ftfy>. This package:
#' <https://github.com/epabarker/r-ftfy>; report bugs at
#' <https://github.com/epabarker/r-ftfy/issues>.
#'
#' `citation("ftfy")` gives the citation Robyn Speer asks for.
#'
#' @keywords internal
"_PACKAGE"
