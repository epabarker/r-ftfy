# Readers for the package's help pages, for the tests of the documentation.

help_source_root <- function() test_path("..", "..")

# The source tree has man/ and data-raw/ beside the tests; the tests of an
# installed package, and of R CMD check, have neither. The R CMD check
# workflow runs the tests from the checkout with FTFY_SOURCE_TREE=true,
# where a skip would hide a failure.
skip_without_source_tree <- function() {
  if (is_source_tree(help_source_root())) {
    return(invisible())
  }
  if (identical(Sys.getenv("FTFY_SOURCE_TREE"), "true")) {
    stop("FTFY_SOURCE_TREE is true, but R/ and data-raw/ are not beside the tests.")
  }
  skip("Not run from the package's source tree.")
}

# Every help page of the package, parsed: from man/ in the source tree,
# from the installed package anywhere else.
package_help <- function() {
  root <- help_source_root()
  if (is_source_tree(root)) {
    tools::Rd_db(dir = root)
  } else {
    tools::Rd_db("ftfy")
  }
}

rd_tag <- function(rd) {
  tag <- attr(rd, "Rd_tag")
  if (is.null(tag)) "" else tag
}

# The pieces of a parsed help page with the tag `tag`, at any depth.
rd_pieces <- function(rd, tag) {
  if (!is.list(rd)) {
    return(list())
  }
  found <- list()
  for (piece in rd) {
    if (identical(rd_tag(piece), tag)) {
      found <- c(found, list(piece))
    } else {
      found <- c(found, rd_pieces(piece, tag))
    }
  }
  found
}

# All the text of a parsed help page or of a piece of one, as one string
# with every run of white space made one space. `drop` names tags whose
# content is left out.
rd_text <- function(rd, drop = character()) {
  collect <- function(piece) {
    if (rd_tag(piece) %in% drop) {
      return(character())
    }
    if (is.list(piece)) {
      return(unlist(lapply(piece, collect)))
    }
    as.character(piece)
  }
  squash(paste(collect(rd), collapse = ""))
}

squash <- function(text) {
  trimws(gsub("[[:space:]]+", " ", text))
}

# The help pages by alias: a named list with one parsed page for each
# alias, so that `help_by_alias()[["is_bad"]]` is the page `?is_bad` opens.
help_by_alias <- function(pages = package_help()) {
  by_alias <- list()
  for (page in pages) {
    for (alias in rd_pieces(page, "\\alias")) {
      by_alias[[rd_text(alias)]] <- page
    }
  }
  by_alias
}
