# The regex lint (ADR 0005): find every regex call in R code and say what is
# wrong with it. test-regex-lint.R runs it over the whole package.
#
# The rules, for code in the package's R/ directory:
#
#   * A stringi regex call (any stringi function that takes `opts_regex`)
#     passes `opts_regex = regex_opts()`, written exactly so, and sits
#     inside `regex_guard()`, which turns a stack overflow into the
#     package's error.
#   * `stringi::stri_opts_regex()` is called with `unix_lines = TRUE` and
#     `stack_limit = 1e9`, without `comments` and with every argument named.
#   * A stringi function that picks its engine from the argument name, such
#     as `stri_detect()`, names `fixed`, `coll` or `charclass` and not
#     `regex`.
#   * A base function that takes `fixed` (`grepl()`, `sub()`, `regexpr()`,
#     `strsplit()` and so on) passes a literal `fixed = TRUE`, which makes
#     it a plain search and not a regex call. Base R's regex engines cannot
#     take the options, so a base regex call is never allowed.
#   * `list.files()` and `dir()` are not given a `pattern`, which is a
#     regex, unless with a literal `fixed = TRUE`.
#   * None of these functions is used as a value (`lapply(x, gsub)`,
#     `do.call("grepl", ...)`), where its arguments cannot be read.
#
# The lists of functions are worked out from the installed stringi and
# base, not written down, so a function added to either is covered.

# Functions that list files, where only a `pattern` is a regex. `dir` is
# also a common name for a variable, so these are checked only as calls.
regex_lint_listing <- c("list.files", "dir")

regex_lint_sets <- local({
  sets <- NULL
  function() {
    if (is.null(sets)) {
      with_formal <- function(package, formal) {
        namespace <- asNamespace(package)
        names <- getNamespaceExports(namespace)
        keep <- vapply(names, function(name) {
          fun <- get(name, envir = namespace)
          is.function(fun) && !is.primitive(fun) &&
            formal %in% names(formals(fun))
        }, logical(1))
        sort(names[keep])
      }
      stringi_regex <- with_formal("stringi", "opts_regex")
      sets <<- list(
        stringi_regex = stringi_regex,
        stringi_generic = setdiff(with_formal("stringi", "regex"), stringi_regex),
        base_fixed = setdiff(with_formal("base", "fixed"), regex_lint_listing)
      )
    }
    sets
  }
})

is_empty_argument <- function(x) {
  is.symbol(x) && !nzchar(as.character(x))
}

# The name of the function a call's head names: `f`, `pkg::f` or `pkg:::f`.
# NULL when the head is anything else.
called_name <- function(head) {
  if (is.symbol(head)) {
    return(as.character(head))
  }
  if (is.call(head) && length(head) == 3L && is.symbol(head[[1L]]) &&
        as.character(head[[1L]]) %in% c("::", ":::") &&
        (is.symbol(head[[3L]]) || is.character(head[[3L]]))) {
    return(as.character(head[[3L]]))
  }
  NULL
}

show_call <- function(x) {
  text <- paste(deparse(x, width.cutoff = 500L), collapse = " ")
  if (nchar(text) > 120L) paste0(substr(text, 1L, 117L), "...") else text
}

