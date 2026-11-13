# Rebuild what is derived from committed sources: the internal package data
# in R/sysdata.rda, then NAMESPACE and man/ (through roxygen2).
#
#   Rscript data-raw/build.R           rebuild everything
#   Rscript data-raw/build.R --check   fail if R/sysdata.rda is out of date
#
# Internal data is built by the scripts in data-raw/sysdata/, which are found
# by listing that directory. Each script is run in its own environment, with
# the repository root as the working directory, and every object it leaves
# there whose name does not start with a dot goes into R/sysdata.rda. To
# ship a new object, add a script; nothing here lists them.
#
# R/sysdata.rda, NAMESPACE and man/ are never edited or merged by hand. On a
# merge conflict in any of them, take either side and run this script.
#
# This script needs no Python. It carries no derived-file header because it
# holds nothing taken from python-ftfy; the scripts in data-raw/sysdata/ and
# data-raw/generators/ do.

args <- commandArgs(trailingOnly = TRUE)
unknown <- setdiff(args, "--check")
if (length(unknown) > 0L) {
  stop("unknown argument: ", paste(unknown, collapse = " "))
}
check_only <- "--check" %in% args

script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE))
if (length(script) != 1L) {
  stop("run this file with Rscript")
}
setwd(dirname(dirname(normalizePath(script))))

build_sysdata <- function() {
  built <- new.env(parent = emptyenv())
  scripts <- sort(list.files("data-raw/sysdata", pattern = "[.]R$", full.names = TRUE))
  for (path in scripts) {
    env <- new.env(parent = globalenv())
    sys.source(path, envir = env)
    for (name in ls(env)) {
      if (exists(name, envir = built, inherits = FALSE)) {
        stop(path, " defines `", name, "`, which another script already built")
      }
      assign(name, get(name, envir = env), envir = built)
    }
  }
  mget(sort(ls(built)), envir = built)
}

read_sysdata <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }
  env <- new.env(parent = emptyenv())
  load(path, envir = env)
  mget(sort(ls(env, all.names = TRUE)), envir = env)
}

target <- "R/sysdata.rda"
built <- build_sysdata()
current <- identical(read_sysdata(target), built)

if (check_only) {
  if (!current) {
    stop(target, " is out of date: run `Rscript data-raw/build.R` and commit the result")
  }
  message(target, " is up to date")
  quit(status = 0L)
}

if (current) {
  message(target, " is up to date")
} else {
  # The file is rewritten only when its contents change, so that a rebuild
  # with nothing to do leaves the working tree clean.
  save(list = names(built), envir = list2env(built), file = target,
       version = 3L, compress = "xz")
  message("wrote ", target, ": ", paste(names(built), collapse = ", "))
}

roxygen2::roxygenise(".", load_code = roxygen2::load_source)
