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

Call it on the whole vector, or the whole column, and not once per row. Each call has a fixed cost. The cost accepted when the design was chosen (ADR 0008) is 0.6 to 1.6 milliseconds for a call on one string that is not plain ASCII, where Python ftfy takes 6 to 16 microseconds; it was accepted so that a whole vector could be fixed in one pass with no compiled code. `?ftfy` has the figures measured on the package as it is now.

## Status

Version 0.1 is written and tested but has not been released yet. It ports what Python ftfy 6.3.1 does to text:

- `fix_text()` for the whole repair, and `fix_and_explain()`, which repairs each string as one segment and also returns the plan of steps it took;
- `fix_encoding()` and `fix_encoding_and_explain()` for mojibake alone;
- `apply_plan()` to replay a plan on other text, and `ftfy_plan()` and `plan_steps()` to build and read plans;
- the separate fixers, such as `uncurl_quotes()`, `unescape_html()` and `fix_c1_controls()`;
- `badness()` and `is_bad()`, the measure of how much a string looks like mojibake;
- the options of Python ftfy, by name in a call or saved with `ftfy_config()`, less `explain` and `fix_surrogates`, which have no counterpart here.

File handling, the command line and Python ftfy's other parts listed in `?ftfy` are not ported.

Install the development version with:

```r
# install.packages("pak")
pak::pak("epabarker/r-ftfy")
```

## How this port relates to ftfy

**The reference version is ftfy 6.3.1**, run on Python 3.13. The package aims to return what that version returns. Its regular expressions, codec tables and other data are read from that version by scripts, not retyped, and the tests compare the package with committed snapshots of that version's output, including all of ftfy's own test cases.

The package has its own version numbers. Where it knowingly behaves differently from the reference version, the difference is recorded in the departure registry (`inst/departures/`). The help page `?"ftfy-differences"` is written from the registry and lists every departure, with the reference version's output beside this package's. `NEWS.md` lists every changed default output with an example, and the output of `fix_text()` with default options never changes in a patch release.

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
