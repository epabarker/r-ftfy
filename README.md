# ftfy

ftfy for R is a port of [ftfy](https://github.com/rspeer/python-ftfy) by Robyn Speer. The heuristic, its test cases and most of its data are her work.

ftfy ("fixes text for you") repairs mojibake: text that was decoded with the wrong codec, so that `só` arrives as `sÃ³`. It works out from the damaged text alone which mix-up happened, and undoes it. It leaves text that is already right as it is.

```r
library(ftfy)

fix_encoding(c("sÃ³", "âœ” No problems", "already fine"))
#> [1] "só"            "✔ No problems" "already fine"

is_bad(c("sÃ³", "só"))
#> [1]  TRUE FALSE
```

Every function takes a character vector and works on all of it at once.

## Status

The package is in development and has not been released. Functions are being added one at a time; the ones shown above work today.

Install the development version with:

```r
# install.packages("pak")
pak::pak("epabarker/r-ftfy")
```

## How this port relates to ftfy

**The reference version is ftfy 6.3.1**, run on Python 3.13. The package aims to return what that version returns. Its regular expressions, codec tables and other data are read from that version by scripts, not retyped, and the tests compare the package with committed snapshots of that version's output, including all of ftfy's own test cases.

The package has its own version numbers. Where it knowingly behaves differently from the reference version, the difference is recorded in the departure registry (`inst/departures/`).

**The port was written with AI assistance.** The R code, tests and documentation were written with Anthropic's Claude, under the maintainer's direction. ftfy's author asks that a derived work never obscure where it came from, and names generative AI as a way that happens. So, to be plain: the ideas here are Robyn Speer's, the translation to R was done with an AI model, and any errors in the translation are this package's and not hers.

## Citing

If you use ftfy for R in research, please cite ftfy itself. Robyn Speer asks for this citation:

    Robyn Speer. (2019). ftfy (Version 5.5). Zenodo.
    http://doi.org/10.5281/zenodo.2591652

In BibTeX format:

    @misc{speer-2019-ftfy,
      author       = {Robyn Speer},
      title        = {ftfy},
      note         = {Version 5.5},
      year         = 2019,
      howpublished = {Zenodo},
      doi          = {10.5281/zenodo.2591652},
      url          = {https://doi.org/10.5281/zenodo.2591652}
    }

`citation("ftfy")` returns this citation first, followed by an entry for the R package.

## Licence

Apache License, Version 2.0, the licence of ftfy. ftfy is Copyright 2023 Robyn Speer. [`inst/COPYRIGHTS`](inst/COPYRIGHTS) lists what was taken from ftfy and how it was changed.