# What is wrong with the regex calls in one piece of R code: a language
# object, a function, or a list of either. A character vector, empty when
# nothing is wrong.
regex_lint <- function(code) {
  sets <- regex_lint_sets()
  every <- unlist(sets, use.names = FALSE)
  problems <- character()
  problem <- function(what, x) {
    problems[[length(problems) + 1L]] <<- paste0(what, ": ", show_call(x))
  }

  check_opts <- function(x) {
    arguments <- as.list(x)[-1L]
    given <- names(arguments)
    if (is.null(given) || !all(nzchar(given))) {
      problem("stri_opts_regex() with an argument that is not named", x)
      return()
    }
    if (!identical(arguments[["unix_lines"]], TRUE)) {
      problem("stri_opts_regex() without unix_lines = TRUE", x)
    }
    if (!identical(arguments[["stack_limit"]], 1e9)) {
      problem("stri_opts_regex() without stack_limit = 1e9", x)
    }
    if ("comments" %in% given) {
      problem("stri_opts_regex() with comments", x)
    }
  }

  check_call <- function(x, name, guarded) {
    arguments <- as.list(x)[-1L]
    given <- names(arguments)
    if (is.null(given)) {
      given <- rep("", length(arguments))
    }
    if (name == "stri_opts_regex") {
      check_opts(x)
    } else if (name %in% sets$stringi_regex) {
      if (!identical(arguments[["opts_regex"]], quote(regex_opts()))) {
        problem("a regex call without opts_regex = regex_opts()", x)
      }
      if (!guarded) {
        problem("a regex call outside regex_guard()", x)
      }
    } else if (name %in% sets$stringi_generic) {
      if ("regex" %in% given || !any(c("fixed", "coll", "charclass") %in% given)) {
        problem("a regex call through a function that cannot take the options", x)
      }
    } else if (name %in% sets$base_fixed) {
      if (!identical(arguments[["fixed"]], TRUE)) {
        problem("a base regex call (no literal fixed = TRUE)", x)
      }
    } else if (name %in% regex_lint_listing) {
      if ("pattern" %in% given && !identical(arguments[["fixed"]], TRUE)) {
        problem("a file listing filtered by a regex", x)
      }
    } else if (name %in% c("do.call", "match.fun", "get", "getExportedValue")) {
      first <- if (length(arguments)) arguments[[1L]] else NULL
      if (is.character(first) && any(first %in% every)) {
        problem("a regex function called by name", x)
      }
    }
  }

  walk <- function(x, guarded = FALSE) {
    if (is.function(x)) {
      if (!is.primitive(x)) {
        walk(formals(x), guarded)
        walk(body(x), guarded)
      }
    } else if (is.symbol(x)) {
      if (as.character(x) %in% every) {
        problem("a regex function used as a value", x)
      }
    } else if (is.call(x)) {
      head <- x[[1L]]
      name <- called_name(head)
      if (is.null(name)) {
        walk(head, guarded)
      } else if (name %in% c("::", ":::")) {
        # `stringi::stri_detect_regex` not being called: a value.
        value <- called_name(x)
        if (!is.null(value) && value %in% every) {
          problem("a regex function used as a value", x)
        }
        return(invisible())
      } else {
        check_call(x, name, guarded)
      }
      inside_guard <- identical(name, "regex_guard")
      for (i in seq_along(x)[-1L]) {
        if (!is_empty_argument(x[[i]])) {
          # Only the guarded expression itself, the first argument, is
          # covered by the guard.
          walk(x[[i]], guarded || (inside_guard && i == 2L))
        }
      }
    } else if (is.pairlist(x) || is.list(x) || is.expression(x)) {
      for (i in seq_along(x)) {
        if (!is_empty_argument(x[[i]])) {
          walk(x[[i]], guarded)
        }
      }
    }
    invisible()
  }

  walk(code)
  problems
}

# The lint over every object in a namespace, each problem starting with
# the object's name.
regex_lint_namespace <- function(namespace = asNamespace("ftfy")) {
  names <- sort(ls(namespace, all.names = TRUE))
  # Objects R itself adds to a namespace.
  names <- setdiff(names, c(".__NAMESPACE__.", ".__S3MethodsTable__.", ".packageName"))
  unlist(lapply(names, function(name) {
    found <- regex_lint(get(name, envir = namespace))
    if (length(found)) paste0(name, ": ", found) else character()
  }))
}

# The lint over R source files, which also sees code outside any function.
regex_lint_files <- function(files) {
  unlist(lapply(files, function(file) {
    found <- regex_lint(parse(file, keep.source = FALSE))
    if (length(found)) paste0(basename(file), ": ", found) else character()
  }))
}
