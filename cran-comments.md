## Submission

This is a new submission: the first release of ftfy, an R port of the Python package ftfy 6.3.1 by Robyn Speer (Apache-2.0). It repairs mojibake (text decoded with the wrong codec) and related damage in text. The package is a derivative work of Python ftfy, credited in `Authors@R` and in `inst/COPYRIGHTS`, under the same licence.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Test environments

* local: macOS (aarch64), R 4.6.2, stringi 1.8.7 with ICU 71.1
* GitHub Actions:
  * Ubuntu: R release, devel, oldrel-1 and 4.2; a Latin-1 session; stringi with its bundled ICU 74.1 and with system ICU 70.1
  * macOS: R release
  * Windows: R release
* win-builder: R release and devel
* mac-builder: R release

## Notes for the reviewers

* stringi is the only hard dependency. jsonlite and testthat are used only by the tests.
* The tests take about 15 seconds. Larger comparisons with the Python package, and the benchmarks, are kept outside the built package.
