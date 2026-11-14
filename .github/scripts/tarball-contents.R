# Checks what the built tarball ships (issue #49, the resolution of issue
# #19): exactly one image, man/figures/logo.png at the size logo_size
# gives, and none of the pkgdown site configuration, favicons or logo
# sources. Run from the directory holding the tarball. Fails, naming the
# offending files, when the tarball ships anything else.

# The size of the logo, width then height, in pixels. Double, as the size
# read from the PNG header below is.
logo_size <- c(480, 556)
logo_label <- sprintf("%d x %d", logo_size[1], logo_size[2])

tarball <- list.files(pattern = "^ftfy_.*[.]tar[.]gz$")
stopifnot(length(tarball) == 1L)

files <- sub("^ftfy/", "", utils::untar(tarball, list = TRUE))
files <- files[!grepl("/$", files)]

problems <- character()

image <- "[.](png|jpe?g|gif|svg|webp|ico|bmp|tiff?|pdf)$"
images <- files[grepl(image, files, ignore.case = TRUE)]
if (!identical(images, "man/figures/logo.png")) {
  problems <- c(problems, paste0(
    "The tarball must ship exactly one image, man/figures/logo.png; it ships: ",
    if (length(images)) paste(images, collapse = ", ") else "none"
  ))
}

excluded <- "^(_pkgdown[.]ya?ml|pkgdown/|logo/|site/)"
shipped <- files[grepl(excluded, files)]
if (length(shipped)) {
  problems <- c(problems, paste0(
    "Site configuration or logo sources are in the tarball: ",
    paste(shipped, collapse = ", ")
  ))
}

if ("man/figures/logo.png" %in% images) {
  unpacked <- tempfile("unpacked")
  dir.create(unpacked)
  utils::untar(tarball, files = "ftfy/man/figures/logo.png", exdir = unpacked)
  con <- file(file.path(unpacked, "ftfy", "man", "figures", "logo.png"), "rb")
  header <- readBin(con, "raw", 24L)
  close(con)
  # A PNG's IHDR chunk holds the width and height as big-endian integers
  # at bytes 17 to 24.
  size <- c(
    sum(as.integer(header[17:20]) * 256^(3:0)),
    sum(as.integer(header[21:24]) * 256^(3:0))
  )
  if (!identical(size, logo_size)) {
    problems <- c(problems, sprintf(
      "man/figures/logo.png is %d x %d, not %s.", size[1], size[2], logo_label
    ))
  }
}

if (length(problems)) {
  stop(paste(problems, collapse = "\n"), call. = FALSE)
}
cat(sprintf(
  "The tarball ships one image, man/figures/logo.png (%s), and no site configuration or logo sources.\n",
  logo_label
))
