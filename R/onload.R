# What is built when the package is loaded. Add a line here only for
# something that must be made from shipped data and never stored.

.onLoad <- function(libname, pkgname) {
  build_codecs()
}
